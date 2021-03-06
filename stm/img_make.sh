#!/bin/bash
#    Utility to create firmware.
#    Getopts utility options:
#    -v - Image Version (digit)
#    -d - Image Description
#    -s - stb model
#    -p - file profile (if exists)

. ../includes/initialize.sh
. ../includes/message.sh

function howTo() {
        echo " "
	echo "Usage: ./img_make.sh [-v <image version>] [-d <image description>] [-s <STB model>] [-p <path to image profile>]"
	echo "Options -v, -d and -s can be replaced with their equivalents in image profile:"
	echo " - [-v <image version>] -> IMAGE_VERSION property"
	echo " - [-d <image description>] -> IMAGE_DESCRIPTION property"
	echo " - [-s <STB model>] -> STB_MODEL property"
	echo " "
}

function not_existing() {
	read -p "[${OutputYellow}WARN!${OutputWhite}] $1 is not defined.${3} Specify its value here or Ctrl+Z to abort: " "$2"
}


# Get values

if [ $# -eq 0 ]; then
	howTo
	exit
else

while getopts ":v:d:s:p:" o; do
    case "${o}" in
        v)
            export img_ver=${OPTARG}
            ;;
        d)
            export img_desc=${OPTARG}
            ;;
	s)
	    export stb_model=${OPTARG}
	    ;;
	p)
	    img_profile=${OPTARG}
		if [ "$img_profile" != "" ]; then 
		  . $img_profile
		  . ../includes/exportVars.sh
		elif [ -f "./img_make.profile" ]; then
		  . img_make.profile
		  . ../includes/exportVars.sh
		else
		  not_existing "Path to image profile" "IMAGE_PROFILE" " You can either enter path to it or leave field blank to omit it."
		fi
		;;
        '' | * )
            howTo
	    exit
            ;;
    esac
done
shift $((OPTIND-1))

fi

# Look in image profile for metadata
[[ "$img_ver" == "" ]] && img_ver=$IMAGE_VERSION
[[ "$img_desc" == "" ]] && img_desc=$IMAGE_DESCRIPTION
[[ "$stb_model" == "" ]] && stb_model=$STB_MODEL

# Try again if one of necessary values doesn't exist

[ "$img_ver" == "" ] && not_existing "Image version" "img_ver"
[ "$img_desc" == "" ] && not_existing "Image description" "img_desc"
[ "$stb_model" == "" ] && not_existing "STB model" "stb_model"
[ "$ROOTFS_PATH" == "" ] && not_existing "Path to root file system" "ROOTFS_PATH"
[ "$KERNEL_PATH" == "" ] && not_existing "Path to kernel" "KERNEL_PATH"

export ROOTFS_PATH
export KERNEL_PATH

# If MAG 256, then HASH_TYPE = SHA256
if [[ "$stb_model" == "MAG256" && "$HASH_TYPE" != "SHA256" ]]
then
	export HASH_TYPE="SHA256"
	echo "[${OutputYellow}WARN!${OutputWhite}] MAG256 requires HASH_TYPE=SHA256. Added this setting automatically."
fi

# Get update API
if [ ! -f $ROOTFS_PATH/etc/VerUpdateAPI.conf ] ; then
    echo -e "[ ${OutputRed}ERR${OutputWhite} ] Update API version is not defined!!!\n"
    exit 1;
fi

# Look if image output exists
if [[ "$IMAGE_OUTPUT" == "" ]]; then
	export IMAGE_OUTPUT="./imageupdate"
	echo "[${OutputYellow}WARN!${OutputWhite}] The image output property was empty. Defaulting to \"./imageupdate\"..."
fi

verUpdateAPI=`cat $ROOTFS_PATH/etc/VerUpdateAPI.conf | awk '{printf  $1; exit;}'`
echo "[ ${OutputBlue}TRY${OutputWhite} ] Make rootfs image $ROOTFS_PATH"
./mk_rfs.sh $ROOTFS_PATH

# Append digital signature
echo "[ ${OutputBlue}TRY${OutputWhite} ] Append digital signature MAG200_OP_KEY=$MAG200_OP_KEY"
./mksign.sh ./sumsubfsnone.img ./sumsubfsnone.img.sign $HASH_TYPE

# Make One Image
echo "[ ${OutputGreen}OK!${OutputWhite} ] Appending okay. Proceeding to compile output firmware..."

./make_imageupdate.sh $IMAGE_OUTPUT $KERNEL_PATH ./sumsubfsnone.img.sign $img_ver $img_desc $stb_model $verUpdateAPI $HASH_TYPE
rm -f ./sumsubfsnone.img.sign ./sumsubfsnone.img
