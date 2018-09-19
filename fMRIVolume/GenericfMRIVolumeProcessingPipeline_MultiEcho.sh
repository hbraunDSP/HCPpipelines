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
log_SetToolName "GenericfMRIVolumeProcessingPipeline_MultiEcho.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`
log_Msg "Path: ${Path}"
Subject=`opts_GetOpt1 "--subject" $@`
log_Msg "Subject: ${Subject}"
NameOffMRI=`opts_GetOpt1 "--fmriname" $@`
log_Msg "NameOffMRI: ${NameOffMRI}"
fMRITimeSeries=`opts_GetOpt1 "--fmritcs" $@`
log_Msg "fMRITimeSeries: ${fMRITimeSeries}"
fMRIScout=`opts_GetOpt1 "--fmriscout" $@`
log_Msg "fMRIScout: ${fMRIScout}"
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`  # Expects 4D volume with two 3D timepoints
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`  
log_Msg "PhaseInputName: ${PhaseInputName}"
GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
log_Msg "GEB0InputName: ${GEB0InputName}"
DwellTime=`opts_GetOpt1 "--echospacing" $@`  
log_Msg "DwellTime: ${DwellTime}"
TopupDwellTime=`opts_GetOpt1 "--SEechospacing" $@`  
deltaTE=`opts_GetOpt1 "--echodiff" $@`  
log_Msg "deltaTE: ${deltaTE}"
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`  
log_Msg "UnwarpDir: ${UnwarpDir}"
FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"

# FIELDMAP, SiemensFieldMap, GeneralElectricFieldMap, or TOPUP
# Note: FIELDMAP and SiemensFieldMap are equivalent
DistortionCorrection=`opts_GetOpt1 "--dcmethod" $@`
log_Msg "DistortionCorrection: ${DistortionCorrection}"

BiasCorrection=`opts_GetOpt1 "--biascorrection" $@`
# Convert BiasCorrection value to all UPPERCASE (to allow the user the flexibility to use NONE, None, none, legacy, Legacy, etc.)
BiasCorrection="$(echo ${BiasCorrection} | tr '[:lower:]' '[:upper:]')"
log_Msg "BiasCorrection: ${BiasCorrection}"
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`  
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`  # NONE if Topup is not being used
log_Msg "TopupConfig: ${TopupConfig}"

dof=`opts_GetOpt1 "--dof" $@`
dof=`opts_DefaultOpt $dof 6`
log_Msg "dof: ${dof}"

RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
log_Msg "RUN: ${RUN}"


#NOTE: the jacobian option only applies the jacobian of the distortion corrections to the fMRI data, and NOT from the nonlinear T1 to template registration
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`
# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
log_Msg "UseJacobian: ${UseJacobian}"

MotionCorrectionType=`opts_GetOpt1 "--mctype" $@`  # use = "FLIRT" to run FLIRT-based mcflirt_acc.sh, or "MCFLIRT" to run MCFLIRT-based mcflirt.sh
MotionCorrectionType=`opts_DefaultOpt $MotionCorrectionType MCFLIRT` #use mcflirt by default

#error check
case "$MotionCorrectionType" in
    MCFLIRT|FLIRT)
        #nothing
    ;;
    
    *)
        log_Msg "ERROR: --mctype must be 'MCFLIRT' (default) or 'FLIRT'"
        exit 1
    ;;
esac

JacobianDefault="true"
if [[ $DistortionCorrection != "TOPUP" ]]
then
    #because the measured fieldmap can cause the warpfield to fold over, default to doing nothing about any jacobians
    JacobianDefault="false"
    #warn if the user specified it
    if [[ $UseJacobian == "true" ]]
    then
        log_Msg "WARNING: using --jacobian=true with --dcmethod other than TOPUP is not recommended, as the distortion warpfield is less stable than TOPUP"
    fi
fi
log_Msg "JacobianDefault: ${JacobianDefault}"

UseJacobian=`opts_DefaultOpt $UseJacobian $JacobianDefault`
log_Msg "After taking default value if necessary, UseJacobian: ${UseJacobian}"

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Msg "the --usejacobian option must be 'true' or 'false'"
    exit 1
fi


BiasFieldType=`opts_GetOpt1 "--biasfield" $@`  # use = "ONES" to skip bias field correction

FinalfMRISpace=`opts_GetOpt1 "--finalspace" $@`  # use = "Native" to put final results in Native space instead of MNI
FinalfMRISpace=`opts_DefaultOpt $FinalfMRISpace MNI`

