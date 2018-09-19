#!/bin/bash

#ScanName=rfMRI_REST1_7T_PA
#VolumeName=rfMRI_REST1_7T_PA_sebased_bias


MeshType=32
RegName=MSMSulc

while [[ $1 == -* ]]; do
	case $1 in
		--subject=*) subject=${1/*=/""};;
		--studydir=* ) StudyFolder=${1/*=/""};;
		--scanname=*) ScanName=${1/*=/""};;
		--volfile=* ) VolumeName=${1/*=/""};;
		--out=* ) OutputName=${1/*=/""};;
		--regname=* ) RegName=${1/*=/""};;
		--meshres=* ) MeshType=${1/*=/""};;
		-h ) display_help;;
	esac
	shift;
done


#OutputType=.dtseries.nii
if [[ ${OutputName} == *.dtseries.nii ]]; then
	OutputType=.dtseries.nii
	OutputCifti=$OutputName
elif [[ ${OutputName} == *.dscalar.nii ]]; then
	OutputType=.dscalar.nii
	OutputCifti=$OutputName
else
	OutputType=.dscalar.nii
	OutputCifti=${OutputName}${OutputType}
fi

MapNames=${VolumeName}

if [ "$RegName" = "MSMSulc" ]; then
	RegSTRING=""
else
	RegSTRING="_${RegName}"
fi

ResultsFolder=${StudyFolder}/${Subject}/MNINonLinear/Results/${ScanName}
VolumefMRI=${ResultsFolder}/${VolumeName}


CARET7DIR=~/workbench_v1.2.2/bin_rh_linux64
PipelineScripts=~/Source/Pipelines/fMRISurface/scripts

export CARET7DIR


FinalfMRIResolution=$( fslval "$VolumefMRI".nii.gz pixdim1 | awk '{printf "%.02f\n",$1}' )

LowResMesh="32"
if [ "$MeshType" = "32" ]; then
	LowResMesh="32"
	GrayordinatesResolution=2
	SmoothingFWHM=2.00
elif [ "$MeshType" = "59" ]; then
	LowResMesh="59"
	GrayordinatesResolution=1.6
	SmoothingFWHM=1.60
else
	LowResMesh=""
	GrayordinatesResolution=${FinalfMRIResolution}
	SmoothingFWHM=${FinalfMRIResolution}
fi

AtlasSpaceFolder=${StudyFolder}/${Subject}/MNINonLinear
DownsampleFolder=${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k
AtlasSpaceNativeFolder=${StudyFolder}/${Subject}/MNINonLinear/Native

ROIFolder="$AtlasSpaceFolder"/ROIs


WorkingDirectory=${ResultsFolder}/RibbonVolumeToSurfaceMapping


for Hemisphere in L R ; do
  ${CARET7DIR}/wb_command -volume-to-surface-mapping "$WorkingDirectory"/goodvoxels.nii.gz "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".goodvoxels.native.func.gii -ribbon-constrained "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii
  ${CARET7DIR}/wb_command -metric-mask "$WorkingDirectory"/"$Hemisphere".goodvoxels.native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii "$WorkingDirectory"/"$Hemisphere".goodvoxels.native.func.gii
  
  ${CARET7DIR}/wb_command -metric-resample "$WorkingDirectory"/"$Hemisphere".goodvoxels.native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
  
  ${CARET7DIR}/wb_command -metric-mask "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii


  ################################

  ${CARET7DIR}/wb_command -volume-to-surface-mapping "$VolumefMRI".nii.gz "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$VolumefMRI"."$Hemisphere".native.func.gii -ribbon-constrained "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii -volume-roi "$WorkingDirectory"/goodvoxels.nii.gz
  
  ${CARET7DIR}/wb_command -metric-dilate "$VolumefMRI"."$Hemisphere".native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 10 "$VolumefMRI"."$Hemisphere".native.func.gii -nearest
  
  ${CARET7DIR}/wb_command -metric-mask  "$VolumefMRI"."$Hemisphere".native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii  "$VolumefMRI"."$Hemisphere".native.func.gii
  
  ${CARET7DIR}/wb_command -metric-resample "$VolumefMRI"."$Hemisphere".native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
  
  ${CARET7DIR}/wb_command -metric-mask "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii
done

"$PipelineScripts"/SurfaceSmoothing.sh "$ResultsFolder"/"${VolumeName}" "$Subject" "$DownsampleFolder" "$LowResMesh" "$SmoothingFWHM"

"$PipelineScripts"/SubcorticalProcessing.sh "$AtlasSpaceFolder" "$ROIFolder" "$FinalfMRIResolution" "$ResultsFolder" "${VolumeName}" "$SmoothingFWHM" "$GrayordinatesResolution" 

####"$PipelineScripts"/CreateDenseTimeseries.sh "$DownsampleFolder" "$Subject" "$LowResMesh" "$ResultsFolder"/"${VolumeName}" "$SmoothingFWHM" "$ROIFolder" "$ResultsFolder"/"$OutputAtlasDenseTimeseries" "$GrayordinatesResolution"

if [ "$OutputType" = ".dtseries.nii" ]; then
	TR_vol=`fslval "$ResultsFolder"/"${VolumeName}" pixdim4 | cut -d " " -f 1`
	${CARET7DIR}/wb_command -cifti-create-dense-timeseries "${ResultsFolder}/$OutputCifti" -volume "${VolumefMRI}"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/Atlas_ROIs."$GrayordinatesResolution".nii.gz -left-metric "${VolumefMRI}"_s"$SmoothingFWHM".atlasroi.L."$LowResMesh"k_fs_LR.func.gii -roi-left "$DownsampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii -right-metric "${VolumefMRI}"_s"$SmoothingFWHM".atlasroi.R."$LowResMesh"k_fs_LR.func.gii -roi-right "$DownsampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii -timestep "$TR_vol"

elif [ "$OutputType" = ".dscalar.nii" ]; then
	tmpd=`mktemp -d`
	
	echo ${MapNames} | tr "@" "\n" > ${tmpd}/mapnames.txt
	
	${CARET7DIR}/wb_command -cifti-create-dense-scalar "${ResultsFolder}/$OutputCifti" -volume "${VolumefMRI}"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/Atlas_ROIs."$GrayordinatesResolution".nii.gz -left-metric "${VolumefMRI}"_s"$SmoothingFWHM".atlasroi.L."$LowResMesh"k_fs_LR.func.gii -roi-left "$DownsampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii -right-metric "${VolumefMRI}"_s"$SmoothingFWHM".atlasroi.R."$LowResMesh"k_fs_LR.func.gii -roi-right "$DownsampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii -name-file ${tmpd}/mapnames.txt
	
	rm -rf ${tmpd}
fi


