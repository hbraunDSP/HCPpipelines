# Upsampling before averaging does not seem to buy anything, so let's just forget this for now

#!/bin/bash 
set -e

Usage() {
    echo ""
    echo "Usage: `basename $0` [options] <image1> ... <imageN>"
    echo ""
    echo "Compulsory arguments"
    echo "  -o <name>        : output basename"
    echo "Optional arguments"
    echo "  -s <image>       : standard image (e.g. MNI152_T1_2mm)"
    echo "  -m <image>       : standard brain mask (e.g. MNI152_T1_2mm_brain_mask_dil)"
    echo "  -n               : do not crop images"
    echo "  -w <dir>         : local, temporary working directory (to be cleaned up - i.e. deleted)"
    echo "  -b <brain mm>    : size of brain in z-dimension for robustfov (default 170mm)"
    echo "  -r <res>         : higher resolution to use during transformation"
    echo "  --nii            : use uncompressed nii for files in working directory (faster)"
    echo "  --noclean        : do not run the cleanup"
    echo "  -v               : verbose output"
    echo "  -h               : display this help message"
    echo ""
    echo "e.g.:  `basename $0` -n -o output_name  im1 im2"
    echo "       Note that N>=2 (i.e. there must be at least two images in the list)"
    exit 1
}

get_arg2() {
    if [ X$2 = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    fi
    echo $2
}

#########################################################################################################

# deal with options
crop=yes
verbose=no
wdir=
UpsampleRes=
cleanup=yes
usenifti=no
StandardImage=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz
StandardMask=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz

if [ $# -eq 0 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$1
    case "$iarg"
	in
	-n)
	    crop=no; 
	    shift;;
	-o)
	    output=`get_arg2 $1 $2`;
	    shift 2;;
	-s)
	    StandardImage=`get_arg2 $1 $2`;
	    shift 2;;
	-m)
	    StandardMask=`get_arg2 $1 $2`;
	    shift 2;;
	-w)
	    wdir=`get_arg2 $1 $2`;
	    cleanup=no;
	    shift 2;;
	-b)
	    BrainSizeOpt=`get_arg2 $1 $2`;
	    BrainSizeOpt="-b $BrainSizeOpt";
	    shift 2;;
	-r)
	    UpsampleRes=`get_arg2 $1 $2`;
	    shift 2;;
	-v)
	    verbose=yes; 
	    shift;;
	-h)
	    Usage;
	    exit 0;;
	--noclean)
	    cleanup=no;
	    shift;;
	--nii)
	    usenifti=yes;
	    shift;;
	*)
	    if [ `echo $1 | sed 's/^\(.\).*/\1/'` = "-" ] ; then 
		echo "Unrecognised option $1" 1>&2
		exit 1
	    fi
	    imagelist="$imagelist $1"
	    shift;;
    esac
done


if [ X$output = X ] ; then
  echo "The compulsory argument -o MUST be used"
  exit 1;
fi

if [ `echo $imagelist | wc -w` -lt 2 ] ; then
  Usage;
  echo " "
  echo "Must specify at least two images to average"
  exit 1;
fi

# setup working directory
if [ X$wdir = X ] ; then
    wdir=`$FSLDIR/bin/tmpnam`;
    wdir=${wdir}_wdir
fi
if [ ! -d $wdir ] ; then
    if [ -f $wdir ] ; then 
	echo "A file already exists with the name $wdir - cannot use this as the working directory"
	exit 1;
    fi
    mkdir $wdir
fi

im1=`echo $imagelist | awk '{print $1}'`
OrigRes=`$FSLDIR/bin/fslval $im1 pixdim1`
OrigRes=$( printf "%.6f\n" $OrigRes )
if [ X$UpsampleRes = X ] ; then
	UpsampleRes=$OrigRes
fi
UpsampleRes=$( printf "%.6f\n" $UpsampleRes )

origfmt=$FSLOUTPUTTYPE
if [ $usenifti = yes ] ; then
	export FSLOUTPUTTYPE=NIFTI
fi

# process imagelist
newimlist=""
for fn in $imagelist ; do
    bnm=`$FSLDIR/bin/remove_ext $fn`;
    bnm=`basename $bnm`;
    res=$( printf "%.6f\n" `$FSLDIR/bin/fslval $fn pixdim1` );
    if [ "$res" = "$UpsampleRes" ]; then
		echo "Already at upsample res: $fn"
		$FSLDIR/bin/imln $fn $wdir/$bnm   ## TODO - THIS FAILS WHEN GIVEN RELATIVE PATHS
    else
		echo "Upsampling: $fn"
		$FSLDIR/bin/flirt -in $fn -ref $fn -out $wdir/$bnm -applyisoxfm $UpsampleRes -interp spline
    fi
    newimlist="$newimlist $wdir/$bnm"
done

if [ $verbose = yes ] ; then echo "Images: $imagelist  Output: $output"; fi


