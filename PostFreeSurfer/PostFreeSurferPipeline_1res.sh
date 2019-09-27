#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6 or later)
#  environment: HCPPIPEDIR

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
else
  echo "${script_name}: HCPPIPEDIR: ${HCPPIPEDIR}"
fi

if [ -z "${HCPPIPEDIR_PostFS}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR_PostFS environment variable must be set"
  exit 1
else
  echo "${script_name}: HCPPIPEDIR_PostFS: ${HCPPIPEDIR_PostFS}"
fi

########################################## PIPELINE OVERVIEW ##########################################

#TODO

########################################## OUTPUT DIRECTORIES ##########################################

#TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib   # Logging related functions
source ${HCPPIPEDIR}/global/scripts/opts.shlib  # Command line option functions

########################################## SUPPORT FUNCTIONS ##########################################

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
log_SetToolName "PostFreeSurferPipeline_1res.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
StudyFolder=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
SurfaceAtlasDIR=`opts_GetOpt1 "--surfatlasdir" $@`
GrayordinatesSpaceDIR=`opts_GetOpt1 "--grayordinatesdir" $@`
GrayordinatesResolutions=`opts_GetOpt1 "--grayordinatesres" $@`
HighResMesh=`opts_GetOpt1 "--hiresmesh" $@`
LowResMeshes=`opts_GetOpt1 "--lowresmesh" $@`
SubcorticalGrayLabels=`opts_GetOpt1 "--subcortgraylabels" $@`
FreeSurferLabels=`opts_GetOpt1 "--freesurferlabels" $@`
ReferenceMyelinMaps=`opts_GetOpt1 "--refmyelinmaps" $@`
CorrectionSigma=`opts_GetOpt1 "--mcsigma" $@`
RegName=`opts_GetOpt1 "--regname" $@`
InflateExtraScale=`opts_GetOpt1 "--inflatescale" $@`

log_Msg "RegName: ${RegName}"
# default parameters
CorrectionSigma=`opts_DefaultOpt $CorrectionSigma $(echo "sqrt ( 200 )" | bc -l)`
RegName=`opts_DefaultOpt $RegName FS`
InflateExtraScale=`opts_DefaultOpt $InflateExtraScale 1`

PipelineScripts=${HCPPIPEDIR_PostFS}

#ceho "---> Starting Post FreeSurfer Pipeline"
echo "---> Starting Post FreeSurfer Pipeline"
echo " "
echo " Using parameters ..."
echo "              --path: ${StudyFolder}"
echo "           --subject: ${Subject}"
echo "      --surfatlasdir: ${SurfaceAtlasDIR}"
echo "  --grayordinatesdir: ${GrayordinatesSpaceDIR}"
echo "  --grayordinatesres: ${GrayordinatesResolutions}"
echo "         --hiresmesh: ${HighResMesh}"
echo "        --lowresmesh: ${LowResMeshes}"
echo " --subcortgraylabels: ${SubcorticalGrayLabels}"
echo "  --freesurferlabels: ${FreeSurferLabels}"
echo "     --refmyelinmaps: ${ReferenceMyelinMaps}"
echo "           --mcsigma: ${CorrectionSigma}"
echo "           --regname: ${RegName}"
echo "   --PipelineScripts: ${PipelineScripts}"
echo " "

#Naming Conventions
# Do NOT include spaces in any of these names
T1wImage="T1w_acpc_dc"
T1wFolder="T1w" #Location of T1w images
T2wFolder="T2w" #Location of T1w images
T2wImage="T2w_acpc_dc"
AtlasSpaceFolder="MNINonLinear"
NativeFolder="Native"
FreeSurferFolder="$Subject"
FreeSurferInput="T1w_acpc_dc_restore_1mm"
AtlasTransform="acpc_dc2standard"
InverseAtlasTransform="standard2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"
OrginalT1wImage="T1w"
OrginalT2wImage="T2w"
T1wImageBrainMask="brainmask_fs"
InitialT1wTransform="acpc.mat"
dcT1wTransform="T1w_dc.nii.gz"
InitialT2wTransform="acpc.mat"
dcT2wTransform="T2w_reg_dc.nii.gz"
FinalT2wTransform="${Subject}/mri/transforms/T2wtoT1w.mat"
BiasField="BiasField_acpc_dc"
OutputT1wImage="T1w_acpc_dc"
OutputT1wImageRestore="T1w_acpc_dc_restore"
OutputT1wImageRestoreBrain="T1w_acpc_dc_restore_brain"
OutputMNIT1wImage="T1w"
OutputMNIT1wImageRestore="T1w_restore"
OutputMNIT1wImageRestoreBrain="T1w_restore_brain"
OutputT2wImage="T2w_acpc_dc"
OutputT2wImageRestore="T2w_acpc_dc_restore"
OutputT2wImageRestoreBrain="T2w_acpc_dc_restore_brain"
OutputMNIT2wImage="T2w"
OutputMNIT2wImageRestore="T2w_restore"
OutputMNIT2wImageRestoreBrain="T2w_restore_brain"
OutputOrigT1wToT1w="OrigT1w2T1w.nii.gz"
OutputOrigT1wToStandard="OrigT1w2standard.nii.gz" #File was OrigT2w2standard.nii.gz, regnerate and apply matrix
OutputOrigT2wToT1w="OrigT2w2T1w.nii.gz" #mv OrigT1w2T2w.nii.gz OrigT2w2T1w.nii.gz
OutputOrigT2wToStandard="OrigT2w2standard.nii.gz"
BiasFieldOutput="BiasField"
Jacobian="NonlinearRegJacobians.nii.gz"

T1wFolder="$StudyFolder"/"$Subject"/"$T1wFolder"
T2wFolder="$StudyFolder"/"$Subject"/"$T2wFolder"
AtlasSpaceFolder="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder"
FreeSurferFolder="$T1wFolder"/"$FreeSurferFolder"
AtlasTransform="$AtlasSpaceFolder"/xfms/"$AtlasTransform"
InverseAtlasTransform="$AtlasSpaceFolder"/xfms/"$InverseAtlasTransform"


# ------------------------------------------------------------------------------
#  Check MMP Version
# ------------------------------------------------------------------------------

Compliance="hcp"
MPPVersion=`opts_GetOpt1 "--mppversion" $@`
MPPVersion=`opts_DefaultOpt $MPPVersion "hcp"`

if [ "${MPPVersion}" = "legacy" ] ; then
  log_Msg "Legacy Minimal Preprocessing Pipelines: PostFreeSurferPipeline_1res v.XX"
  log_Msg "NOTICE: You are using MPP version that enables processing of images that do not"
  log_Msg "        conform to the HCP specification as described in Glasser et al. (2013)!"
  log_Msg "        Be aware that if the HCP requirements are not met, the level of data quality"
  log_Msg "        can not be guaranteed and the Glasser et al. (2013) paper should not be used"
  log_Msg "        in support of this workflow. A mnauscript with comprehensive evaluation for"
  log_Msg "        the Legacy MPP workflow is in active preparation and should be appropriately"
  log_Msg "        cited when published."
  log_Msg "        "
  log_Msg "Checking available data"
else
  log_Msg "HCP Minimal Preprocessing Pipelines: PostFreeSurferPipeline_1res v.XX"
  log_Msg "Checking data compliance with HCP MPP"
fi

# -- T2w image

if [ ! -e ${T2wFolder}/T2w.nii.gz ]; then
    log_Msg "-> T2w image not present (legacy)"
    Compliance="legacy"
    T2wRestoreImage="NONE"
else
  log_Msg "-> T2w image present"
fi

# -- Final evaluation

if [ "${MPPVersion}" = "legacy" ] ; then
  if [ "${Compliance}" = "legacy" ] ; then
    log_Msg "Processing will continue using Legacy MPP."
  else
    log_Msg "All conditions for the use of HCP MPP are met. Consider using HCP MPP instead of Legacy MPP."
    log_Msg "Processing will continue using Legacy MPP."
  fi
else
  if [ "${Compliance}" = "legacy" ] ; then
    log_Msg "User requested HCP MPP. However, compliance check for use of HCP MPP failed."
    log_Msg "Aborting execution."
    exit 1
  else
    log_Msg "Conditions for the use of HCP MPP are met."
    log_Msg "Processing will continue using HCP MPP."
  fi
fi



#Conversion of FreeSurfer Volumes and Surfaces to NIFTI and GIFTI and Create Caret Files and Registration
log_Msg "Conversion of FreeSurfer Volumes and Surfaces to NIFTI and GIFTI and Create Caret Files and Registration"
log_Msg "RegName: ${RegName}"

argList="$StudyFolder "                # ${1}
argList+="$Subject "                   # ${2}
argList+="$T1wFolder "                 # ${3}
argList+="$AtlasSpaceFolder "          # ${4}
argList+="$NativeFolder "              # ${5}
argList+="$FreeSurferFolder "          # ${6}
argList+="$FreeSurferInput "           # ${7}
argList+="$T1wRestoreImage "           # ${8}  Called T1wImage in FreeSurfer2CaretConvertAndRegisterNonlinear_1res.sh
argList+="$T2wRestoreImage "           # ${9}  Called T2wImage in FreeSurfer2CaretConvertAndRegisterNonlinear_1res.sh
argList+="$SurfaceAtlasDIR "           # ${10}
argList+="$HighResMesh "               # ${11}
argList+="$LowResMeshes "              # ${12}
argList+="$AtlasTransform "            # ${13}
argList+="$InverseAtlasTransform "     # ${14}
argList+="$AtlasSpaceT1wImage "        # ${15}
argList+="$AtlasSpaceT2wImage "        # ${16}
argList+="$T1wImageBrainMask "         # ${17}
argList+="$FreeSurferLabels "          # ${18}
argList+="$GrayordinatesSpaceDIR "     # ${19}
argList+="$GrayordinatesResolutions "  # ${20}
argList+="$SubcorticalGrayLabels "     # ${21}
argList+="$RegName "                   # ${22}
argList+="$InflateExtraScale "         # ${23}
"$PipelineScripts"/FreeSurfer2CaretConvertAndRegisterNonlinear_1res.sh ${argList}


#Myelin Mapping
if [ "${T2wRestoreImage}" = "NONE" ]; then
    log_Msg "Skipping Myelin Mapping"
else
    log_Msg "Myelin Mapping"
    log_Msg "RegName: ${RegName}"

    argList="$StudyFolder "                # ${1}
    argList+="$Subject "
    argList+="$AtlasSpaceFolder "
    argList+="$NativeFolder "
    argList+="$T1wFolder "                 # ${5}
    argList+="$HighResMesh "
    argList+="$LowResMeshes "
    argList+="$T1wFolder"/"$OrginalT1wImage "
    argList+="$T2wFolder"/"$OrginalT2wImage "
    argList+="$T1wFolder"/"$T1wImageBrainMask "           # ${10}
    argList+="$T1wFolder"/xfms/"$InitialT1wTransform "
    argList+="$T1wFolder"/xfms/"$dcT1wTransform "
    argList+="$T2wFolder"/xfms/"$InitialT2wTransform "
    argList+="$T1wFolder"/xfms/"$dcT2wTransform "
    argList+="$T1wFolder"/"$FinalT2wTransform "           # ${15}
    argList+="$AtlasTransform "
    argList+="$T1wFolder"/"$BiasField "
    argList+="$T1wFolder"/"$OutputT1wImage "
    argList+="$T1wFolder"/"$OutputT1wImageRestore "
    argList+="$T1wFolder"/"$OutputT1wImageRestoreBrain "  # ${20}
    argList+="$AtlasSpaceFolder"/"$OutputMNIT1wImage "
    argList+="$AtlasSpaceFolder"/"$OutputMNIT1wImageRestore "
    argList+="$AtlasSpaceFolder"/"$OutputMNIT1wImageRestoreBrain "
    argList+="$T1wFolder"/"$OutputT2wImage "
    argList+="$T1wFolder"/"$OutputT2wImageRestore "       # ${25}
    argList+="$T1wFolder"/"$OutputT2wImageRestoreBrain "
    argList+="$AtlasSpaceFolder"/"$OutputMNIT2wImage "
    argList+="$AtlasSpaceFolder"/"$OutputMNIT2wImageRestore "
    argList+="$AtlasSpaceFolder"/"$OutputMNIT2wImageRestoreBrain "
    argList+="$T1wFolder"/xfms/"$OutputOrigT1wToT1w "     # {30}
    argList+="$T1wFolder"/xfms/"$OutputOrigT1wToStandard "
    argList+="$T1wFolder"/xfms/"$OutputOrigT2wToT1w "
    argList+="$T1wFolder"/xfms/"$OutputOrigT2wToStandard "
    argList+="$AtlasSpaceFolder"/"$BiasFieldOutput "
    argList+="$AtlasSpaceFolder"/"$T1wImageBrainMask "    # {35}  Called T1wMNIImageBrainMask in CreateMyelinMaps_1res.sh
    argList+="$AtlasSpaceFolder"/xfms/"$Jacobian "
    argList+="$ReferenceMyelinMaps "
    argList+="$CorrectionSigma "
    argList+="$RegName "                                  # ${39}
    "$PipelineScripts"/CreateMyelinMaps_1res.sh ${argList}

log_Msg "Completed"