ExtrafMRITimeSeries=`opts_GetOpt1 "--extrafmritcs" $@`

StartWith=`opts_GetOpt1 "--startwith" $@`


# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRIVol}
GlobalScripts=${HCPPIPEDIR_Global}


#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
OrigScoutName="${ScoutName}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"
SubjectFolder="$Path"/"$Subject"
#note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh during DistortionCorrectionAnd...
sebasedBiasFieldMNI="$SubjectFolder/$AtlasSpaceFolder/Results/$NameOffMRI/${NameOffMRI}_sebased_bias.nii.gz"

fMRIFolder="$Path"/"$Subject"/"$NameOffMRI"

#error check bias correction opt
case "$BiasCorrection" in
    NONE)
        UseBiasFieldMNI=""
    ;;
    LEGACY)
        UseBiasFieldMNI="${fMRIFolder}/${BiasFieldMNI}.${FinalfMRIResolution}"
    ;;
    
    SEBASED)
        if [[ "$DistortionCorrection" != "TOPUP" ]]
        then
            log_Msg "SEBASED bias correction is only available with --dcmethod=TOPUP"
            exit 1
        fi
        UseBiasFieldMNI="$sebasedBiasFieldMNI"
    ;;
    
    "")
        log_Msg "--biascorrection option not specified"
        exit 1
    ;;
    
    *)
        log_Msg "unrecognized value for bias correction: $BiasCorrection"
    exit 1
esac

########################################## DO WORK ########################################## 

T1wFolder="$Path"/"$Subject"/"$T1wFolder"

####
if [ "$FinalfMRISpace" = Native ]; then
	AtlasSpaceFolder="T1w"
	T1wAtlasName="${T1wRestoreImage}"
	T1w2Standard=
	FinalfMRISpace_Suffix="_native"
else
	FinalfMRISpace_Suffix=""
fi

AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

mkdir -p ${T1wFolder}/Results/${NameOffMRI}

####
if [ ! "$StartWith" = "resample" ]; then

if [ ! -e "$fMRIFolder" ] ; then
  log_Msg "mkdir ${fMRIFolder}"
  mkdir "$fMRIFolder"
fi
${RUN} cp "$fMRITimeSeries" "$fMRIFolder"/"$OrigTCSName".nii.gz

#Create fake "Scout" if it doesn't exist
if [ $fMRIScout = "NONE" ] ; then
  ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigScoutName" 0 1
else
  ${RUN} cp "$fMRIScout" "$fMRIFolder"/"$OrigScoutName".nii.gz
fi

#Gradient Distortion Correction of fMRI
log_Msg "Gradient Distortion Correction of fMRI"
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
    log_Msg "mkdir -p ${fMRIFolder}/GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	--workingdir="$fMRIFolder"/GradientDistortionUnwarp \
	--coeffs="$GradientDistortionCoeffs" \
	--in="$fMRIFolder"/"$OrigTCSName" \
	--out="$fMRIFolder"/"$NameOffMRI"_gdc \
	--owarp="$fMRIFolder"/"$NameOffMRI"_gdc_warp

    log_Msg "mkdir -p ${fMRIFolder}/${ScoutName}_GradientDistortionUnwarp"	
     mkdir -p "$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp
     ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	 --workingdir="$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp \
	 --coeffs="$GradientDistortionCoeffs" \
	 --in="$fMRIFolder"/"$OrigScoutName" \
	 --out="$fMRIFolder"/"$ScoutName"_gdc \
	 --owarp="$fMRIFolder"/"$ScoutName"_gdc_warp
	if [[ $UseJacobian == "true" ]]
	then
	    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc -mul "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian "$fMRIFolder"/"$NameOffMRI"_gdc
	    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$ScoutName"_gdc -mul "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian "$fMRIFolder"/"$ScoutName"_gdc
	fi
else
    log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$NameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc "$fMRIFolder"/"$NameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$NameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$ScoutName"_gdc
    #make fake jacobians of all 1s, for completeness
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$OrigScoutName" -mul 0 -add 1 "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc_warp "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian 0 1
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian -mul 0 -add 1 "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian
fi

