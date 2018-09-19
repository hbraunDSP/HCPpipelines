#!/bin/bash

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------
set -e # If any command exit with non-zero value, this script exits
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"
log_Debug_On

#MATLAB_HOME="/export/matlab/R2013a"
MATLAB_HOME="${HCP_MATLAB_PATH}"
log_Msg "MATLAB_HOME: ${MATLAB_HOME}"

#
# Function Description:
#  TBW
#
usage()
{
	echo ""
	echo "  MSMAll.sh"
	echo ""
	echo " usage TBW"
	echo ""
}

#
# Function Description:
#  Get the command line options for this script
#  Shows usage information and exits if command line is malformed
#
# Global Output Variables
#
#   TBW
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder # ${StudyFolder}
	unset g_subject              # ${Subject}
	unset g_high_res_mesh        # ${HighResMesh}
	unset g_low_res_mesh         # ${LowResMesh}
	unset g_fmri_names_list      # ${fMRINames}
	unset g_output_fmri_name     # ${OutputfMRIName}
	unset g_fmri_proc_string     # ${fMRIProcSTRING}
	unset g_input_pca_registration_name # ${InPCARegName}
	unset g_input_registration_name     # ${InRegName}
	unset g_registration_name_stem      # ${RegNameStem}
	unset g_rsn_target_file             # ${RSNTargetFileOrig}
	unset g_rsn_cost_weights            # ${RSNCostWeightsOrig}
	unset g_myelin_target_file          # ${MyelinTargetFile}
	unset g_topography_roi_file         # ${TopographyROIFile}
	unset g_topography_target_file      # ${TopographyTargetFile}
	unset g_iterations                  # ${Iterations}
	unset g_method                      # ${Method}
	unset g_use_migp                    # ${UseMIGP}
	unset g_ica_dim                     # ${ICAdim}
	unset g_regression_params           # ${RegressionParams}
	unset g_vn                          # ${VN}
	unset g_rerun                       # ${ReRun}
	unset g_reg_conf                    # ${RegConf}
	unset g_reg_conf_vars               # ${RegConfVars}
	unset g_matlab_run_mode               # ${RegConfVars}
	
	g_matlab_run_mode=0
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--path=*)
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-names-list=*)
				g_fmri_names_list=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_output_fmri_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-pca-registration-name=*)
				g_input_pca_registration_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				g_input_registration_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--registration-name-stem=*)
				g_registration_name_stem=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-target-file=*)
				g_rsn_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-cost-weights=*)
				g_rsn_cost_weights=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--myelin-target-file=*)
				g_myelin_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-roi-file=*)
				g_topography_roi_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-target-file=*)
				g_topography_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--iterations=*)
				g_iterations=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--method=*)
				g_method=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--use-migp=*)
				g_use_migp=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--ica-dim=*)
				g_ica_dim=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--regression-params=*)
				g_regression_params=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--vn=*)
				g_vn=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rerun=*)
				g_rerun=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-conf=*)
				g_reg_conf=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-conf-vars=*)
				# Note: since the value of this parameter contains equal signs ("="),
				# we have to handle grabbing the value slightly differently than
				# in the other cases.
				g_reg_conf_vars=${argument#--reg-conf-vars=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: unrecognized option: ${argument}"
				echo ""
				exit 1
				;;
		esac
	done

	local error_count=0
	# check required parameters

	if [ -z "${g_path_to_study_folder}" ]; then
		echo "ERROR: path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_path_to_study_folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high_res_mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_mesh}" ]; then
		echo "ERROR: low_res_mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_mesh: ${g_low_res_mesh}"
	fi

	if [ -z "${g_fmri_names_list}" ]; then
		echo "ERROR: fmri_names_list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		echo "ERROR: output_fmri_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		echo "ERROR: fmri_proc_string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_input_pca_registration_name}" ]; then
		echo "ERROR: input_pca_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_pca_registration_name: ${g_input_pca_registration_name}"
	fi

	if [ -z "${g_input_registration_name}" ]; then
		echo "ERROR: input_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_registration_name: ${g_input_registration_name}"
	fi

	if [ -z "${g_registration_name_stem}" ]; then
		echo "ERROR: registration_name_stem required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_registration_name_stem: ${g_registration_name_stem}"
	fi

	if [ -z "${g_rsn_target_file}" ]; then
		echo "ERROR: rsn_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_target_file: ${g_rsn_target_file}"
	fi

	if [ -z "${g_rsn_cost_weights}" ]; then
		echo "ERROR: rsn_cost_weights required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_cost_weights: ${g_rsn_cost_weights}"
	fi

	if [ -z "${g_myelin_target_file}" ]; then
		echo "ERROR: myelin_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_myelin_target_file: ${g_myelin_target_file}"
	fi

	if [ -z "${g_topography_roi_file}" ]; then
		echo "ERROR: topography_roi_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_roi_file: ${g_topography_roi_file}"
	fi

	if [ -z "${g_topography_target_file}" ]; then
		echo "ERROR: topography_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_target_file: ${g_topography_target_file}"
	fi

	if [ -z "${g_iterations}" ]; then
		echo "ERROR: iterations required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_iterations: ${g_iterations}"
	fi

	if [ -z "${g_method}" ]; then
		echo "ERROR: method required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_method: ${g_method}"
	fi

	if [ -z "${g_use_migp}" ]; then
		echo "ERROR: use_migp required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_use_migp: ${g_use_migp}"
	fi

	if [ -z "${g_ica_dim}" ]; then
		echo "ERROR: ica_dim required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_ica_dim: ${g_ica_dim}"
	fi

	if [ -z "${g_regression_params}" ]; then
		echo "ERROR: regression_params required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_regression_params: ${g_regression_params}"
	fi

	if [ -z "${g_vn}" ]; then
		echo "ERROR: vn required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_vn: ${g_vn}"
	fi

	if [ -z "${g_rerun}" ]; then
		echo "ERROR: rerun required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rerun: ${g_rerun}"
	fi

	if [ -z "${g_reg_conf}" ]; then
		echo "ERROR: reg_conf required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf: ${g_reg_conf}"
	fi

	if [ -z "${g_reg_conf_vars}" ]; then
		echo "ERROR: reg_conf_vars required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf_vars: ${g_reg_conf_vars}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

