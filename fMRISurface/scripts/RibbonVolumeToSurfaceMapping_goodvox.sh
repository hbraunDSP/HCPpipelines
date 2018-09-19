#!/bin/bash 
set -e
echo -e "\n START: RibbonVolumeToSurfaceMapping"

WorkingDirectory="$1"
VolumefMRI="$2"
Subject="$3"
DownsampleFolder="$4"
LowResMesh="$5"
AtlasSpaceNativeFolder="$6"
RegName="$7"

if [ ${RegName} = "FS" ]; then
    RegName="reg.reg_LR"
fi

NeighborhoodSmoothing="5"
Factor="0.5"


LeftGreyRibbonValue="1"
RightGreyRibbonValue="1"

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
  fi    
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$VolumefMRI"_SBRef.nii.gz "$WorkingDirectory"/"$Subject"."$Hemisphere".white.native.nii.gz
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$VolumefMRI"_SBRef.nii.gz "$WorkingDirectory"/"$Subject"."$Hemisphere".pial.native.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$WorkingDirectory"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$WorkingDirectory"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$WorkingDirectory"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$WorkingDirectory"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$WorkingDirectory"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$WorkingDirectory"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$WorkingDirectory"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$WorkingDirectory"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$WorkingDirectory"/"$Subject"."$Hemisphere".white.native.nii.gz "$WorkingDirectory"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$WorkingDirectory"/"$Subject"."$Hemisphere".pial.native.nii.gz "$WorkingDirectory"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
done

fslmaths "$WorkingDirectory"/"$Subject".L.ribbon.nii.gz -add "$WorkingDirectory"/"$Subject".R.ribbon.nii.gz "$WorkingDirectory"/ribbon_only.nii.gz
rm "$WorkingDirectory"/"$Subject".L.ribbon.nii.gz "$WorkingDirectory"/"$Subject".R.ribbon.nii.gz

fslmaths "$VolumefMRI" -Tmean "$WorkingDirectory"/mean -odt float
fslmaths "$VolumefMRI" -Tstd "$WorkingDirectory"/std -odt float
fslmaths "$WorkingDirectory"/std -div "$WorkingDirectory"/mean "$WorkingDirectory"/cov

fslmaths "$WorkingDirectory"/cov -mas "$WorkingDirectory"/ribbon_only.nii.gz "$WorkingDirectory"/cov_ribbon

fslmaths "$WorkingDirectory"/cov_ribbon -div `fslstats "$WorkingDirectory"/cov_ribbon -M` "$WorkingDirectory"/cov_ribbon_norm
fslmaths "$WorkingDirectory"/cov_ribbon_norm -bin -s $NeighborhoodSmoothing "$WorkingDirectory"/SmoothNorm
fslmaths "$WorkingDirectory"/cov_ribbon_norm -s $NeighborhoodSmoothing -div "$WorkingDirectory"/SmoothNorm -dilD "$WorkingDirectory"/cov_ribbon_norm_s$NeighborhoodSmoothing
fslmaths "$WorkingDirectory"/cov -div `fslstats "$WorkingDirectory"/cov_ribbon -M` -div "$WorkingDirectory"/cov_ribbon_norm_s$NeighborhoodSmoothing "$WorkingDirectory"/cov_norm_modulate
fslmaths "$WorkingDirectory"/cov_norm_modulate -mas "$WorkingDirectory"/ribbon_only.nii.gz "$WorkingDirectory"/cov_norm_modulate_ribbon

STD=`fslstats "$WorkingDirectory"/cov_norm_modulate_ribbon -S`
echo $STD
MEAN=`fslstats "$WorkingDirectory"/cov_norm_modulate_ribbon -M`
echo $MEAN
Lower=`echo "$MEAN - ($STD * $Factor)" | bc -l`
echo $Lower
Upper=`echo "$MEAN + ($STD * $Factor)" | bc -l`
echo $Upper

fslmaths "$WorkingDirectory"/mean -bin "$WorkingDirectory"/mask
fslmaths "$WorkingDirectory"/cov_norm_modulate -thr $Upper -bin -sub "$WorkingDirectory"/mask -mul -1 "$WorkingDirectory"/goodvoxels


echo " END: RibbonVolumeToSurfaceMapping"

