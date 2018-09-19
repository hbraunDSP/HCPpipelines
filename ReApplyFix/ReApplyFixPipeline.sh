#!/bin/bash

# If any command exits with non-zero value, this script exits
set -e
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

#
# Function Description:
#  Show usage information for this script
#
usage()
{
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo " "
	echo "  TBW "
	echo " "
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed
#
get_options()
{
#Caret7_Command="${1}"   ${CARET7_DIR}/wb_command
#GitRepo="${2}"          ${HCPPIPEDIR}
#FixDir="${3}"           ${ICAFIX}

#StudyFolder="${4}"
#Subject="${5}"
#fMRIName="${6}"
#HighPass="${7}"
#RegName="${8}"

	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder     # StudyFolder
	unset g_subject                  # Subject
	unset g_fmri_name                # fMRIName
	unset g_high_pass                # HighPass
	unset g_reg_name                 # RegName
	unset g_matlab_run_mode
	unset g_fmri_suffix
	unset g_cleanvol			
	unset g_atlas_suffix	
	unset g_skip_hpf				
	
	#set defaults
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
			--fmri-name=*)
				g_fmri_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				g_reg_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmrisuffix=*)
				g_fmri_suffix=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--cleanvol)
				g_cleanvol=1
				index=$(( index + 1 ))
				;;
			--atlas-suffix=*)
				g_atlas_suffix=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--skiphpf)
				g_skip_hpf=1
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
		log_Msg "path to study folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "subject ID (--subject=): ${g_subject}"
	fi

	if [ -z "${g_fmri_name}" ]; then
		echo "ERROR: fMRI Name (--fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Name: (--fmri-name=): ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		echo "ERROR: High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: (--high-pass=): ${g_high_pass}"
	fi

	if [ -z "${g_reg_name}" ]; then
		echo "ERROR: Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: (--reg-name=): ${g_reg_name}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

show_tool_version()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

main() 
{
	# Get command line options
	get_options $@

	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	#GitRepo="${2}"
	#FixDir="${3}"

	local StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"
	
	local Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"
	
	local fMRIName="${g_fmri_name}"
	log_Msg "fMRIName: ${fMRIName}"

	local HighPass="${g_high_pass}"
	log_Msg "HighPass: ${HighPass}"

	local RegName="${g_reg_name}"
	log_Msg "RegName: ${RegName}"
	
	if [ ${RegName} != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi
	RegString+="${g_atlas_suffix}"
	
	log_Msg "RegString: ${RegString}"

	
	export FSL_FIX_CIFTIRW="${HCPPIPEDIR}/ReApplyFix/scripts"
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"

#  #Make appropriate files if they don't exist
#  #Call matlab
#  ML_PATHS="addpath('${FixDir}'); addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}');"

	local aggressive=0
	local domot=1
	local hp=${HighPass}
	local fixlist=".fix"
	local fmri_orig="${fMRIName}${g_fmri_suffix}"
	local fmri="${fMRIName}${g_fmri_suffix}"
	
	local skiphpf=false
	if [ -n ${g_skip_hpf} ]; then
		skiphpf=true
	fi
	
	DIR=`pwd`
	cd ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fmri}_hp${HighPass}.ica

	#use HandNoise if available
	if [ -e "./HandNoise.txt" ] ; then
		fixlist="HandNoise.txt"
	fi
	
	if [ -e ../${fmri_orig}_Atlas${RegString}.dtseries.nii ] ; then
		$FSLDIR/bin/imln ../${fmri_orig}_Atlas${RegString}.dtseries.nii Atlas.dtseries.nii
	fi

	$FSLDIR/bin/imln ../$fmri filtered_func_data

	motionparameters="../Movement_Regressors.txt"
	if [ "X${g_fmri_suffix}" != X ] && [ -e "../Movement_Regressors${g_fmri_suffix}.txt" ]; then
		motionparameters="../Movement_Regressors${g_fmri_suffix}.txt"
	fi
	
	mkdir -p mc
	if [ -f ${motionparameters} ] ; then
		cat ${motionparameters} | awk '{ print $4 " " $5 " " $6 " " $1 " " $2 " " $3}' > mc/prefiltered_func_data_mcf.par
	else
		echo "ERROR: Movement_Regressors.txt not retrieved properly." 
		exit -1
	fi 

	mPath="${HCPPIPEDIR}/global/matlab "
	mPath+="${FSL_FIXDIR} "
	mPath+="${HCPPIPEDIR}/ReApplyFix/scripts "
	log_Msg "mPath: ${mPath}"
		
	case ${g_matlab_run_mode} in
	0)
		# Use Compiled Matlab
		local matlab_exe="${HCPPIPEDIR}"
		matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean_no_vol/distrib/run_fix_3_clean_no_vol.sh"

		# TBD: Use environment variable instead of fixed path!
		local matlab_compiler_runtime="/export/matlab/R2013a/MCR"

		local matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp}"
		
		local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.matlab.log 2>&1"

		matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

		# --------------------------------------------------------------------------------
		log_Msg "Run matlab command: ${matlab_cmd}"
		# --------------------------------------------------------------------------------
		echo "${matlab_cmd}" | bash
		echo $?
		;;
	1)
		# Use Matlab - Untested
		matlab_script_file_name=./reapplyfix.m
		log_Msg "Creating Matlab script: ${matlab_script_file_name}"

		if [ -e ${matlab_script_file_name} ]; then
			echo "Removing old ${matlab_script_file_name}"
			rm -f ${matlab_script_file_name}
		fi

		touch ${matlab_script_file_name}
		echo "addpath ${mPath}" >> ${matlab_script_file_name}
		
		if [ -z "${g_cleanvol}" ]; then
			echo "fix_3_clean_no_vol('${fixlist}', ${aggressive}, ${domot}, ${hp}, ${skiphpf});" >> ${matlab_script_file_name}
		else
			echo "fix_3_clean('${fixlist}', ${aggressive}, ${domot}, ${hp}, ${skiphpf});" >> ${matlab_script_file_name}
		fi
		
		local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.matlab.log 2>&1"

		log_Msg "About to execute the following Matlab script"

		cat ${matlab_script_file_name}
		cat ${matlab_script_file_name} | matlab -nojvm -nodisplay -nosplash ${matlab_logging}

		;;
	2)
		#KJ: Octave not yet written
		;;
	*)
			log_Msg "ERROR: Unrecognized Matlab run mode value: ${g_matlab_run_mode}"
			exit 1
	esac

#matlab -nojvm -nodisplay -nosplash <<M_PROG
#${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});
#M_PROG
#echo "${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});"

	cd ${DIR}

	fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${g_fmri_suffix}_hp${HighPass}"
	fmri_orig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${g_fmri_suffix}"
	if [ -f ${fmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${fmri}.ica/Atlas_clean.dtseries.nii ${fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	fi

	$FSLDIR/bin/immv ${fmri}.ica/filtered_func_data_clean ${fmri}_clean
}

#
# Invoke the main function to get things started
#
main $@