#
# Function Description:
#  Document Tool Versions
#
show_tool_versions() 
{
	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version

	# Show MSMBin
	log_Msg "MSMBin: ${MSMBin}"
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for get_options function for global variables set
	get_options $@

	# show the versions of tools used
	show_tool_versions

	Caret7_Command=${CARET7DIR}/wb_command
	log_Msg "Caret7_Command: ${Caret7_Command}"

	StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"

	HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	LowResMesh="${g_low_res_mesh}"
	log_Msg "LowResMesh: ${LowResMesh}"

	fMRINames="${g_fmri_names_list}"
	log_Msg "fMRINames: ${fMRINames}"

	OutputfMRIName="${g_output_fmri_name}"
	log_Msg "OutputfMRIName: ${OutputfMRIName}"

	fMRIProcSTRING="${g_fmri_proc_string}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"

	InPCARegName="${g_input_pca_registration_name}"
	log_Msg "InPCARegName: ${InPCARegName}"

	InRegName="${g_input_registration_name}"
	log_Msg "InRegName: ${InRegName}"

	RegNameStem="${g_registration_name_stem}"
	log_Msg "RegNameStem: ${RegNameStem}"

	RSNTargetFileOrig="${g_rsn_target_file}"
	log_Msg "RSNTargetFileOrig: ${RSNTargetFileOrig}"

	RSNCostWeightsOrig="${g_rsn_cost_weights}"
	log_Msg "RSNCostWeightsOrig: ${RSNCostWeightsOrig}"

	MyelinTargetFile="${g_myelin_target_file}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"

	TopographyROIFile="${g_topography_roi_file}"
	log_Msg "TopographyROIFile: ${TopographyROIFile}"

	TopographyTargetFile="${g_topography_target_file}"
	log_Msg "TopographyTargetFile: ${TopographyTargetFile}"

	Iterations="${g_iterations}"
	log_Msg "Iterations: ${Iterations}"

	Method="${g_method}"
	log_Msg "Method: ${Method}"

	UseMIGP="${g_use_migp}"
	log_Msg "UseMIGP: ${UseMIGP}"

	ICAdim="${g_ica_dim}"
	log_Msg "ICAdim: ${ICAdim}"

	RegressionParams="${g_regression_params}"
	log_Msg "RegressionParams: ${RegressionParams}"

	VN="${g_vn}"
	log_Msg "VN: ${VN}"

	ReRun="${g_rerun}"
	log_Msg "ReRun: ${ReRun}"

	RegConf="${g_reg_conf}"
	log_Msg "RegConf: ${RegConf}"

	RegConfVars="${g_reg_conf_vars}"
	log_Msg "RegConfVars: ${RegConfVars}"

	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
	log_Msg "DownSampleFolder: ${DownSampleFolder}"

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	ResultsFolder="${AtlasFolder}/Results/${OutputfMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	T1wFolder="${StudyFolder}/${Subject}/T1w"
	log_Msg "T1wFolder: ${T1wFolder}"

	DownSampleT1wFolder="${T1wFolder}/fsaverage_LR${LowResMesh}k"
	log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	if [[ `echo -n ${Method} | grep "WR"` ]] ; then
		LowICAdims=`echo ${RegressionParams} | sed 's/_/ /g'`
	fi
	log_Msg "LowICAdims: ${LowICAdims}"

	Iterations=`echo ${Iterations} | sed 's/_/ /g'`
	log_Msg "Iterations: ${Iterations}"

	NumIterations=`echo ${Iterations} | wc -w`
	log_Msg "NumIterations: ${NumIterations}"

	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	log_Msg "CorrectionSigma: ${CorrectionSigma}"

	BC="NO"
	log_Msg "BC: ${BC}"

	nTPsForSpectra="0" #Set to zero to not compute spectra
	log_Msg "nTPsForSpectra: ${nTPsForSpectra}"

	if [[ ! -e ${NativeFolder}/${Subject}.ArealDistortion_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.native.dscalar.nii || ${ReRun} = "YES" ]] ; then 
		
		##IsRunning="${NativeFolder}/${Subject}.IsRunning_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.txt"
		##if [ ! -e ${IsRunning} ] ; then
		##  touch ${IsRunning}
		##else
		##  exit
		##fi

		RSNTargetFile=`echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${ICAdim}/g"`
		log_Msg "RSNTargetFile: ${RSNTargetFile}"
		log_File_Must_Exist "${RSNTargetFile}"
		
		RSNCostWeights=`echo ${RSNCostWeightsOrig} | sed "s/REPLACEDIM/${ICAdim}/g"`
		log_Msg "RSNCostWeights: ${RSNCostWeights}"
		log_File_Must_Exist "${RSNCostWeights}"

		#cp --verbose ${RSNTargetFile} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii
		#cp --verbose ${MyelinTargetFile} ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
		#cp --verbose ${TopographyROIFile} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii
		#cp --verbose ${TopographyTargetFile} ${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii

		if [ ${InPCARegName} = "MSMSulc" ] ; then
			log_Msg "InPCARegName is MSMSulc"
			InPCARegString="MSMSulc"
			OutPCARegString=""
			PCARegString=""
			SurfRegSTRING=""
		else
			log_Msg "InPCARegName is not MSMSulc"
			InPCARegString="${InPCARegName}"
			OutPCARegString="${InPCARegName}_"
			PCARegString="_${InPCARegName}"
			SurfRegSTRING=""
		fi

		log_Msg "InPCARegString: ${InPCARegString}"
		log_Msg "OutPCARegString: ${OutPCARegString}"
		log_Msg "PCARegString: ${PCARegString}"
		log_Msg "SurfRegSTRING: ${SurfRegSTRING}"


			
		if [ ${UseMIGP} = "YES" ] ; then
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}_PCA${PCARegString}.dtseries.nii"
		else
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}${PCARegString}.dtseries.nii"
		fi

		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
		
		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ `echo -n ${Method} | grep "WR"` ]] ; then
			Distortion="${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
			#Distortion="${DownSampleT1wFolder}/${Subject}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
			echo ${Distortion} > ${Params}
			LeftSurface="${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${LeftSurface} >> ${Params}
			RightSurface="${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${RightSurface} >> ${Params}        
			for LowICAdim in ${LowICAdims} ; do
				LowDim=`echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g"`
				echo ${LowDim} >> ${Params}
			done
		fi
		

			matlab_script_file_name=${ResultsFolder}/run_msm3.m
			log_Msg "Creating Matlab script: ${matlab_script_file_name}"

			if [ -e ${matlab_script_file_name} ]; then
				echo "Removing old ${matlab_script_file_name}"
				rm -f ${matlab_script_file_name}
			fi

			matlab_function_arguments="'${inputspatialmaps}'"
			matlab_function_arguments+=",'${inputdtseries}'"
			matlab_function_arguments+=",'${inputweights}'"
			matlab_function_arguments+=",'${outputspatialmaps}'"
			matlab_function_arguments+=",'${outputweights}'"
			matlab_function_arguments+=",'${Caret7_Command}'"
			matlab_function_arguments+=",'${Method}'"
			matlab_function_arguments+=",'${Params}'"
			matlab_function_arguments+=",'${VN}'"
			matlab_function_arguments+=",${nTPsForSpectra}"
			matlab_function_arguments+=",'${BC}'"
			
			mPath="${HCPPIPEDIR}/global/matlab "
			mPath+="${HCPPIPEDIR}/MSMAll/scripts "
			
			touch ${matlab_script_file_name}
			echo "addpath ${mPath}" >> ${matlab_script_file_name}
			echo "MSMregression(${matlab_function_arguments});" >> ${matlab_script_file_name}

			log_Msg "About to execute the following Matlab script"

			cat ${matlab_script_file_name}
			
			matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.1.log 2>&1"
			#exit 0
			cat ${matlab_script_file_name} | matlab -nojvm -nodisplay -nosplash ${matlab_logging}
			
		
		#rm ${Params} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii


	fi

# ##rm ${IsRunning}

}

# 
# Invoke the main function to get things started
#
main $@