log_Msg "mkdir -p ${fMRIFolder}/MotionCorrection"
mkdir -p "$fMRIFolder"/MotionCorrection
${RUN} "$PipelineScripts"/MotionCorrection.sh \
    "$fMRIFolder"/MotionCorrection \
    "$fMRIFolder"/"$NameOffMRI"_gdc \
    "$fMRIFolder"/"$ScoutName"_gdc \
    "$fMRIFolder"/"$NameOffMRI"_mc \
    "$fMRIFolder"/"$MovementRegressor" \
    "$fMRIFolder"/"$MotionMatrixFolder" \
    "$MotionMatrixPrefix" \
    "$MotionCorrectionType"

# EPI Distortion Correction and EPI to T1w Registration
log_Msg "EPI Distortion Correction and EPI to T1w Registration"
if [ -e ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased ] ; then
    ${RUN} rm -r ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
fi
log_Msg "mkdir -p ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased"
mkdir -p ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased

${RUN} ${PipelineScripts}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh \
    --workingdir=${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased \
    --scoutin=${fMRIFolder}/${ScoutName}_gdc \
    --t1=${T1wFolder}/${T1wImage} \
    --t1restore=${T1wFolder}/${T1wRestoreImage} \
    --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
    --fmapmag=${MagnitudeInputName} \
    --fmapphase=${PhaseInputName} \
    --fmapgeneralelectric=${GEB0InputName} \
    --echodiff=${deltaTE} \
    --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
    --SEPhasePos=${SpinEchoPhaseEncodePositive} \
    --echospacing=${DwellTime} \
    --SEechospacing=${TopupDwellTime} \
    --unwarpdir=${UnwarpDir} \
    --owarp=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
    --biasfield=${T1wFolder}/${BiasField} \
    --oregim=${fMRIFolder}/${RegOutput} \
    --freesurferfolder=${T1wFolder} \
    --freesurfersubjectid=${Subject} \
    --gdcoeffs=${GradientDistortionCoeffs} \
    --qaimage=${fMRIFolder}/${QAImage} \
    --method=${DistortionCorrection} \
    --topupconfig=${TopupConfig} \
    --ojacobian=${fMRIFolder}/${JacobianOut} \
    --dof=${dof} \
    --fmriname=${NameOffMRI} \
    --subjectfolder=${SubjectFolder} \
    --biascorrection=${BiasCorrection} \
    --usejacobian=${UseJacobian}
    
fi #end startwith!=resample

####
if [ "$FinalfMRISpace" = Native ]; then
	T1w2Standard=
	
	${RUN} imln ${T1wFolder}/${BiasField} ${AtlasSpaceFolder}/${BiasFieldMNI}
	${RUN} mkdir -p ${fMRIFolder}/${MotionMatrixFolder}${FinalfMRISpace_Suffix}
	${RUN} cp -f ${fMRIFolder}/${MotionMatrixFolder}/MAT_???? ${fMRIFolder}/${MotionMatrixFolder}${FinalfMRISpace_Suffix}/
else
	T1w2Standard=${AtlasSpaceFolder}/xfms/${AtlasTransform}
fi

#One Step Resampling
log_Msg "One Step Resampling"
log_Msg "mkdir -p ${fMRIFolder}/OneStepResampling"
mkdir -p ${fMRIFolder}/OneStepResampling
${RUN} ${PipelineScripts}/OneStepResampling.sh \
    --workingdir=${fMRIFolder}/OneStepResampling${FinalfMRISpace_Suffix} \
    --infmri=${fMRIFolder}/${OrigTCSName}.nii.gz \
    --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
    --fmriresout=${FinalfMRIResolution} \
    --fmrifolder=${fMRIFolder} \
    --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
    --struct2std=${T1w2Standard} \
    --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
    --oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
    --motionmatdir=${fMRIFolder}/${MotionMatrixFolder}${FinalfMRISpace_Suffix} \
    --motionmatprefix=${MotionMatrixPrefix} \
    --ofmri=${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin \
    --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
    --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
    --gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp \
    --scoutin=${fMRIFolder}/${OrigScoutName} \
    --scoutgdcin=${fMRIFolder}/${ScoutName}_gdc \
    --oscout=${fMRIFolder}/${NameOffMRI}_SBRef${FinalfMRISpace_Suffix}_nonlin \
    --ojacobian=${fMRIFolder}/${JacobianOut}_${FinalfMRISpace}.${FinalfMRIResolution} \
    --ofreesurferbrainmask=${FreeSurferBrainMask}${FinalfMRISpace_Suffix} \
    --obiasfield=${BiasFieldMNI}${FinalfMRISpace_Suffix} \
    --ot1=${T1wAtlasName}${FinalfMRISpace_Suffix}

if [ ! "X$ExtrafMRITimeSeries" = X ]; then
	log_Msg "One Step Resampling for MultiEcho"
	nxf=0
	MEoutput=${fMRIFolder}/${NameOffMRI}_ME${FinalfMRISpace_Suffix}_nonlin
	TEstring=
	for xf in `echo $ExtrafMRITimeSeries | tr "[@,]" " "`; do
		nxf=$((nxf+1))
		xsuffix="_TE${nxf}"
		xfmriout=${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin${xsuffix}
		TEstring="${TEstring} ${xfmriout}"
		${RUN} ${PipelineScripts}/OneStepResampling_ExtraEcho.sh \
			--workingdir=${fMRIFolder}/OneStepResampling${FinalfMRISpace_Suffix} \
			--infmri=${fMRIFolder}/${OrigTCSName}.nii.gz \
			--t1=${AtlasSpaceFolder}/${T1wAtlasName} \
			--fmriresout=${FinalfMRIResolution} \
			--fmrifolder=${fMRIFolder} \
			--fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
			--struct2std=${T1w2Standard} \
			--owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
			--oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
			--motionmatdir=${fMRIFolder}/${MotionMatrixFolder}${FinalfMRISpace_Suffix} \
			--motionmatprefix=${MotionMatrixPrefix} \
			--ofmri=${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin \
			--freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
			--biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
			--gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp \
			--scoutin=${fMRIFolder}/${OrigScoutName} \
			--scoutgdcin=${fMRIFolder}/${ScoutName}_gdc \
			--oscout=${fMRIFolder}/${NameOffMRI}_SBRef${FinalfMRISpace_Suffix}_nonlin \
			--jacobianin=${fMRIFolder}/${JacobianOut} \
			--ojacobian=${fMRIFolder}/${JacobianOut}_${FinalfMRISpace}.${FinalfMRIResolution} \
			--extrafmri=${xf} \
			--oextrafmri=${xfmriout} \
			--extrafmrisuffix=${xsuffix}
	done
	${RUN} ${BatchToolsDir}/fslsplice ${MEoutput} ${TEstring}
	${RUN} imcp ${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin_mask ${MEoutput}_mask
fi

log_Msg "Finished OneStepResampling...Clean up temp files from MotionMatrices, prevols, postvols"
${RUN} rm -rf ${fMRIFolder}/${MotionMatrixFolder}${FinalfMRISpace_Suffix}/*.nii.gz
${RUN} rm -rf ${fMRIFolder}/OneStepResampling${FinalfMRISpace_Suffix}/prevols*
${RUN} rm -rf ${fMRIFolder}/OneStepResampling${FinalfMRISpace_Suffix}/postvols*

log_Msg "mkdir -p ${ResultsFolder}"
mkdir -p ${ResultsFolder}

#now that we have the final MNI fMRI space, resample the T1w-space sebased bias field related outputs
#the alternative is to add a bunch of optional arguments to OneStepResampling that just do the same thing
#we need to do this before intensity normalization, as it uses the bias field output
if [[ ${DistortionCorrection} == "TOPUP" ]]
then
    #create MNI space corrected fieldmap images
    ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/PhaseOne_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
    ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/PhaseTwo_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
    
    #create MNINonLinear final fMRI resolution bias field outputs
    if [[ ${BiasCorrection} == "SEBASED" ]]
    then
        ${FSLDIR}/bin/applywarp --interp=trilinear -i ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/ComputeSpinEchoBiasField/sebased_bias_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${SubjectFolder}/MNINonLinear/xfms/acpc_dc2standard.nii.gz -o ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_bias.nii.gz
        ${FSLDIR}/bin/fslmaths ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_bias.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_bias.nii.gz
        
        ${FSLDIR}/bin/applywarp --interp=trilinear -i ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/ComputeSpinEchoBiasField/sebased_reference_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${SubjectFolder}/MNINonLinear/xfms/acpc_dc2standard.nii.gz -o ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_reference.nii.gz
        ${FSLDIR}/bin/fslmaths ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_reference.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_sebased_reference.nii.gz
        
        ${FSLDIR}/bin/applywarp --interp=trilinear -i ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${SubjectFolder}/MNINonLinear/xfms/acpc_dc2standard.nii.gz -o ${SubjectFolder}/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}_dropouts.nii.gz
    fi
fi


#Intensity Normalization and Bias Removal
#BiasFieldFile=${fMRIFolder}/${BiasFieldMNI}${FinalfMRISpace_Suffix}.${FinalfMRIResolution}
BiasFieldFile=${UseBiasFieldMNI}
if [ "$BiasFieldType" = ONES ]; then
	
	#if biastype = NONE, replace current biasfield image with all 1's
	${RUN} ${FSLDIR}/bin/fslmaths ${BiasFieldFile} \
		-mul 0 -add 1 ${BiasFieldFile}.ONES
		
	BiasFieldFile=${BiasFieldFile}.ONES
fi

#Intensity Normalization and Bias Removal
log_Msg "Intensity Normalization and Bias Removal"
${RUN} ${PipelineScripts}/IntensityNormalization.sh \
    --infmri=${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin \
    --biasfield=${BiasFieldFile} \
    --jacobian=${fMRIFolder}/${JacobianOut}_${FinalfMRISpace}.${FinalfMRIResolution} \
    --brainmask=${fMRIFolder}/${FreeSurferBrainMask}${FinalfMRISpace_Suffix}.${FinalfMRIResolution} \
    --ofmri=${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin_norm \
    --inscout=${fMRIFolder}/${NameOffMRI}_SBRef${FinalfMRISpace_Suffix}_nonlin \
    --oscout=${fMRIFolder}/${NameOffMRI}_SBRef${FinalfMRISpace_Suffix}_nonlin_norm \
    --usejacobian=${UseJacobian}

if [ ! "X$ExtrafMRITimeSeries" = X ]; then

	log_Msg "Intensity Normalization and Bias Removal on MultiEcho volume"
	
	${RUN} ${PipelineScripts}/IntensityNormalization.sh \
		--infmri=${fMRIFolder}/${NameOffMRI}_ME${FinalfMRISpace_Suffix}_nonlin \
		--biasfield=${BiasFieldFile} \
		--jacobian=${fMRIFolder}/${JacobianOut}_${FinalfMRISpace}.${FinalfMRIResolution} \
		--brainmask=${fMRIFolder}/${FreeSurferBrainMask}${FinalfMRISpace_Suffix}.${FinalfMRIResolution} \
		--ofmri=${fMRIFolder}/${NameOffMRI}_ME${FinalfMRISpace_Suffix}_nonlin_norm \
		--inscout=\
		--oscout=\
		--usejacobian=${UseJacobian}
fi


# MJ QUERY: WHY THE -r OPTIONS BELOW?
# TBr Response: Since the copy operations are specifying individual files
# to be copied and not directories, the recursive copy options (-r) to the
# cp calls below definitely seem unnecessary. They should be removed in 
# a code clean up phase when tests are in place to verify that removing them
# has no unexpected bad side-effect.
${RUN} cp -rf ${fMRIFolder}/${NameOffMRI}${FinalfMRISpace_Suffix}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}.nii.gz
${RUN} cp -rf ${fMRIFolder}/${MovementRegressor}.txt ${ResultsFolder}/${MovementRegressor}.txt
${RUN} cp -rf ${fMRIFolder}/${MovementRegressor}_dt.txt ${ResultsFolder}/${MovementRegressor}_dt.txt
${RUN} cp -rf ${fMRIFolder}/${NameOffMRI}_SBRef${FinalfMRISpace_Suffix}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz
${RUN} cp -rf ${fMRIFolder}/${JacobianOut}_${FinalfMRISpace}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_${JacobianOut}.nii.gz
${RUN} cp -rf ${fMRIFolder}/${FreeSurferBrainMask}${FinalfMRISpace_Suffix}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz
if [ ! "X$ExtrafMRITimeSeries" = X ]; then
	${RUN} cp -rf ${fMRIFolder}/${NameOffMRI}_ME${FinalfMRISpace_Suffix}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_ME.nii.gz
fi

###Add stuff for RMS###
${RUN} cp -rf ${fMRIFolder}/Movement_RelativeRMS.txt ${ResultsFolder}/Movement_RelativeRMS.txt
${RUN} cp -rf ${fMRIFolder}/Movement_AbsoluteRMS.txt ${ResultsFolder}/Movement_AbsoluteRMS.txt
${RUN} cp -rf ${fMRIFolder}/Movement_RelativeRMS_mean.txt ${ResultsFolder}/Movement_RelativeRMS_mean.txt
${RUN} cp -rf ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt ${ResultsFolder}/Movement_AbsoluteRMS_mean.txt
###Add stuff for RMS###

log_Msg "Completed"

