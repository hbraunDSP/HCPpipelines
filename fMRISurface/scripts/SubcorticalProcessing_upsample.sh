#!/bin/bash 
set -e
script_name="SubcorticalProcessing_upsample.sh"
echo "${script_name}: START"

AtlasSpaceFolder="$1"
echo "${script_name}: AtlasSpaceFolder: ${AtlasSpaceFolder}"

ROIFolder="$2"
echo "${script_name}: ROIFolder: ${ROIFolder}"

FinalfMRIResolution="$3"
echo "${script_name}: FinalfMRIResolution: ${FinalfMRIResolution}"

ResultsFolder="$4"
echo "${script_name}: ResultsFolder: ${ResultsFolder}"

NameOffMRI="$5"
echo "${script_name}: NameOffMRI: ${NameOffMRI}"

SmoothingFWHM="$6"
echo "${script_name}: SmoothingFWHM: ${SmoothingFWHM}"

BrainOrdinatesResolution="$7"
echo "${script_name}: BrainOrdinatesResolution: ${BrainOrdinatesResolution}"

ForceGeneric="$8"
echo "${script_name}: ForceGenericResampling: ${ForceGeneric}"

UnmaskedVolumefMRI="$9"
echo "${script_name}: UnmaskedVolumefMRI: ${UnmaskedVolumefMRI}"

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
echo "${script_name}: VolumefMRI: ${VolumefMRI}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
echo "${script_name}: Sigma: ${Sigma}"

unset POSIXLY_CORRECT

ForceGeneric=`echo $ForceGeneric 0 | awk '{print $1}'`
unset VolumeTemp

if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] && [ "${ForceGeneric}" = 0 ]; then
	echo "${script_name}: Doing volume parcel resampling without first applying warp"
	${CARET7DIR}/wb_command -volume-parcel-resampling "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
else
	echo "${script_name}: Creating subcortical ROI volume in original fMRI resolution"
	cp "$GrayordinatesSpaceDIR"/Atlas_ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$FinalfMRIResolution".nii.gz

	applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$ROIFolder"/Atlas_ROIs."$FinalfMRIResolution".nii.gz -o "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
	${CARET7DIR}/wb_command -volume-label-import "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz ${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
	#for some reason this is coming out as LPI, so reorient
	${CARET7DIR}/wb_command -volume-reorient "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz RPI "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz
	
	rm "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz

	
	echo "${script_name}: spline resampling before volume parcel resampling"
	VolumeTemp="$VolumefMRI"_tmp"$BrainOrdinatesResolution"
	
	if [ -e "$UnmaskedVolumefMRI" ]; then
		echo "${script_name}: Using unmasked version of input data for upsampling"
		inputfmri=$UnmaskedVolumefMRI
	else
		dilcount=4

		dilarg=
		for i in `seq 1 $dilcount`; do
			dilarg+=" -dilM "
		done
		
		echo "${script_name}: Using ${dilcount}x dilated masked input for upsampling"
		
		fslmaths "$VolumefMRI".nii.gz $dilarg "$VolumeTemp".nii.gz
		inputfmri="$VolumeTemp".nii.gz
	fi
	
	FinalfMRIResolution=`echo "scale=2; $BrainOrdinatesResolution/1.0" | bc -l`;
	#applywarp is has less distant ringing than flirt (maybe just a datatype/precision thing?)
	#flirt -in "$inputfmri" -ref "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz -out "$VolumeTemp".nii.gz -applyisoxfm "$BrainOrdinatesResolution" -interp spline
	BrainMask="$ResultsFolder"/brainmask_fs."$FinalfMRIResolution".nii.gz

	#make new res brainmask
	${FSLDIR}/bin/applywarp --rel --interp=nn -i ${AtlasSpaceFolder}/brainmask_fs.nii.gz -r "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$BrainMask"

	applywarp -i $inputfmri -r "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz -o "$VolumeTemp".nii.gz -m "$BrainMask" --interp=spline 


	echo "${script_name}: Doing applywarp and volume label import"
	applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz -o "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
	${CARET7DIR}/wb_command -volume-label-import "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz ${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
	echo "${script_name}: Doing volume parcel resampling after applying warp and doing a volume label import"
	${CARET7DIR}/wb_command -volume-parcel-resampling-generic "$VolumeTemp".nii.gz "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
	rm "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
	rm -f "$VolumeTemp".nii.gz
fi


echo "${script_name}: END"

