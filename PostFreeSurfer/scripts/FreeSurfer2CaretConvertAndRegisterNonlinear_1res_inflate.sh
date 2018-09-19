#!/bin/bash
set -e
echo -e "\n START: FS2CaretConvertRegisterNonlinear_1res_inflate"

StudyFolder="$1"
Subject="$2"
T1wFolder="$3"
AtlasSpaceFolder="$4"
LowResMeshes="$5"

LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`

for Hemisphere in L R ; do
  for LowResMesh in ${LowResMeshes} ; do

    InflationScale=`echo "scale=4; 0.75 * $LowResMesh / 32" | bc -l`

    ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$InflationScale"

    ${CARET7DIR}/wb_command -surface-generate-inflated "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$InflationScale"
  done
done

echo -e "\n END: FS2CaretConvertRegisterNonlinear_1res_inflate"

