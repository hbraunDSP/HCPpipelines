#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "GenericfMRISurfaceProcessingPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`  # "$1"
Subject=`opts_GetOpt1 "--subject" $@`  # "$2"
NameOffMRI=`opts_GetOpt1 "--fmriname" $@`  # "$6"
LowResMesh=`opts_GetOpt1 "--lowresmesh" $@`  # "$6"
FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  # "${14}"
SmoothingFWHM=`opts_GetOpt1 "--smoothingFWHM" $@`  # "${14}"
GrayordinatesResolution=`opts_GetOpt1 "--grayordinatesres" $@`  # "${14}"
RegName=`opts_GetOpt1 "--regname" $@`
FinalSpace=`opts_GetOpt1 "--finalspace" $@`
FMRISuffix=`opts_GetOpt1 "--fmrisuffix" $@`
ForceGenericResampling=`opts_GetOpt1 "--forcegeneric" $@`
UseMappingSuffix=`opts_GetOpt1 "--usemappingsuffix" $@`
ForceUpsample=`opts_GetOpt1 "--upsample" $@`
UnmaskedInput=`opts_GetOpt1 "--unmasked" $@`

if [ "${RegName}" = "" ]; then
    RegName="FS"
fi
NameOffMRI_withsuffix="${NameOffMRI}${FMRISuffix}"

RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

log_Msg "Path: ${Path}"
log_Msg "Subject: ${Subject}"
log_Msg "NameOffMRI: ${NameOffMRI}"
log_Msg "LowResMesh: ${LowResMesh}"
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"
log_Msg "SmoothingFWHM: ${SmoothingFWHM}"
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"
log_Msg "RegName: ${RegName}"
log_Msg "FMRISuffix: ${FMRISuffix}"
log_Msg "RUN: ${RUN}"

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRISurf}

#Naming Conventions
AtlasSpaceFolder="MNINonLinear"
T1wFolder="T1w"
NativeFolder="Native"
ResultsFolder="Results"
DownSampleFolder="fsaverage_LR${LowResMesh}k"
ROIFolder="ROIs"
OutputAtlasDenseTimeseries="${NameOffMRI_withsuffix}_Atlas"

if [ "${FinalSpace}" = "Native" ]; then
    AtlasSpaceFolder=${T1wFolder}
fi

AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
T1wFolder="$Path"/"$Subject"/"$T1wFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"
ROIFolder="$AtlasSpaceFolder"/"$ROIFolder"

#Make fMRI Ribbon
#Noisy Voxel Outlier Exclusion
#Ribbon-based Volume to Surface mapping and resampling to standard surface

if [ `imtest "$ResultsFolder"/"${NameOffMRI_withsuffix}_SBRef"` = 0 ]; then
	imln "$ResultsFolder"/"${NameOffMRI}_SBRef" "$ResultsFolder"/"${NameOffMRI_withsuffix}_SBRef" 
fi

wdir="$ResultsFolder"/RibbonVolumeToSurfaceMapping${FMRISuffix}

log_Msg "Make fMRI Ribbon"
log_Msg "mkdir -p ${wdir}"
mkdir -p ${wdir}

if [ "X$UseMappingSuffix" = "X" ]; then
	"$PipelineScripts"/RibbonVolumeToSurfaceMapping.sh ${wdir} "$ResultsFolder"/"${NameOffMRI_withsuffix}" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$AtlasSpaceFolder"/"$NativeFolder" "${RegName}"
else
	UseMappingSuffix=`echo $UseMappingSuffix | awk -F: '{print $2}'`
	MappingTCS="$ResultsFolder"/"${NameOffMRI}${UseMappingSuffix}"
	log_Msg "Using alternate fMRI series for goodvoxels.nii.gz mask: ${MappingTCS}"
	"$PipelineScripts"/RibbonVolumeToSurfaceMapping_goodvox.sh ${wdir} "${MappingTCS}" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$AtlasSpaceFolder"/"$NativeFolder" "${RegName}"
	"$PipelineScripts"/RibbonVolumeToSurfaceMapping_usemap.sh ${wdir} "$ResultsFolder"/"${NameOffMRI_withsuffix}" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$AtlasSpaceFolder"/"$NativeFolder" "${RegName}"
fi

#Surface Smoothing
log_Msg "Surface Smoothing"
"$PipelineScripts"/SurfaceSmoothing.sh "$ResultsFolder"/"${NameOffMRI_withsuffix}" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$SmoothingFWHM"

#Subcortical Processing
log_Msg "Subcortical Processing"
if [ "X$ForceUpsample" = "X" ]; then
	"$PipelineScripts"/SubcorticalProcessing.sh "$AtlasSpaceFolder" "$ROIFolder" "$FinalfMRIResolution" "$ResultsFolder" "${NameOffMRI_withsuffix}" "$SmoothingFWHM" "$GrayordinatesResolution" "$ForceGenericResampling"
else
	"$PipelineScripts"/SubcorticalProcessing_upsample.sh "$AtlasSpaceFolder" "$ROIFolder" "$FinalfMRIResolution" "$ResultsFolder" "${NameOffMRI_withsuffix}" "$SmoothingFWHM" "$GrayordinatesResolution" "$ForceGenericResampling" "$UnmaskedInput"
fi

#Generation of Dense Timeseries
log_Msg "Generation of Dense Timeseries"
"$PipelineScripts"/CreateDenseTimeseries.sh "$AtlasSpaceFolder"/"$DownSampleFolder" "$Subject" "$LowResMesh" "$ResultsFolder"/"${NameOffMRI_withsuffix}" "$SmoothingFWHM" "$ROIFolder" "$ResultsFolder"/"$OutputAtlasDenseTimeseries" "$GrayordinatesResolution"

log_Msg "Completed"
