#!/bin/bash
         STOP_FILE=STOP
  ARCHIVE_BASE_URL=http://newspaperarchive.ftroot.com
BANNER_CROP_HEIGHT=1000
 BANNER_CROP_WIDTH=5000
     EXTENT_HEIGHT=2814
         CROPS_DIR=./crops
     ORIGINALS_DIR=./originals
    ANIMATIONS_DIR=./animations
BOUNDS_ARTICLES_DIR=./bounds_articles
  BOUNDS_BANNER_DIR=./bounds_banner
   ANIMATION_DELAY=1
         FRAMERATE=10
      SCALED_WIDTH=1080
        PAD_HEIGHT=608
      PAD_Y_OFFSET=196
               NOW=$(date +"%Y_%m_%d_%H%M_%S")
     MP4_BASE_NAME=${ANIMATIONS_DIR}/${NOW}_xml_ff_r${FRAMERATE}

mkdir -p $CROPS_DIR
mkdir -p $ORIGINALS_DIR
mkdir -p $ANIMATIONS_DIR
mkdir -p $BOUNDS_ARTICLES_DIR
mkdir -p $BOUNDS_BANNER_DIR

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
		 	  BOUNDS_ARTICLES_FILENAME=$BOUNDS_ARTICLES_DIR/${XML_BASE_NAME}.bounds_articles.psv
		 	    BOUNDS_BANNER_FILENAME=$BOUNDS_BANNER_DIR/${XML_BASE_NAME}.bounds_banner.txt

				if [ -e $SOURCE_IMAGE_FILENAME ]; then
					echo "skipping WGET of $SOURCE_IMAGE_FILENAME: local copy exists"
				else
					wget -O $SOURCE_IMAGE_FILENAME $SOURCE_IMAGE_URL
				fi

				if [ -s $SOURCE_IMAGE_FILENAME ]; then
					echo "found non-empty $SOURCE_IMAGE_FILENAME"
					if [[ -e $CROPPED_IMAGE_FILENAME ]]; then
						echo "skipping convert of $CROPPED_IMAGE_FILENAME: local copy exists"
					else
						if [ -s $BOUNDS_ARTICLES_FILENAME ]; then
							echo "skipping WGET of XML: $BOUNDS_ARTICLES_FILENAME exists"
						else
							wget -O- $SOURCE_XML_URL | perl -ne '
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
/<pg [^>]+ pos="(.*)"\/>/ and print join("|", $mainId, $da, $dw, $imdim, $atype, $ct, $id, $ti, $1), "\n"
' > $BOUNDS_ARTICLES_FILENAME 
						fi

						if [ -s $BOUNDS_BANNER_FILENAME ]; then
							echo "skipping calc of banner bounds: $BOUNDS_BANNER_FILENAME exists"
						else
							cat $BOUNDS_ARTICLES_FILENAME | perl -ne '
BEGIN {
	$mostLeft  = 1000000;
	$mostRight = 0;
	$mostUp    = 100000;
	$mostDown  = 0;
	$mostDownFrontMatter = 0;
	$MAX_DOWN  = 1100;

}
@p = split(/\|/, $_); 
$ti = $p[5];
@coords = split(/,/, $p[8]);
if($coords[0] < $mostLeft ) { $mostLeft  = $coords[0] };
if($coords[1] < $mostUp   ) { $mostUp    = $coords[1] };
if($coords[2] > $mostRight) { $mostRight = $coords[2] };
if($coords[3] > $mostDown ) { $mostDown  = $coords[3] };
if( $ti =~ /^Front matter|Contents$/i and $coords[3] < $MAX_DOWN ){
	if($coords[3] > $mostDownFrontMatter){ $mostDownFrontMatter = $coords[3]};
}
END {
	if (($mostDownFrontMatter <= 0) or ($p[2] eq "Saturday")) {
		print "";
	} else {
		$width  = $mostRight - $mostLeft;
		$height = $mostDownFrontMatter - $mostUp; 

		if (($width % 2) == 1) { $width += 1; }
		if (($height % 2) == 1) { $height += 1; }

		print sprintf("%dx%d+%d+%d", $width, $height, $mostLeft, $mostUp);
	}
}
' > $BOUNDS_BANNER_FILENAME
						fi

						if [ -s $BOUNDS_BANNER_FILENAME ] ; then
							BOUNDS=$(cat $BOUNDS_BANNER_FILENAME)

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
ffmpeg -i ${MP4_NAME} -vf scale="${SCALED_WIDTH}:trunc(ow/a/2)*2" ${MP4_SCALED_NAME}
ffmpeg -i ${MP4_SCALED_NAME} -filter_complex "pad=height=${PAD_HEIGHT}:y=${PAD_Y_OFFSET}" ${MP4_PADDED_NAME}
