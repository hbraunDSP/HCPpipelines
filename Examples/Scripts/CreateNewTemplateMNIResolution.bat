#!/bin/bash

TemplateFolder=/home/range1-raid1/kjamison/Source/Pipelines/global/templates
OriginalResolution=1
NewResolution=0.8
NewDataType=short
OutputFolder=`pwd`
#OutputFolder=


allres="1.05"
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
for mm in $allres
do
	${SCRIPTDIR}/CreateNewTemplateMNIResolution.sh $TemplateFolder $OriginalResolution $mm $NewDataType $OutputFolder
done

