GitRepo="/media/2TBB/Connectome_Project/Pipelines"
TemplateFolder="${GitRepo}/global/templates/standard_mesh_atlases_chimp"
TemplateFolder="${GitRepo}/global/templates/standard_mesh_atlases"
NumberOfVertices="20000"
NumberOfVertices="59000"
OriginalMesh="164"
NewMesh="20"
NewMesh="59"
NewResolution="1.6"
Caret7_Command="wb_command"
SubcorticalLabelTable="${GitRepo}/global/config/FreeSurferSubcorticalLabelTableLut.txt"

${GitRepo}/CreateNewTemplateSpace.sh ${TemplateFolder} ${NumberOfVertices} ${OriginalMesh} ${NewMesh} ${NewResolution} ${Caret7_Command} ${SubcorticalLabelTable}
echo "set -- ${TemplateFolder} ${NumberOfVertices} ${OriginalMesh} ${NewMesh} ${NewResolution} ${Caret7_Command} ${SubcorticalLabelTable}"
