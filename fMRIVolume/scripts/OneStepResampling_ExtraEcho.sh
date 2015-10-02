#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script to combine warps and affine transforms together and do a single resampling, with specified output resolution"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working dir>"
  echo "             --infmri=<input fMRI 4D image>"
  echo "             --extrafmri=<additional fMRI 4D image (eg: multi-echo)>"
  echo "             --t1=<input T1w restored image>"
  echo "             --fmriresout=<output resolution for images, typically the fmri resolution>"
  echo "             --fmrifolder=<fMRI processing folder>"
  echo "             --atlasspacedir=<output directory for several resampled images>"
  echo "             --fmri2structin=<input fMRI to T1w warp>"
  echo "             --struct2std=<input T1w to MNI warp, or blank to leave data in T1w space>"
  echo "             --owarp=<output fMRI to MNI warp>"
  echo "             --oiwarp=<output MNI to fMRI warp>"
  echo "             --motionmatdir=<input motion correcton matrix directory>"
  echo "             --motionmatprefix=<input motion correcton matrix filename prefix>"
  echo "             --ofmri=<input fMRI 4D image>"
  echo "             --freesurferbrainmask=<input FreeSurfer brain mask, nifti format in T1w space>"
  echo "             --biasfield=<input biasfield image, in T1w space>"
  echo "             --gdfield=<input warpfield for gradient non-linearity correction>"
  echo "             --scoutin=<input scout image (EPI pre-sat, before gradient non-linearity distortion correction)>"
  echo "             --scoutgdcin=<input scout gradient nonlinearity distortion corrected image (EPI pre-sat)>"
  echo "             --oscout=<output transformed + distortion corrected scout image>"
  echo "             --jacobianin=<input Jacobian image>"
  echo "             --ojacobian=<output transformed + distortion corrected Jacobian image>"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD): 
#         NB: all these images are in standard space 
#             but at the specified resolution (to match the fMRI - i.e. low-res)
#     ${T1wImageFile}.${FinalfMRIResolution}  
#     ${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
#     ${BiasFieldFile}.${FinalfMRIResolution}  
#     Scout_gdc_MNI_warp     : a warpfield from original (distorted) scout to low-res MNI
#
# Outputs (not in either of the above):
#     ${OutputTransform}  : the warpfield from fMRI to standard (low-res)
#     ${OutputfMRI}       
#     ${JacobianOut}
#     ${ScoutOutput}
#          NB: last three images are all in low-res standard space

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
InputfMRI=`getopt1 "--infmri" $@`  # "$2"
T1wImage=`getopt1 "--t1" $@`  # "$3"
FinalfMRIResolution=`getopt1 "--fmriresout" $@`  # "$4"
fMRIFolder=`getopt1 "--fmrifolder" $@`
fMRIToStructuralInput=`getopt1 "--fmri2structin" $@`  # "$6"
StructuralToStandard=`getopt1 "--struct2std" $@`  # "$7"
OutputTransform=`getopt1 "--owarp" $@`  # "$8"
OutputInvTransform=`getopt1 "--oiwarp" $@`
MotionMatrixFolder=`getopt1 "--motionmatdir" $@`  # "$9"
MotionMatrixPrefix=`getopt1 "--motionmatprefix" $@`  # "${10}"
OutputfMRI=`getopt1 "--ofmri" $@`  # "${11}"
FreeSurferBrainMask=`getopt1 "--freesurferbrainmask" $@`  # "${12}"
BiasField=`getopt1 "--biasfield" $@`  # "${13}"
GradientDistortionField=`getopt1 "--gdfield" $@`  # "${14}"
ScoutInput=`getopt1 "--scoutin" $@`  # "${15}"
ScoutInputgdc=`getopt1 "--scoutgdcin" $@`  # "${15}"
ScoutOutput=`getopt1 "--oscout" $@`  # "${16}"
JacobianIn=`getopt1 "--jacobianin" $@`  # "${17}"
JacobianOut=`getopt1 "--ojacobian" $@`  # "${18}"

ExtrafMRI=`getopt1 "--extrafmri" $@`  # "$2"
OutputExtrafMRI=`getopt1 "--oextrafmri" $@`  # "$2"
ExtrafMRISuffix=`getopt1 "--extrafmrisuffix" $@`  # "$2"

BiasFieldFile=`basename "$BiasField"`
T1wImageFile=`basename $T1wImage`
FreeSurferBrainMaskFile=`basename "$FreeSurferBrainMask"`



echo " "
echo " START: OneStepResampling_MultiEcho"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

#############################################################################################
if [ "X$ExtrafMRISuffix" = X ]; then
	prevol_new=`mktemp --tmpdir=${WD} prevols.XXXXXXXXXX`
	postvol_new=${WD}/`basename ${prevol_new} | sed 's/prevols/postvols/'`
else
	prevol_new="${WD}/prevols${ExtrafMRISuffix}"
	postvol_new="${WD}/postvols${ExtrafMRISuffix}"
fi

if [ "X$OutputExtrafMRI" = X ] && [ ! "X$ExtrafMRISuffix" = X ]; then
	OutputExtrafMRI="${OutputfMRI}${ExtrafMRISuffix}"
fi

if [ "X$OutputExtrafMRI" = X ]; then
	echo "Error: No valid output name given for extrafmri"
	exit 1
fi

mkdir -p ${prevol_new}
mkdir -p ${postvol_new}

########################################## DO WORK ########################################## 

#Save TR for later
TR_vol=`${FSLDIR}/bin/fslval ${InputfMRI} pixdim4 | cut -d " " -f 1`
NumFrames=`${FSLDIR}/bin/fslval ${InputfMRI} dim4`

${FSLDIR}/bin/fslsplit ${ExtrafMRI} ${prevol_new}/vol -t


FrameMergeSTRING=""
k=0
while [ $k -lt $NumFrames ] ; do
  vnum=`${FSLDIR}/bin/zeropad $k 4`

	if [ "X$fMRIToStructuralInput" = X ] && [ "X$StructuralToStandard" = X ]; then
		ref=${WD}/prevols/vol${vnum}.nii.gz
		xform=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz
	elif [ "X$StructuralToStandard" = X ]; then
		# Assumes that StructuralToStandard was also blank for original call
		ref=${WD}/${T1wImageFile}.${FinalfMRIResolution}
		xform=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz
	else
		ref=${WD}/${T1wImageFile}.${FinalfMRIResolution}
		xform=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz
	fi
    ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${prevol_new}/vol${vnum}.nii.gz --warp=${xform} --ref=${ref} --out=${postvol_new}/vol${k}.nii.gz

  FrameMergeSTRING="${FrameMergeSTRING}${postvol_new}/vol${k}.nii.gz " 
  k=`echo "$k + 1" | bc`
done

# Merge together results and restore the TR (saved beforehand)

${FSLDIR}/bin/fslmerge -tr ${OutputExtrafMRI} $FrameMergeSTRING $TR_vol

echo " "
echo "END: OneStepResampling_MultiEcho"
echo " END: `date`" >> $WD/log.txt

