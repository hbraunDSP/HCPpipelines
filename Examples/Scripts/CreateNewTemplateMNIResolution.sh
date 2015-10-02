#!/bin/bash

set -e 

TemplateFolder=$1
OriginalResolution=$2
NewResolution=$3
NewDataType=$4
OutputFolder=$5

OutputFolder=`echo $OutputFolder $TemplateFolder | awk '{print $1}'`

#odtmax only really matters for char and short, since they might be cut off
odt=
odtmax=
case `echo ${NewDataType} | tr "[A-Z]" "[a-z]"` in
	char|uint8 )
		odt="-odt char"
		odtmax=255
		;;
	short|int16 )
		odt="-odt short"
		odtmax=32767
		;;
	int|int32 )
		odt="-odt int"
		odtmax=
		;;
	float|float32 )
		odt="-odt float"
		odtmax=
		;;
	double|float64 )
		odt="-odt double"
		odtmax=
		;;
	input )
		odt=
		odtmax=
		
esac


inputT1=${TemplateFolder}/MNI152_T1_${OriginalResolution}mm
inputT2=${TemplateFolder}/MNI152_T2_${OriginalResolution}mm

newT1=${OutputFolder}/MNI152_T1_${NewResolution}mm
newT2=${OutputFolder}/MNI152_T2_${NewResolution}mm

# Resample T1, T1_brain, T1_brain_mask
p0=`fslstats ${inputT1} -p 0`
p100=`fslstats ${inputT1} -p 100`
if [ "x${odtmax}" = x ]; then
	odtdiv=
else
	odtdiv="-div ${p100} -mul ${odtmax}"
fi

flirt -in ${inputT1} -ref ${inputT1} -out ${newT1} -applyisoxfm ${NewResolution} -interp spline
fslmaths ${newT1} -max ${p0} -min ${p100} ${odtdiv} ${newT1} ${odt}

flirt -in ${inputT1}_brain_mask -ref ${inputT1} -out ${newT1}_brain_mask -applyisoxfm ${NewResolution} -interp nearestneighbour
fslmaths ${newT1}_brain_mask -thr 0.5 -bin ${newT1}_brain_mask
fslmaths ${newT1} -mas ${newT1}_brain_mask ${newT1}_brain

# Resample T2, T2_brain
p0=`fslstats ${inputT2} -p 0`
p100=`fslstats ${inputT2} -p 100`
if [ "x${odtmax}" = x ]; then
	odtdiv=
else
	odtdiv="-div ${p100} -mul ${odtmax}"
fi
flirt -in ${inputT2} -ref ${inputT2} -out ${newT2} -applyisoxfm ${NewResolution} -interp spline
fslmaths ${newT2} -max ${p0} -min ${p100} ${odtdiv} ${newT2} ${odt}

fslmaths ${newT2} -mas ${newT1}_brain_mask ${newT2}_brain ${odt}

