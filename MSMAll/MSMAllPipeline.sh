#!/bin/bash
#set -exv
Caret7_Command="${1}"
GitRepo="${2}"
MSMBin="${3}"
StudyFolder="${4}"
Subject="${5}"
HighResMesh="${6}"
LowResMesh="${7}"
InRegName="${8}"
OutRegName="${9}"
fMRINames="${10}"
OutputfMRIName="${11}"
fMRIProcSTRING="${12}"
MSMAllTemplates="${13}"
#NumThreads="${14}"

InPCARegName="${InRegName}"

#OMP_NUM_THREADS="${NumThreads}"
#export OMP_NUM_THREADS

RUN="echo"

echo "Running MSM on full timeseries"
MIGPvars="NO@0@0@NO@YES" #UseMIGP@PCAInitDim@PCAFinalDim@ReRunIfExists@VarianceNormalization  YES or NO @ number or NONE @ number or NONE @ YES or NO @ YES or NO  #If UseMIGP = NO, then use full timeseries
OutputProcSTRING="_nobias_vn"
${RUN} ${GitRepo}/MSMAll/scripts/SingleSubjectConcat.sh ${Caret7_Command} ${GitRepo} ${StudyFolder} ${Subject} ${fMRINames} ${OutputfMRIName} ${fMRIProcSTRING} ${MIGPvars} ${OutputProcSTRING}

RSNTemplates="${MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii"
RSNWeights="${MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/Weights.txt"
MyelinMaps="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
TopographicRegressors="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topographic_ROIs.32k_fs_LR.dscalar.nii"
TopographicMaps="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topography.32k_fs_LR.dscalar.nii"


#ModuleName@RegName@RSNTargetFile@RSNCostWeights@ArchitectureTargetFile@TopographyROIFile@TopographyTargetFile@Iterations@Method@UseMIGP@ICAdim@RegressionParams@VarianceNormalization@ReRunIfExists@RegConf@RegConfVars #NONE is valid for CostWeights #Iterations specifies what modalities: C=RSN Connectivity, A=Myelin Architecture, T=RSN Topography and number is the number of elements delimited by _ #Method is DR, DRZ, DRN, WR, WRZ, WRN, #UseMIGP is YES or NO #RegressionParams are ICA dimensionalitys delimited by _ to use in calculating spatial weighting for WR #RegConfVars delimited by , Use NONE to use config file as specified
MSMAllRegsOrig="MSMAll.sh@${OutRegName}@${RSNTemplates}@${RSNWeights}@${MyelinMaps}@${TopographicRegressors}@${TopographicMaps}@CA_CAT@WRN@NO@40@7_8_9_10_11_12_13_14_15_16_17_18_19_20_21@NO@YES@${MSMBin}/allparametersVariableMSMOptimiztionAllDRconf@RegConfVars" 

RegConfVars="REGNUMBER=1,REGPOWER=3,SCALEPOWER=0,AREALDISTORTION=0,MAXTHETA=0,LAMBDAONE=0.01,LAMBDATWO=0.05,LAMBDATHREE=0.1" 

MSMAllRegs=`echo ${MSMAllRegsOrig} | sed "s/RegConfVars/${RegConfVars}/g"`
STRING=`echo ${RegConfVars} | sed "s/,/_/g" | sed s/=/_/g`
MSMAllRegs=`echo ${MSMAllRegs} | sed "s/REPLACESTRING/${STRING}/g"`

#Run whatever MSMAll registrations were specified (e.g. when running multiple dimensionalities)
if [ ! ${MSMAllRegs} = "NONE" ] ; then
MSMAllRegs=`echo ${MSMAllRegs} | sed 's/+/ /g'`

  for MSMAllRegs in ${MSMAllRegs} ; do
    Module=`echo ${MSMAllRegs} | cut -d "@" -f 1`
    RegName=`echo ${MSMAllRegs} | cut -d "@" -f 2`
    RSNTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 3`
    RSNCostWeights=`echo ${MSMAllRegs} | cut -d "@" -f 4`
    MyelinTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 5`
    TopographyROIFile=`echo ${MSMAllRegs} | cut -d "@" -f 6`
    TopographyTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 7`
    Iterations=`echo ${MSMAllRegs} | cut -d "@" -f 8`
    Method=`echo ${MSMAllRegs} | cut -d "@" -f 9`
    UseMIGP=`echo ${MSMAllRegs} | cut -d "@" -f 10`
    ICAdim=`echo ${MSMAllRegs} | cut -d "@" -f 11`
    RegressionParams=`echo ${MSMAllRegs} | cut -d "@" -f 12`
    VN=`echo ${MSMAllRegs} | cut -d "@" -f 13`
    ReRun=`echo ${MSMAllRegs} | cut -d "@" -f 14`
    RegConf=`echo ${MSMAllRegs} | cut -d "@" -f 15`
    RegConfVars=`echo ${MSMAllRegs} | cut -d "@" -f 16`
  
    ${RUN} ${GitRepo}/MSMAll/scripts/${Module} ${Caret7_Command} ${GitRepo} ${MSMBin} ${StudyFolder} ${Subject} ${HighResMesh} ${LowResMesh} ${fMRINames} ${OutputfMRIName} ${fMRIProcSTRING} ${InPCARegName} ${InRegName} ${RegName} ${RSNTargetFile} ${RSNCostWeights} ${MyelinTargetFile} ${TopographyROIFile} ${TopographyTargetFile} ${Iterations} ${Method} ${UseMIGP} ${ICAdim} ${RegressionParams} ${VN} ${ReRun} ${RegConf} "${RegConfVars}" 
    InRegName=${RegName}
  done
fi


