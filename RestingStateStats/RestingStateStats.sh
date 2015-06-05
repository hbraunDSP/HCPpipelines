Path="$1"
Subject="$2"
fMRIName="$3"
HighPass="$4"
Caret7_Command="$5"
RegName="$6"
LowResMesh="$7"
FinalfMRIResolution="${8}"
BrainOrdinatesResolution="${9}"
SmoothingFWHM="${10}"
OutputProcSTRING="${11}"
dlabelFile="${12}"

forceGeneric="${13}" #vox dimensions don't quite match?

#Naming Conventions
AtlasFolder="${Path}/${Subject}/MNINonLinear"
NativeFolder="${AtlasFolder}/Native"
ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
DownsampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
ROIFolder="${AtlasFolder}/ROIs"
ICAFolder="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica"
FIXFolder="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica"

if [ ${dlabelFile} = "NONE" ] ; then
  unset dlabelFile
fi

if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
  RegName="reg"
  #RegName="MSMSulc"
fi

### Calculate CIFTI version of the bias field (which is removed as part of the fMRI minimal pre-processing)
### so that the bias field can be "restored" prior to the variance decomposition
### i.e., so that the estimate variance at each grayordinate reflects the scaling of the original data
### MG: Note that bias field correction and variance normalization are two incompatible goals

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

