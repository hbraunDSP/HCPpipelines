#!/bin/bash

Subjlist="BYLEE164"
STUDYNAME="lifespan@7tas"

set -e

################
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${SCRIPTDIR}/batch_StudySettings.sh `echo $STUDYNAME | tr "@" " "`
if [ -z ${StudyFolder} ]; then
  exit 1
fi
##############

###24 7T Subjects with complete rfMRI and Structural###


fMRINames="rfMRI_REST_PA rfMRI_REST_AP"

OrigHighPass="2000" #Specified in Sigma
Caret7_Command="${CARET7DIR}/wb_command"
GitRepo="${HCPPIPEDIR}/RestingStateStats"
#RegName="MSMRSNOrig3_d26_DR_DeDrift"
RegName="NONE"
#RegName="MSMAll_2_d41_WRN_DeDrift"

LowResMesh="32"
#FinalfMRIResolution="2"
BrainOrdinatesResolution="2"
SmoothingFWHM="1.6"
OutputProcSTRING="_hp2000_clean"
dlabelFile="NONE"

for Subject in ${Subjlist} ; do
  for fMRIName in ${fMRINames} ; do
    fsl_sub -q q6.q ${GitRepo}/RestingStateStats.sh ${StudyFolder} ${Subject} ${fMRIName} ${OrigHighPass} ${Caret7_Command} ${RegName} ${LowResMesh} ${FinalfMRIResolution} ${BrainOrdinatesResolution} ${SmoothingFWHM} ${OutputProcSTRING} ${dlabelFile}
    echo "set -- ${StudyFolder} ${Subject} ${fMRIName} ${OrigHighPass} ${Caret7_Command} ${RegName} ${LowResMesh} ${FinalfMRIResolution} ${BrainOrdinatesResolution} ${SmoothingFWHM} ${OutputProcSTRING} ${dlabelFile}"
  done
done
