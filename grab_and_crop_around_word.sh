#!/bin/bash
         STOP_FILE=STOP
  ARCHIVE_BASE_URL=http://newspaperarchive.ftroot.com
              WORD="Europe"
     WORD_PAD_SIDE=300
      NAME_VARIANT=to_word_${WORD}
         CROPS_DIR=./crops_${NAME_VARIANT}
     ORIGINALS_DIR=./originals
    ANIMATIONS_DIR=./animations_${NAME_VARIANT}
BOUNDS_ARTICLES_DIR=./bounds_articles_${NAME_VARIANT}
   BOUNDS_WORD_DIR=./bounds_${NAME_VARIANT}
   ANIMATION_DELAY=1
         FRAMERATE=10
      SCALED_WIDTH=1080
        PAD_HEIGHT=608
      PAD_Y_OFFSET=196
               NOW=$(date +"%Y_%m_%d_%H%M_%S")
     MP4_BASE_NAME=${ANIMATIONS_DIR}/${NOW}_${NAME_VARIANT}_ff_r${FRAMERATE}

for D in $CROPS_DIR $ORIGINALS_DIR $ANIMATIONS_DIR $BOUNDS_ARTICLES_DIR $BOUNDS_WORD_DIR; do
	mkdir -p $D
done

FIRST_ARG=$1

error()
{
    echo "error: $*"
    exit 1;
}

command -v convert >/dev/null 2>&1 || error "Missing program, 'convert'. You need ImageMagick installed."
command -v ffmpeg  >/dev/null 2>&1 || error "Missing program, 'ffmpeg'."
command -v wget    >/dev/null 2>&1 || error "Missing program, 'wget'."

if [[ "$FIRST_ARG" = "" ]]; then # any arg means skip creating crops

	for YEAR in {1888..2010}
	do
		for MONTH in {1..12}
		do
			# for DAY in {1..31}
			for DAY in 1
			do
				if [[ -e $STOP_FILE ]]; then
					echo "exiting loop because STOP file exists"
					exit
				fi
				                   YMD=$(printf "%4d%02d%02d" $YEAR $MONTH $DAY)
				       IMAGE_BASE_NAME=$(printf "FTDA-%4d-%02d%02d-0001" $YEAR $MONTH $DAY)
				     SOURCE_IMAGE_NAME=${IMAGE_BASE_NAME}.JPG
				  SOURCE_URL_BASE_PATH=$ARCHIVE_BASE_URL/all_years/$YEAR/$YMD
				      SOURCE_IMAGE_URL=$SOURCE_URL_BASE_PATH/$SOURCE_IMAGE_NAME
				 SOURCE_IMAGE_FILENAME=$ORIGINALS_DIR/$SOURCE_IMAGE_NAME
				    CROPPED_IMAGE_NAME=${IMAGE_BASE_NAME}-cropped-to-banner.JPG
				CROPPED_IMAGE_FILENAME=$CROPS_DIR/$CROPPED_IMAGE_NAME
				         XML_BASE_NAME=$(printf "FTDA-%4d-%02d%02d" $YEAR $MONTH $DAY)
				        SOURCE_XML_URL=$SOURCE_URL_BASE_PATH/${XML_BASE_NAME}.xml
		 	  BOUNDS_ARTICLES_FILENAME=$BOUNDS_ARTICLES_DIR/${XML_BASE_NAME}.bounds.txt
		 	      BOUNDS_WORD_FILENAME=$BOUNDS_WORD_DIR/${XML_BASE_NAME}.bounds.txt

				if [ -e $SOURCE_IMAGE_FILENAME ]; then
					echo "skipping WGET of $SOURCE_IMAGE_FILENAME: local copy exists"
				else
					wget -O $SOURCE_IMAGE_FILENAME $SOURCE_IMAGE_URL
				fi

				if [ ! -e $SOURCE_IMAGE_FILENAME ]; then
					touch $SOURCE_IMAGE_FILENAME 
				fi

				if [ -s $SOURCE_IMAGE_FILENAME ]; then
					echo "found non-empty $SOURCE_IMAGE_FILENAME"
					if [[ -e $CROPPED_IMAGE_FILENAME ]]; then
						echo "skipping convert of $CROPPED_IMAGE_FILENAME: local copy exists"
					else
						if [ -s $BOUNDS_ARTICLES_FILENAME ]; then
							echo "skipping WGET of XML: $BOUNDS_ARTICLES_FILENAME exists"
						else
							export WORD
							wget -O- $SOURCE_XML_URL | perl -ne '
