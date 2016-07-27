#!/bin/bash
         STOP_FILE=STOP
  ARCHIVE_BASE_URL=http://newspaperarchive.ftroot.com
BANNER_CROP_HEIGHT=1000
 BANNER_CROP_WIDTH=5000
     EXTENT_HEIGHT=2814
         CROPS_DIR=./crops
     ORIGINALS_DIR=./originals
    ANIMATIONS_DIR=./animations
   ANIMATION_DELAY=1
         FRAMERATE=10
      SCALED_WIDTH=1080
        PAD_HEIGHT=608
      PAD_Y_OFFSET=196

mkdir -p $CROPS_DIR
mkdir -p $ORIGINALS_DIR
mkdir -p $ANIMATIONS_DIR

MP4_BASE_NAME=$1

error()
{
    echo "error: $*"
    exit 1;
}

command -v convert >/dev/null 2>&1 || error "Missing program, 'convert'. You need ImageMagick installed."
command -v ffmpeg  >/dev/null 2>&1 || error "Missing program, 'ffmpeg'."
command -v wget    >/dev/null 2>&1 || error "Missing program, 'wget'."

if [[ "$MP4_BASE_NAME" = "" ]]; then # for now, any arg means skip creating crops

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
				      SOURCE_IMAGE_URL=$ARCHIVE_BASE_URL/all_years/$YEAR/$YMD/$SOURCE_IMAGE_NAME
				 SOURCE_IMAGE_FILENAME=$ORIGINALS_DIR/$SOURCE_IMAGE_NAME
				    CROPPED_IMAGE_NAME=${IMAGE_BASE_NAME}-cropped-to-banner.JPG
				CROPPED_IMAGE_FILENAME=$CROPS_DIR/$CROPPED_IMAGE_NAME

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
						convert \
							-crop "${BANNER_CROP_WIDTH}x${BANNER_CROP_HEIGHT}+0+0" \
							$SOURCE_IMAGE_FILENAME \
							$CROPPED_IMAGE_FILENAME
					fi
				fi
			done
		done
	done
fi

if [[ "$MP4_BASE_NAME" = "" ]]; then
	MP4_BASE_NAME=${ANIMATIONS_DIR}/basic_ff_r${FRAMERATE}
fi

       MP4_NAME=${MP4_BASE_NAME}.mp4
MP4_SCALED_NAME=${MP4_BASE_NAME}_size${SCALED_WIDTH}.mp4
MP4_PADDED_NAME=${MP4_BASE_NAME}_size${SCALED_WIDTH}_padheight${PAD_HEIGHT}.mp4

ffmpeg -framerate $FRAMERATE -pattern_type glob -i "${CROPS_DIR}/*.JPG" -c:v libx264 -r 30 -pix_fmt yuv420p ${MP4_NAME}
ffmpeg -i ${MP4_NAME} -vf scale=${SCALED_WIDTH}:-1 ${MP4_SCALED_NAME}
ffmpeg -i ${MP4_SCALED_NAME} -filter_complex "pad=height=${PAD_HEIGHT}:y=${PAD_Y_OFFSET}" ${MP4_PADDED_NAME}