applywarp --rel --interp=spline -i ${AtlasFolder}/BiasField.nii.gz -r ${ResultsFolder}/${fMRIName}_SBRef.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz
fslmaths ${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz -thr 0.1 ${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz

for Hemisphere in L R ; do
	#Map bias field volume to surface using the same approach as when fMRI data are projected to the surface
	volume="${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz"
	surface="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	ribbonInner="${NativeFolder}/${Subject}.${Hemisphere}.white.native.surf.gii"
	ribbonOutter="${NativeFolder}/${Subject}.${Hemisphere}.pial.native.surf.gii"
	roiVolume="${ResultsFolder}/RibbonVolumeToSurfaceMapping/goodvoxels.nii.gz"
	$Caret7_Command -volume-to-surface-mapping $volume $surface $metricOut -ribbon-constrained $ribbonInner $ribbonOutter -volume-roi $roiVolume

	#Fill in any small holes with dilation again as is done with fMRI
	metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	surface="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	distance="10"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	$Caret7_Command -metric-dilate $metric $surface $distance $metricOut -nearest
  
  #Mask out the medial wall of dilated file
	metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	mask="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	$Caret7_Command -metric-mask $metric $mask $metricOut
	
	#Resample the surface data from the native mesh to the standard mesh
	metricIn="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
	currentSphere="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"
	newSphere="${DownsampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii"
	method="ADAP_BARY_AREA"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	currentArea="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
	newArea="${DownsampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
	roiMetric="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
	$Caret7_Command -metric-resample $metricIn $currentSphere $newSphere $method $metricOut -area-surfs $currentArea $newArea -current-roi $roiMetric
	
	#Make sure the medial wall is zeros
	metric="${ResultsFolder}/BiasField.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	mask="${DownsampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	$Caret7_Command -metric-mask $metric $mask $metricOut
	
	#Smooth the surface bias field the same as the fMRI
	surface="${DownsampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
	metricIn="${ResultsFolder}/BiasField.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	smoothingKernel="${Sigma}"
	metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii"
	roiMetric="${DownsampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
	$Caret7_Command -metric-smoothing $surface $metricIn $smoothingKernel $metricOut -roi $roiMetric
  done
  
unset POSIXLY_CORRECT
if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] && [ -z ${forceGeneric} ]; then
	#If using the same fMRI and grayordinates space resolution, use the simple algorithm to project bias field into subcortical CIFTI space like fMRI
	volumeIn="${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz"
	currentParcel="${ROIFolder}/ROIs.${BrainOrdinatesResolution}.nii.gz"
	newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
	kernel="${Sigma}"
	volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
	$Caret7_Command -volume-parcel-resampling $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
else
	#If using different fMRI and grayordinates space resolutions, use the generic algorithm to project bias field into subcortical CIFTI space like fMRI
	volumeIn="${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz"
	currentParcel="${ResultsFolder}/ROIs.${FinalfMRIResolution}.nii.gz"
	newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
	kernel="${Sigma}"
	volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
	$Caret7_Command -volume-parcel-resampling-generic $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
fi 

#Create CIFTI file of bias field as was done with fMRI
ciftiOut="${ResultsFolder}/${fMRIName}_Atlas${RegString}_BiasField.dscalar.nii"
volumeData="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
labelVolume="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
lMetric="${ResultsFolder}/BiasField.L.${LowResMesh}k_fs_LR.func.gii"
lRoiMetric="${DownsampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
rMetric="${ResultsFolder}/BiasField.R.${LowResMesh}k_fs_LR.func.gii"
rRoiMetric="${DownsampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
$Caret7_Command -cifti-create-dense-scalar $ciftiOut -volume $volumeData $labelVolume -left-metric $lMetric -roi-left $lRoiMetric -right-metric $rMetric -roi-right $rRoiMetric

Mean=`fslstats ${ResultsFolder}/BiasField.${FinalfMRIResolution}.nii.gz -k ${ResultsFolder}/${fMRIName}_SBRef.nii.gz -M`

#Someone: don't paramaterize this, it messes up Var and -var Var structure somehow
#MG: Not sure why unless you tried to change the math expression, question for Tim Coalson
$Caret7_Command -cifti-math "Var / ${Mean}" ${ResultsFolder}/${fMRIName}_Atlas${RegString}_BiasField.dscalar.nii -var Var ${ResultsFolder}/${fMRIName}_Atlas${RegString}_BiasField.dscalar.nii

### End creation of CIFTI bias field

### Proceed to run the Matlab script

motionparameters="${ResultsFolder}/Movement_Regressors" #No .txt
TR=`$FSLDIR/bin/fslval ${ResultsFolder}/${fMRIName} pixdim4`
ICAs="${ICAFolder}/melodic_mix"
if [ -e ${FIXFolder}/HandNoise.txt ] ; then
  noise="${FIXFolder}/HandNoise.txt"
else
  noise="${FIXFolder}/.fix"
fi
dtseries="${ResultsFolder}/${fMRIName}_Atlas${RegString}"
bias="${ResultsFolder}/${fMRIName}_Atlas${RegString}_BiasField.dscalar.nii"

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath('${scriptdir}');
addpath('${FSLDIR}/etc/matlab');
RestingStateStats('${motionparameters}',${HighPass},${TR},'${ICAs}','${noise}','${Caret7_Command}','${dtseries}','${bias}',[],'${dlabelFile}');
M_PROG
echo "RestingStateStats('${motionparameters}',${HighPass},${TR},'${ICAs}','${noise}','${Caret7_Command}','${dtseries}','${bias}',[],'${dlabelFile}');"

if [ -e ${ResultsFolder}/Names.txt ] ; then 
  rm ${ResultsFolder}/Names.txt
fi

Names=`cat ${dtseries}_stats.txt | head -1 | sed 's/,/ /g'`

i=1
for Name in ${Names} ; do
  if [ ${i} -gt 4 ] ; then
    echo ${Name} >> ${ResultsFolder}/Names.txt
  fi
  i=$((${i}+1))
done

#Set map names in CIFTI dscalar
ciftiIn="${ResultsFolder}/${fMRIName}_Atlas${RegString}_stats.dtseries.nii"
direction="ROW"
ciftiOut="${ResultsFolder}/${fMRIName}_Atlas${RegString}_stats.dscalar.nii"
nameFile="${ResultsFolder}/Names.txt"
$Caret7_Command -cifti-convert-to-scalar $ciftiIn $direction $ciftiOut -name-file $nameFile

rm ${ResultsFolder}/Names.txt ${ResultsFolder}/${fMRIName}_Atlas${RegString}_stats.dtseries.nii

#Set Palette in CIFTI dscalar
ciftiIn="${ResultsFolder}/${fMRIName}_Atlas${RegString}_stats.dscalar.nii"
mode="MODE_AUTO_SCALE_PERCENTAGE"
ciftiOut="${ResultsFolder}/${fMRIName}_Atlas${RegString}_stats.dscalar.nii"
$Caret7_Command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style

#Rename files for MSMAll or SingleSubjectConcat script
mv ${ResultsFolder}/${fMRIName}_Atlas${RegString}_vn.dscalar.nii ${ResultsFolder}/${fMRIName}_Atlas${RegString}${OutputProcSTRING}_vn.dscalar.nii