im1=`echo $newimlist | awk '{ print $1 }'`;
# for each image reorient, register to std space, (optionally do "get transformed FOV and crop it based on this")
for fn in $newimlist ; do
  $FSLDIR/bin/fslreorient2std ${fn} ${fn}_reorient
  $FSLDIR/bin/robustfov -i ${fn}_reorient -r ${fn}_roi -m ${fn}_roi2orig.mat $BrainSizeOpt
  $FSLDIR/bin/convert_xfm -omat ${fn}TOroi.mat -inverse ${fn}_roi2orig.mat
  if [ $fn = $im1 ] ; then
	  $FSLDIR/bin/flirt -in ${fn}_roi -ref "$StandardImage" -omat ${fn}roi_to_std.mat -out ${fn}roi_to_std -dof 12 -searchrx -30 30 -searchry -30 30 -searchrz -30 30
	  $FSLDIR/bin/convert_xfm -omat ${fn}_std2roi.mat -inverse ${fn}roi_to_std.mat
  fi
done

outtxt=$wdir/tmpjobstatus_`date +%Y%m%d%H%M%S%N`.txt
rm -f $outtxt
touch $outtxt

totaljobs=0
# register images together, using standard space brain masks
im1=`echo $newimlist | awk '{ print $1 }'`;
for im2 in $newimlist ; do
    if [ $im2 != $im1 ] ; then

		{ 
		# register version of two images (whole heads still)
		$FSLDIR/bin/flirt -in ${im2}_roi -ref ${im1}_roi -omat ${im2}_to_im1.mat -out ${im2}_to_im1 -dof 6 -searchrx -30 30 -searchry -30 30 -searchrz -30 30

		# re-register using the brain mask as a weighting image
		$FSLDIR/bin/flirt -in ${im2}_roi -init ${im2}_to_im1.mat -omat ${im2}_to_im1_linmask.mat -out ${im2}_to_im1_linmask -ref ${im1}_roi -refweight ${im1}_roi_linmask -nosearch
		echo " done " >> $outtxt
		} &
		
		totaljobs=$((totaljobs+1))
    else
        # transform std space brain mask
		$FSLDIR/bin/flirt -init ${im1}_std2roi.mat -in "$StandardMask" -ref ${im1}_roi -out ${im1}_roi_linmask -applyxfm
		cp $FSLDIR/etc/flirtsch/ident.mat ${im1}_to_im1_linmask.mat
		totaljobs=$((totaljobs+1))
		echo " done " >> $outtxt
    fi
done

while [ : ]; do
	numcomplete=`cat $outtxt | wc -w`
	echo `date +"%Y-%m-%d %H:%M"`": completed $numcomplete out of $totaljobs"
	if [[ $numcomplete = $totaljobs ]]; then
		break
	fi
	sleep 60
done

rm -f $outtxt

# get the halfway space transforms (midtrans output is the *template* to halfway transform)
translist=""
for fn in $newimlist ; do translist="$translist ${fn}_to_im1_linmask.mat" ; done
$FSLDIR/bin/midtrans --separate=${wdir}/ToHalfTrans --template=${im1}_roi $translist

# interpolate
n=1;
for fn in $newimlist ; do
    num=`$FSLDIR/bin/zeropad $n 4`;
    n=`echo $n + 1 | bc`;
    if [ $crop = yes ] ; then
	$FSLDIR/bin/applywarp --rel -i ${fn}_roi --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_roi -o ${wdir}/ImToHalf${num} --interp=spline
    else
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${wdir}/ToHalfTrans${num}.mat ${fn}TOroi.mat
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${im1}_roi2orig.mat ${wdir}/ToHalfTrans${num}.mat
	$FSLDIR/bin/applywarp --rel -i ${fn}_reorient --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_reorient -o ${wdir}/ImToHalf${num} --interp=spline  
    fi
done


# average outputs
comm=`echo ${wdir}/ImToHalf* | sed "s@ ${wdir}/ImToHalf@ -add ${wdir}/ImToHalf@g"`;
tot=`echo ${wdir}/ImToHalf* | wc -w`;

if [ "$OrigRes" != "$UpsampleRes" ]; then
    bnm=`$FSLDIR/bin/remove_ext $output`;
    bnm=`basename $bnm`;
    output_hires=$wdir/${bnm}_hires
	$FSLDIR/bin/fslmaths ${comm} -div $tot ${output_hires}

	export FSLOUTPUTTYPE=$origfmt
	$FSLDIR/bin/flirt -in ${output_hires} -ref ${output_hires} -out ${output} -applyisoxfm $OrigRes -interp spline
else
	export FSLOUTPUTTYPE=$origfmt
	$FSLDIR/bin/fslmaths ${comm} -div $tot ${output}
fi


# CLEANUP
if [ $cleanup != no ] ; then
    # the following protects the rm -rf call (making sure that it is not null and really is a directory)
    if [ X$wdir != X ] ; then
	if [ -d $wdir ] ; then
	    # should be safe to call here without trying to remove . or $HOME or /
	    rm -rf $wdir
	fi
    fi
fi

