# experimenting with cropping of the archive issues

## specifically, the banner

To generate the crop of each issue's banner, 

`$ ./grab_and_crop.sh`

which will loop over every year/month/1st day

* grabbing the JPG of the first page, into ./originals
* then cropping it using ImageMagick, into ./crops
   * NB, the crops are very basic: the first 1000 lines of pixels, 5000 wide.

If a image has already been downloaded, it will not be re-fetched.
If a crop has already been done, it will not be re-done.

Once all the crops are done, an mp4 animation of the ./crops images will be generated into ./animations

* full 5000x1000
* scaled to 1080 width
* padded to near 16x9 ratio

To skip the cropping and just generate the animation, specify the base mp4 filename as an argument, e.g.

`$ ./grab_and_crop.sh ./animations/a_quick_test`

# To Do

* read the XML to get a tighter bounding box around the banner
* skip Saturdays (cos recent years have a very different layout)
* tint the crop to be pink
