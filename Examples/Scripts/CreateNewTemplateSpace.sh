TemplateFolder=${1}
NumberOfVertices=${2}
OriginalMesh=${3}
NewMesh=${4}
NewResolution=${5}
Caret7_Command=${6}
SubcorticalLabelTable=${7}

${FSLDIR}/bin/flirt -interp spline -in ${TemplateFolder}/Avgwmparc.nii.gz -ref ${TemplateFolder}/Avgwmparc.nii.gz -applyisoxfm ${NewResolution} -out ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${TemplateFolder}/Avgwmparc.nii.gz -r ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz
${Caret7_Command} -volume-label-import ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz ${SubcorticalLabelTable} ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz -discard-others -drop-unused-labels 

${Caret7_Command} -surface-create-sphere ${NumberOfVertices} ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii
${Caret7_Command} -surface-flip-lr ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii ${TemplateFolder}/L.sphere.${NewMesh}k_fs_LR.surf.gii
${Caret7_Command} -set-structure ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii CORTEX_RIGHT
${Caret7_Command} -set-structure ${TemplateFolder}/L.sphere.${NewMesh}k_fs_LR.surf.gii CORTEX_LEFT

for Hemisphere in L R ; do
  ${Caret7_Command} -metric-resample ${TemplateFolder}/${Hemisphere}.atlasroi.${OriginalMesh}k_fs_LR.shape.gii ${TemplateFolder}/fsaverage.${Hemisphere}_LR.spherical_std.${OriginalMesh}k_fs_LR.surf.gii ${TemplateFolder}/${Hemisphere}.sphere.${NewMesh}k_fs_LR.surf.gii BARYCENTRIC ${TemplateFolder}/${Hemisphere}.atlasroi.${NewMesh}k_fs_LR.shape.gii -largest
  ${Caret7_Command} -surface-cut-resample ${TemplateFolder}/colin.cerebral.${Hemisphere}.flat.${OriginalMesh}k_fs_LR.surf.gii ${TemplateFolder}/fsaverage.${Hemisphere}_LR.spherical_std.${OriginalMesh}k_fs_LR.surf.gii ${TemplateFolder}/${Hemisphere}.sphere.${NewMesh}k_fs_LR.surf.gii ${TemplateFolder}/colin.cerebral.${Hemisphere}.flat.${NewMesh}k_fs_LR.surf.gii
done

