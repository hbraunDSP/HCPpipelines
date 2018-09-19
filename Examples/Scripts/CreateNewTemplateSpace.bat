GitRepo=${HOME}/Source/Pipelines
TemplateFolder="${GitRepo}/global/templates/standard_mesh_atlases"
NumberOfVertices="5000"
OriginalMesh="164"
NewMesh="5"
#NewResolution="1.05"
NewResolution=3.00
Caret7_Command="wb_command"
SubcorticalLabelTable="${GitRepo}/global/config/FreeSurferSubcorticalLabelTableLut.txt"

${GitRepo}/Examples/Scripts/CreateNewTemplateSpace.sh ${TemplateFolder} ${NumberOfVertices} ${OriginalMesh} ${NewMesh} ${NewResolution} ${Caret7_Command} ${SubcorticalLabelTable}
echo "set -- ${TemplateFolder} ${NumberOfVertices} ${OriginalMesh} ${NewMesh} ${NewResolution} ${Caret7_Command} ${SubcorticalLabelTable}"

