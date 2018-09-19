#!/bin/bash

set -e 

VolumeFile=$1
MaskFile=$2
OutputCifti=$3
OutputLabelFile=$4


tmpd=`mktemp -d`
echo CORTEX > ${tmpd}/labelname.txt
echo 1 1 1 1 1 >> ${tmpd}/labelname.txt

wb_command -volume-label-import ${MaskFile} ${tmpd}/labelname.txt ${OutputLabelFile}

if [[ ${OutputCifti} == *.dtseries.nii ]]; then
	wbarg="-cifti-create-dense-timeseries"
	TR_vol=`fslval $VolumeFile pixdim4`
	wbarg2="-timestep ${TR_vol}"
else
	wbarg="-cifti-create-dense-scalar"
	wbarg2=
fi

wb_command ${wbarg} ${OutputCifti} -volume ${VolumeFile} ${OutputLabelFile} ${wbarg2}

rm -rf ${tmpd}
