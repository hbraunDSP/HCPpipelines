#!/bin/bash

Caret7_Command="wb_command"
GitRepo="/media/myelin/brainmappers/HardDrives/2TBB/Connectome_Project/CodeReleases/MSMAll"
MSMBin="${GitRepo}/MSMBinaries"

StudyFolder="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseTwo"
Subjlist="100307" #Space delimited list of subjects (or call from DB one at a time)

HighResMesh="164"
LowResMesh="32"

InRegName="MSMSulc" 
OutRegName="MSMAll_InitalReg" #Final Output RegName

fMRINames="rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL" #Names of resting state scans to be used
OutputfMRIName="rfMRI_REST"
fMRIProcSTRING="_Atlas_hp2000_clean" #${fMRIName}_${fMRIProcSTRING}.dtseries.nii #Input FIX cleaned dtseries to use

MSMAllTemplates="${GitRepo}/global/templates/MSMAll"

fMRINames=`echo "$fMRINames" | sed s/" "/"@"/g`

for Subject in ${Subjlist} ; do
  fsl_sub -q q3.q ${GitRepo}/MSMAll/MSMAllPipeline.sh ${Caret7_Command} ${GitRepo} ${MSMBin} ${StudyFolder} ${Subject} ${HighResMesh} ${LowResMesh} ${InRegName} ${OutRegName} ${fMRINames} ${OutputfMRIName} ${fMRIProcSTRING} ${MSMAllTemplates}
  echo "set -- ${Caret7_Command} ${GitRepo} ${MSMBin} ${StudyFolder} ${Subject} ${HighResMesh} ${LowResMesh} ${InRegName} ${OutRegName} ${fMRINames} ${OutputfMRIName} ${fMRIProcSTRING} ${MSMAllTemplates}"
done