BEGIN { $word = $ENV{"WORD"}; }
/<imdim>([^<]+)<\/imdim>/ and $imdim=$1;
/<da>([^<]+)<\/da>/ and $da=$1;
/<dw>([^<]+)<\/dw>/ and $dw=$1;
/<ti>([^<]+)<\/ti>/ and $ti=$1; 
/<article type="([^"]+)">/ and $atype=$1;
if (/<id>([^<]+)<\/id>/) {
	$id=$1;
	@pieces = split(/-/, $id);
	if (scalar(@pieces) == 5) {
		if ($pieces[3] ne "0001") { 
			last;
		}
	} else {
		$mainId=$id
	}
}
/<ct>([^<]*)<\/ct>/ and $ct=$1;
/<pg [^>]+ pos="(.*)"\/>/ and $pg=$1;
if(/<wd pos="([^>]+)">${word}<\/wd>/i) {
	print join("|", $mainId, $da, $dw, $imdim, $atype, $ct, $id, $ti, $pg, $1), "\n";
	last;
}
' > $BOUNDS_ARTICLES_FILENAME 
						fi

						if [ -s $BOUNDS_WORD_FILENAME ]; then
							echo "skipping calc of banner bounds: $BOUNDS_WORD_FILENAME exists"
						else
							export WORD_PAD_SIDE
							cat $BOUNDS_ARTICLES_FILENAME | perl -ne '
BEGIN { $word_pad_side = $ENV{"WORD_PAD_SIDE"}; }
@p = split(/\|/, $_); 
@acoords = split(/,/, $p[8]);
@wcoords = split(/,/, $p[9]);

$wordHeight = $wcoords[3] - $wcoords[1];
$wordWidth  = $wcoords[2] - $wcoords[0];

# $gapL = $wcoords[0] - $acoords[0];
# $gapR = $acoords[2] - $wcoords[2];

# $mostGapLR = ($gapL > $gapR)? $gapL : $gapR;

# $gapU = $wcoords[1] - $acoords[1];
# $gapD = $acoords[3] - $wcoords[3];

# $mostGapUD = ($gapU > $gapD)? $gapU : $gapD;

# $heightPad = $mostGapLR;
# $widthPad  = $mostGapLR;

# $totHeight = $wordHeight + $heightPad + $heightPad;
# $totWidth  = $wordWidth  + $widthPad  + $widthPad;

# $offsetX = $wcoords[0] - $widthPad;
# $offsetY = $wcoords[1] - $heightPad;

$totHeight = $word_pad_side + $word_pad_side;
$totWidth  = $word_pad_side + $word_pad_side;

if (($totHeight % 2) == 1) { $totHeight += 1; }
if (($totWidth  % 2) == 1) { $totWidth  += 1; }

$offsetX = $wcoords[0] - $word_pad_side + int($wordWidth  / 2);
$offsetY = $wcoords[1] - $word_pad_side + int($wordHeight / 2);

if($offsetX >= 0 and $offsetY >= 0) {
	print sprintf("%dx%d+%d+%d", $totWidth, $totHeight, $offsetX, $offsetY);
	last;
} else {
	print STDERR "offsetX=$offsetX, offsetY=$offsetY, acoords=@acoords, wcoords=@wcoords, wordHeight=$wordHeight, wordWidth=$wordWidth, gapL=$gapL, gapR=$gapR, mostGapLR=$mostGapLR, gapU=$gapU, gapD=$gapD, mostGapUD=$mostGapUD, totHeight=$totHeight, totWidth=$totWidth, widthPad=$widthPad, heightPad=$heightPad\n";
}
' > $BOUNDS_WORD_FILENAME
						fi

						if [ -s $BOUNDS_WORD_FILENAME ] ; then
							BOUNDS=$(cat $BOUNDS_WORD_FILENAME)

							convert \
								-crop "$BOUNDS" \
								$SOURCE_IMAGE_FILENAME \
								$CROPPED_IMAGE_FILENAME
						fi
					fi
				fi
			done
		done
	done
fi

       MP4_NAME=${MP4_BASE_NAME}.mp4
MP4_SCALED_NAME=${MP4_BASE_NAME}_size${SCALED_WIDTH}.mp4
MP4_PADDED_NAME=${MP4_BASE_NAME}_size${SCALED_WIDTH}_padheight${PAD_HEIGHT}.mp4

ffmpeg -framerate $FRAMERATE -pattern_type glob -i "${CROPS_DIR}/*.JPG" -c:v libx264 -r 30 -pix_fmt yuv420p ${MP4_NAME}
# ffmpeg -i ${MP4_NAME} -vf scale="${SCALED_WIDTH}:trunc(ow/a/2)*2" ${MP4_SCALED_NAME}
# ffmpeg -i ${MP4_SCALED_NAME} -filter_complex "pad=height=${PAD_HEIGHT}:y=${PAD_Y_OFFSET}" ${MP4_PADDED_NAME}
