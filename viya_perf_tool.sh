#!/bin/bash
#
# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# ============================
# Viya Perf Tool
# Name: viya_perf_tool.sh
# Author: Jim Kuell, SAS <support@sas.com>
# Description: Test network and/or storage IO performance of Viya 3.5 hosts running RHEL or CentOS 7.x.
# Required Files: viya_perf_tool.conf
# ============================
#
# USAGE
# ./viya_perf_tool.sh (parameter)
#    -y               (optional) Auto accept config file values and immediately start running the tool.
#    -h, --help	      Show usage info.
#    -v, --version    Show version info.
#

# ====================================================================
# INITIAL BASH CHECKS
# ====================================================================
if [ -z "${BASH_VERSINFO}" ] || [ -z "${BASH_VERSINFO[0]}" ]; then
	echo
	echo "ERROR: This script must be run with bash (v4+). Try running:"
	echo "           'bash $0'"
	echo
	exit 125
elif ((${BASH_VERSINFO[0]}<4)); then
	echo
	echo "ERROR: Unsupported bash version detected. Bash v4+ required."
	echo
	exit 125
fi

set -o pipefail

# ====================================================================
# VARIABLES
# ====================================================================
PID=$$
GLOBAL_START_TIME="$(date)"
GLOBAL_SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GLOBAL_SCRIPT_NAME="$(basename "$(readlink -f "$0")")"
GLOBAL_SCRIPT_VERSION="4.0.1"
GLOBAL_SCRIPT_BUILD_ID="20220201401"
GLOBAL_CONFIG_NAME="viya_perf_tool.conf"
GLOBAL_CONFIG_VERSION="1.0.0"
GLOBAL_CONFIG_FULL="${GLOBAL_SCRIPT_DIR}/${GLOBAL_CONFIG_NAME}"
GLOBAL_SH_FHOST="$(hostname -f | tr -d '\040\011\012\015')"
GLOBAL_SH_SHOST="$(hostname -s | tr -d '\040\011\012\015')"
if [[ -z "${GLOBAL_EPOCH_TIME}" ]]; then
	GLOBAL_EPOCH_TIME="$(date +%s)"
fi
if [[ -z "${GLOBAL_SH_WORKDIR}" ]]; then 
	GLOBAL_SH_WORKDIR="/tmp/viya_perf_tool_${GLOBAL_EPOCH_TIME}_tmpdir"
fi
if [[ -z "${GLOBAL_LOG_FILE}" ]]; then
	GLOBAL_LOG_FILE="${GLOBAL_SCRIPT_DIR}/viya_perf_tool_${GLOBAL_EPOCH_TIME}.log"
fi
if [[ -z "${GLOBAL_TEST_MODE}" ]]; then
	if [[ -f "${GLOBAL_SCRIPT_DIR}/.test" ]]; then
		echo "************TEST MODE*************"
		GLOBAL_TEST_MODE=1
	else
		GLOBAL_TEST_MODE=0
	fi
fi
OLDIFS="${IFS}"
IFS=':'
readonly PID GLOBAL_START_TIME GLOBAL_SCRIPT_DIR GLOBAL_SCRIPT_NAME GLOBAL_SCRIPT_VERSION GLOBAL_SCRIPT_BUILD_ID GLOBAL_CONFIG_NAME GLOBAL_CONFIG_VERSION GLOBAL_CONFIG_FULL GLOBAL_SH_FHOST GLOBAL_SH_SHOST GLOBAL_EPOCH_TIME GLOBAL_SH_WORKDIR GLOBAL_TEST_MODE OLDIFS IFS
auto_cont=0
full_trap=0
test_count=0
skip_iotest=0
exit_flag=0
clean_work=0
skip_msg=0
curr_test=""
declare -A short_hosts
declare -A test_errors
declare -A skipped_tests

# ====================================================================
# FUNCTIONS
# ====================================================================

#####
# Print version info and exit.
# Parameters:
#   None
#####
show_version() {
	echo
	echo "Viya Perf Tool"
	echo "${GLOBAL_SCRIPT_NAME}"
	echo "Version: ${GLOBAL_SCRIPT_VERSION}"
	echo "Build: ${GLOBAL_SCRIPT_BUILD_ID}"
	echo "Copyright (c) 2020 SAS Institute Inc."
	echo "Unpublished - All Rights Reserved."
	echo
	exit 0
}

#####
# Print usage info and exit.
# Parameters:
#   None
#####
show_usage() {
	echo
	echo "<<USAGE>>"
	echo "  ${GLOBAL_SCRIPT_NAME} (parameter)"
	echo
	echo "  Optional parameters:"
	echo "    -y               Auto accept config file values and immediately start running the tool."
	echo "    -h, --help       Show usage info."
	echo "    -v, --version    Show version info."
	echo
	echo "  Function: Test network and/or storage IO performance of Viya 3.5 hosts."
	echo "            All additional options are read from the config file: [${GLOBAL_CONFIG_FULL}]."
	echo "            Results and system info will be output to log file [e.g. viya_perf_tool_1616433582.log] unless OUTPUT_TO_FILE=N."
	echo
	exit 0
}

#####
# Wrapper for calling trap functions - catch and store what signal is being trapped.
# Parameters:
#   $1 - Function to call when trap is triggered
#####
trap_with_arg() {
	local func_name="$1"; shift
	for signal in "$@"; do
		trap "${func_name} ${signal}" "${signal}"
	done
}

#####
# Trap function for main host - kill and cleanup all child processes and print current test status to the log.
# Parameters:
#   $1 - Signal that was caught and stored by trap_with_arg()
#####
main_trap() {
	trap - EXIT
	trap "" SIGINT SIGTERM SIGHUP
	local signal="$1"
	skip_msg=1
	if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
		echo ""
		echo "Interrupt signal [${signal}] caught. Beginning clean up..."
		echo "To kill this script immediately, issue the command 'kill -9 ${PID}'. NOTE: doing this may result in stray files and processes."
		echo ""
	fi
	echo_out ""
	echo_out "*** Interrupt signal [${signal}] caught. Beginning clean up... ***"
	echo_out "*** To kill this script immediately, issue the command 'kill -9 ${PID}'. NOTE: doing this may result in stray files and processes. ***"
	echo_out ""
	kill -s SIGTERM 0
	wait
	if [[ "${full_trap}" -eq 1 ]]; then
		if [[ "${env_type}" == "mpp" ]]; then
			# print all test output that's been gathered so far to the log
			if [[ -z "${GLOBAL_REMEXEC_HOST}" && ! -z "${test_type}" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
				echo_out "-----------------------------"
				echo_out "Begin printing current test output"
				echo_out "-----------------------------"
				# forces echo_out to print to console and log
				unset curr_test
				for host in ${HOSTS}; do
					echo_out "---------------------------"
					echo_out "Begin current test output for [${host}]"
					echo_out "---------------------------"
					if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
						cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${host}.${GLOBAL_EPOCH_TIME}.out" >> "${GLOBAL_LOG_FILE}"
					else
						cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${host}.${GLOBAL_EPOCH_TIME}.out"
					fi
					echo_out "---------------------------"
					echo_out "End current test output for [${host}]"
					echo_out "---------------------------"
				done
				echo_out "-----------------------------"
				echo_out "End printing current test output"
				echo_out "-----------------------------"
			fi
			# wait for remote processes to finish cleaning up and exit
			run_ssh "while pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null; do sleep 1; done"
		# for smp tests, test_type is only set when iotests are run
		elif [[ ! -z "${test_type}" ]]; then
			clean_up_data
		fi
		clean_work=1
		clean_up_rem_work
	fi
	echo_out "Interrupt signal [${signal}] trap and cleanup complete. Exiting..."
	exit 42
}

#####
# Trap function for remote hosts - kill and cleanup all child processes.
# Parameters:
#   $1 - Signal that was caught and stored by trap_with_arg()
#####
remote_trap() {
	trap - EXIT
	trap "" SIGINT SIGTERM SIGHUP
	local signal="$1"
	echo_out "Remote interrupt signal [${signal}] caught. Beginning clean up..."
	kill -s SIGTERM 0
	wait
	clean_up_data
	if [[ "${GLOBAL_SH_SHOST}" != "${GLOBAL_REMEXEC_HOST}" ]]; then
		clean_up_work
	fi
	exit 42
}

#####
# Message and Error Handling.
# Parameters:
#   $1 - Code of message to be handled
#   $2 - Message value 1
#   $3 - Message value 2
#####
message_handle() {
	wrapper_rc="$1"
	local message_val_1="$2"
	local message_val_2="$3"

	if [[ "${wrapper_rc}" -eq 1 ]]; then
		echo
		echo_out "ERROR - Unable to find config file [${GLOBAL_CONFIG_FULL}]." "1"
		echo
		exit "${wrapper_rc}"
	elif [[ "${wrapper_rc}" -eq 2 ]]; then
		echo
		echo_out "ERROR - Unable to parse config file [${GLOBAL_CONFIG_FULL}]. Possible syntax issue in the file." "1"
		echo
		exit "${wrapper_rc}"
	elif [[ "${wrapper_rc}" -eq 3 ]]; then
		echo
		if [[ ! -z "${CONFIG_VERSION}" ]]; then
			echo_out "ERROR - Invalid config file version detected [${CONFIG_VERSION}]. Expecting [${GLOBAL_CONFIG_VERSION}]. Update config file to the latest version and rerun." "1"
		else
			echo_out "ERROR - Unable to find config file version. Update config file to the latest version and rerun." "1"
		fi
		echo
		exit "${wrapper_rc}"
	elif [[ "${wrapper_rc}" -eq 4 ]]; then
		echo
		echo_out "ERROR - Unable to access /etc/os-release. Supported operating systems: RHEL 7 and CentOS 7." "1"
		echo
		exit "${wrapper_rc}"
	elif [[ "${wrapper_rc}" -eq 5 ]]; then
		echo
		echo_out "ERROR - Operating system not supported. Supported operating systems: RHEL 7 and CentOS 7." "1"
		echo
		exit "${wrapper_rc}"
	elif [[ "${wrapper_rc}" -eq 6 ]]; then
		echo_out "ERROR - Unable to passwordless SSH to [${message_val_1}]." "1"
	elif [[ "${wrapper_rc}" -eq 7 ]]; then
		exit_flag=1
		echo_out "ERROR - ${message_val_1} failed for ${message_val_2} host(s). See list of failed hosts above and correct!" "1"
		echo
		clean_up_data
		clean_up_rem_work
	elif [[ "${wrapper_rc}" -eq 8 ]]; then
		(( config_error_catch+=1 ))
		echo_out "ERROR - Duplicate host found in HOSTS list: [${message_val_1}]." "1"
	elif [[ "${wrapper_rc}" -eq 12 ]]; then
		echo_out "ERROR - Unable to create directory [${message_val_1}] on [${message_val_2}]. Check permissions and try again!" "1"
		if [[ "${skip_iotest}" -eq 0 ]]; then 
			exit_flag=1
			clean_up_data
		fi
	elif [[ "${wrapper_rc}" -eq 14 ]]; then
		echo_out "ERROR - Failed to start iperf listener on [${message_val_1}] as part of ${curr_test}." "1"
	elif [[ "${wrapper_rc}" -eq 15 ]]; then
		echo_out "ERROR - Failed to start iperf sender on [${message_val_1}] connecting to [${message_val_2}] as part of ${curr_test}." "1"
	elif [[ "${wrapper_rc}" -eq 19 ]]; then
		echo_out "ERROR - Command [${message_val_1}] not found on host [${message_val_2}]." "1"
	elif [[ "${wrapper_rc}" -eq 20 ]]; then
		exit_flag=1
		clean_work=1
		echo_out "ERROR - Command check failed for hosts above. Install missing commands or update Bash PATH and rerun!" "1"
		for host in "${!host_paths[@]}"; do
			host_path="$(echo "${host_paths[${host}]}" | tr -d '\040\011\012\015')"
			echo_out "INFO - Host [${host}]: PATH=[${host_path}]."
		done
		echo
		clean_up_data
		clean_up_rem_work
	elif [[ "${wrapper_rc}" -eq 21 ]]; then
		echo_out "ERROR - Cannot pass environment variables to remote host [${message_val_1}]. Check SSH server environment options for ${message_val_1}." "1"
	elif [[ "${wrapper_rc}" -eq 22 ]]; then
		echo_out "ERROR - Cannot execute [${message_val_1}] on [${message_val_2}]. Check SSH between [${GLOBAL_SH_SHOST}] and [${message_val_2}]." "1"
	elif [[ "${wrapper_rc}" -eq 23 ]]; then
		echo_out "ERROR - Ambiguous value for CLEANUP in config file. Directories will need to be cleaned up manually." "1"
	elif [[ "${wrapper_rc}" -eq 24 ]]; then
		clean_work=1
		echo_out "ERROR - Unable to SCP copy [${message_val_1}] to [${message_val_2}]." "1"
	elif [[ "${wrapper_rc}" -eq 25 ]]; then
		echo_out "ERROR - Unable to gather system info for host [${message_val_1}]." "1"
	elif [[ "${wrapper_rc}" -eq 26 ]]; then
		echo_out "ERROR - Directory [${message_val_1}] does not exist on [${message_val_2}]." "1"
	elif [[ "${wrapper_rc}" -eq 27 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to execute dd. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 28 ]]; then
		exit_flag=1
		echo_out "ERROR - Aborting current test due to errors. ${message_val_1} will be skipped for this host." "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 29 ]]; then
		exit_flag=1
		echo_out "ERROR - No physical cores found in /proc/cpuinfo. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 30 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to access [${message_val_1}]. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 31 ]]; then
		echo_out "WARNING - Cannot find units for XFS preallocation size. Calculating max possible size." "0"
	elif [[ "${wrapper_rc}" -eq 32 ]]; then
		echo_out "WARNING - Unable to calculate XFS preallocation buffer. Skipping calculation." "0"
	elif [[ "${wrapper_rc}" -eq 33 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to find file system type for [${message_val_1}]. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 34 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to find mount point for [${message_val_1}]. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 35 ]]; then
		echo_out "WARNING - More than two sockets detected. CPU performance may be affected by NUMA." "0"
	elif [[ "${wrapper_rc}" -eq 36 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to calculate iteration count. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 37 ]]; then
		echo_out "WARNING - Insufficient free space in [${message_val_1}] for FULL test. Smaller file sizes will be used." "0"
	elif [[ "${wrapper_rc}" -eq 38 ]]; then
		exit_flag=1
		echo_out "ERROR - [Available space - 10% total size buffer] is less than 1 KB in [${message_val_1}]. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 39 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to create readhold file [${message_val_1}]. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 40 ]]; then
		exit_flag=1
		echo_out "ERROR - Block count not calculated correctly. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 41 ]]; then
		exit_flag=1
		echo_out "ERROR - Block size not calculated correctly. Aborting test!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 42 ]]; then
		exit_flag=1
		echo_out "ERROR - Unable to verify size of output files. File size missing for iteration ${message_val_1} or ${message_val_2}. Aborting test!" "1"
		failed_write_ls
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 43 ]]; then
		exit_flag=1
		echo_out "ERROR - Target filesystem [${message_val_1}] does not have an adequate amount of free disk space to create test files. Aborting test!" "1"
		failed_write_ls
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 44 ]]; then
		echo_out "WARNING - Unable to remove [${message_val_1}]. This may need to be cleaned up manually!" "1"
	elif [[ "${wrapper_rc}" -eq 45 ]]; then
		(( config_error_catch+=1 ))
		echo_out "ERROR - [${message_val_1}=${message_val_2}] is invalid." "1"
	elif [[ "${wrapper_rc}" -eq 46 ]]; then
		(( config_error_catch+=1 ))
		echo_out "ERROR - [${message_val_1}] is empty in config file. [${message_val_1}] requires a valid value." "1"
	elif [[ "${wrapper_rc}" -eq 47 ]]; then
		exit_flag=1
		echo_out "ERROR - Error(s) encountered parsing config file [${GLOBAL_CONFIG_FULL}]. See list of errors above and correct!" "1"
		echo
	elif [[ "${wrapper_rc}" -eq 48 ]]; then
		exit_flag=1
		echo_out "ERROR - Flushing test files from cache failed. Unable to ${message_val_1} in [${message_val_2}]." "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 49 ]]; then
		exit_flag=1
		echo_out "ERROR - Write test failed for [${message_val_1}] in iteration [${message_val_2}]. Check file system!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 50 ]]; then
		exit_flag=1
		echo_out "ERROR - Read test failed for [${message_val_1}] in iteration [${message_val_2}]. Check file system!" "1"
		clean_up_data
	elif [[ "${wrapper_rc}" -eq 51 ]]; then
		echo_out "ERROR - Required bash shell unavailable on host [${message_val_1}]. Bash v4+ required." "1"
	elif [[ "${wrapper_rc}" -eq 52 ]]; then
		echo_out "ERROR - Unsupported bash version detected on host [${message_val_1}]. Bash v4+ required." "1"
	elif [[ "${wrapper_rc}" -eq 53 ]]; then
		echo_out "ERROR - Unable to validate bash shell on host [${message_val_1}]. Bash v4+ required." "1"
	elif [[ "${wrapper_rc}" -eq 54 ]]; then
		echo_out "ERROR - Unable to ssh to host [${message_val_1}] to ${message_val_2}. Manual cleanup may be needed." "1"
		clean_up_iotests
	elif [[ "${wrapper_rc}" -eq 55 ]]; then
		echo_out "ERROR - Unable to find ${GLOBAL_SCRIPT_NAME} process on [${message_val_1}]. This is likely due to an error encountered during remote testing." "1"
		clean_up_iotests
	elif [[ "${wrapper_rc}" -eq 56 ]]; then
		echo_out "ERROR - ${message_val_2} host [${message_val_1}]." "1"
		clean_up_iotests
	else
		exit_flag=1
		wrapper_rc=256
		echo
		echo_out "ERROR - Ambiguous error received. Contact SAS Support" "1"
		echo
		clean_up_data
	fi

	if [[ "${exit_flag}" -eq 1 ]]; then
		if [[ ! -z "${GLOBAL_REMEXEC_HOST}" && "${GLOBAL_SH_SHOST}" != "${GLOBAL_REMEXEC_HOST}" ]]; then
			clean_up_work
		fi
		if [[ ! -z "${curr_test}" ]]; then
			echo_out "-------------------------"
			echo_out "End ${curr_test} for [${GLOBAL_SH_SHOST}]"
			echo_out "-------------------------"

			if [[ "${env_type}" = "smp" ]]; then
				test_errors["${GLOBAL_SH_SHOST}"]="${curr_test}"
				curr_test="DATA IO Test"
			fi
		fi
		print_test_errors
		trap - EXIT
		exit "${wrapper_rc}"
	fi
}

#####
# Check for non-zero exit code or output to stderr
#   - initially added as workaround for a bug where iperf exits with 0 but still outputs to stderr.
# Parameters:
#   $@ - All output of given command
#####
fail_if_stderr() {
	local rc err
	rc=$({
		("$@" 2>&1 >&3 3>&- 4>&-; echo "$?" >&4) |
		grep '^' >&2 3>&- 4>&-
		} 4>&1)
	err="$?"
	[ "${rc}" -eq 0 ] || exit "${rc}"
	[ "${err}" -ne 0 ] || exit 125
} 3>&1

#####
# Echo message to correct output destination.
# Parameters:
#   $1 - Message to echo out
#   $2 - Action to take with the message
#####
echo_out() {
	local message_out="$1"
	local message_action="$2"
	local message_header=""
	local timestamp
	if [[ "${message_action}" != "2" ]]; then
		timestamp="$(date -u +%FT%T.%3NZ)"
		message_header="[${GLOBAL_SH_SHOST}][${timestamp}]: "
	fi
	if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
		if [[ -z "${GLOBAL_REMEXEC_HOST}" ]]; then
			echo "${message_header}${message_out}" >> "${GLOBAL_LOG_FILE}"
			if [[ "${message_action}" == "1" && -z "${curr_test}" ]]; then
				echo "${message_header}${message_out}"
			fi
		elif [[ ! -z "${GLOBAL_REMEXEC_HOST}" ]]; then
			echo "${message_header}${message_out}"
		fi
	else
		echo "${message_header}${message_out}"
	fi
}

#####
# Clean up IO tests on remote systems if an error is detected.
# Parameters:
#   None
#####
clean_up_iotests() {
	if [[ "${stop_tests}" -eq 1 ]]; then
		exit_flag=1
		echo_out "INFO - Aborting all tests!" "1"

		# check exit codes of nodes that have already finished
		for ssh_host in "${!ssh_status[@]}"; do
			if [[ -z "${skipped_tests[${ssh_host}]}" && -z "${test_errors[${ssh_host}]}" ]] && ! kill -0 "${ssh_status[${ssh_host}]}" >/dev/null 2>&1; then
				pid_wait "${ssh_status[${ssh_host}]}"
			fi
		done

		trap - EXIT
		trap "" SIGINT SIGTERM SIGHUP
		kill -s SIGTERM 0
		wait
		trap_with_arg 'main_trap' SIGINT SIGTERM SIGHUP EXIT
		echo_out "-----------------------------"
		echo_out "Begin printing current test output"
		echo_out "-----------------------------"
		for host in ${HOSTS}; do
			echo_out "---------------------------"
			echo_out "Begin current test output for [${host}]"
			echo_out "---------------------------"
			if [[ "${OUTPUT_TO_FILE}" = "y" ]]; then
				cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${host}.${GLOBAL_EPOCH_TIME}.out" >> "${GLOBAL_LOG_FILE}"
			else
				cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${host}.${GLOBAL_EPOCH_TIME}.out"
			fi
			echo_out "---------------------------"
			echo_out "End current test output for [${host}]"
			echo_out "---------------------------"
		done
		echo_out "-----------------------------"
		echo_out "End printing current test output"
		echo_out "-----------------------------"
		run_ssh "while pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null; do sleep 1; done"
		clean_up_data
	fi
}

#####
# Clean up local work dir.
# Parameters:
#   None
#####
clean_up_work() {
	if [[ "${CLEANUP}" == "y" ]]; then
		if [[ -d "${GLOBAL_SH_WORKDIR}" ]]; then
			rm -rf "${GLOBAL_SH_WORKDIR}"
		fi
		if [[ -d "${GLOBAL_SH_WORKDIR}" ]]; then
			message_handle 44 "${GLOBAL_SH_WORKDIR}"
		elif [[ -z "${GLOBAL_REMEXEC_HOST}" ]]; then
			echo_out "The working directory [${GLOBAL_SH_WORKDIR}] has been removed from host [${GLOBAL_SH_SHOST}]."
		fi
	elif [[ "${CLEANUP}" == "n" ]]; then
		echo_out "CLEANUP=N. The working directory [${GLOBAL_SH_WORKDIR}] was not removed from host [${GLOBAL_SH_SHOST}]."
	else
		message_handle 23
	fi
}

#####
# Clean up work dir on all hosts.
# Parameters:
#   None
#####
clean_up_rem_work() {
	if [[ "${clean_work}" -eq 1 ]]; then
		if [[ "${CLEANUP}" == "y" ]]; then
			clean_up_work
			if [[ "${env_type}" == "mpp" && ( "${IO_TESTS_CDC}" == "y" || "${IO_TESTS_DATA}" == "y" ) ]]; then
				local ssh_host clean_flag ssh_ret_code
				for ssh_host in ${rem_host_list}; do
					clean_flag=0
					# 0 -> dir doesn't exist - ignore (likely cleaned up via another method)
					# 1 -> dir exists and was cleaned up
					# 2 -> dir exists and cannot be cleaned up
					clean_flag="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'export GLOBAL_SH_WORKDIR=${GLOBAL_SH_WORKDIR}; if [[ -d \"\${GLOBAL_SH_WORKDIR}\" ]]; then rm -rf \"\${GLOBAL_SH_WORKDIR}\"; if [[ -d \"\${GLOBAL_SH_WORKDIR}\" ]]; then echo 2; exit; fi; fi; echo 0'")"
					ssh_ret_code="$?"
					clean_flag="$(echo "${clean_flag}" | tr -d '\040\011\012\015')"

					if [[ "${ssh_ret_code}" -gt 0 ]]; then
						echo_out "WARNING - Unable to ssh to host [${ssh_host}] to verify working directory [${GLOBAL_SH_WORKDIR}] was removed. Manual cleanup may be needed!"
					elif [[ "${clean_flag}" -eq 0 ]]; then
						echo_out "The working directory [${GLOBAL_SH_WORKDIR}] has been removed from host [${ssh_host}]."
					else
						echo_out "WARNING - Unable to remove the working directory [${GLOBAL_SH_WORKDIR}] from host [${ssh_host}]. This may need to be cleaned up manually!"
					fi
				done
			fi
		else
			echo_out "CLEANUP=N. The working directory [${GLOBAL_SH_WORKDIR}] was not removed from remote hosts."
		fi
	fi
}

#####
# Clean up IO test data dir.
# Parameters:
#   None
#####
clean_up_data() {
	if [[ "${CLEANUP}" == "y" ]]; then
		if [[ -d "${target_dir}" ]]; then
			rm -rf "${target_dir}"
			if [[ "$?" -gt 0 ]]; then
				message_handle 44 "${target_dir}"
			else
				echo_out "The target directory [${target_dir}] has been removed."
			fi
		elif [[ ! -z "${target_dir}" ]]; then
			echo_out "WARNING - The target directory [${target_dir}] was not removed. Directory not found."
		fi
	elif [[ "${CLEANUP}" == "n" ]]; then
		if [[ -d "${target_dir}" && ! -z "${target_dir}" ]]; then
			echo_out "CLEANUP=N. The target directory [${target_dir}] was not removed."
		fi
	else
		message_handle 23
	fi
}

#####
# Print any test errors that have been stored.
# Parameters:
#   None
#####
print_test_errors() {
	if [[ "${#test_errors[@]}" -gt 0 && "${skip_msg}" -eq 0 ]]; then
		if [[ ! -z "${curr_test}" ]]; then
			echo_out "-----------------------------"
			echo_out "End ${curr_test}s"
			echo_out "-----------------------------"
		fi

		clean_work=1
		clean_up_rem_work
		print_skipped_tests

		if [[ "${OUTPUT_TO_FILE}" == "n" ]]; then
			GLOBAL_LOG_FILE=""
		fi
		if [[ "${#skipped_tests[@]}" -eq 0 ]]; then
			echo "" | tee -a "${GLOBAL_LOG_FILE}"
		fi
		echo "Exiting due to errors during the following tests. Check the output log for more details."
		echo_out "Exiting due to errors during the following tests:" "2"
		echo "********* ERRORS *********" | tee -a "${GLOBAL_LOG_FILE}"
		for host in "${!test_errors[@]}"; do
			echo "    ${test_errors[${host}]} - ${host}" | tee -a "${GLOBAL_LOG_FILE}"
		done 
		echo "**************************" | tee -a "${GLOBAL_LOG_FILE}"
		echo ""
		trap - EXIT
		trap "" SIGINT SIGTERM SIGHUP
		kill -s SIGTERM 0
		wait
		[[ -z "${wrapper_rc}" ]] && wrapper_rc=1
		exit "${wrapper_rc}"
	fi
}

#####
# Print any tests that were skipped.
# Parameters:
#   None
#####
print_skipped_tests() {
	if [[ "${#skipped_tests[@]}" -gt 0 ]]; then
		if [[ "${OUTPUT_TO_FILE}" == "n" ]]; then
			GLOBAL_LOG_FILE=""
		fi
		echo "" | tee -a "${GLOBAL_LOG_FILE}"
		echo "The following tests were skipped due to errors. Check the output log for more details."
		echo_out "The following tests were skipped due to errors:" "2"
		echo "***** SKIPPED TESTS ******" | tee -a "${GLOBAL_LOG_FILE}"
		echo "**************************" | tee -a "${GLOBAL_LOG_FILE}"
		for host in "${!skipped_tests[@]}"; do
			echo "    ${skipped_tests[${host}]} - ${host}" | tee -a "${GLOBAL_LOG_FILE}"
		done 
		echo "**************************" | tee -a "${GLOBAL_LOG_FILE}"
		echo "" | tee -a "${GLOBAL_LOG_FILE}"
	fi
}

#####
# Run calculation and output as integer with thousands separator (if LC_NUMERIC="en_US.UTF-8").
# Parameters:
#   $@ - Calculation to be run
#####
print_calc_int() {
	awk "BEGIN{printf \"%'d\", $@}"
}

#####
# Run calculation and output as a fp with 2 decimals and a thousands separator (if LC_NUMERIC="en_US.UTF-8").
# Parameters:
#   $@ - Calculation to be run
#####
print_calc_2d() {
	awk "BEGIN{printf \"%'.2f\", $@}"
}

#####
# Check if given var is an integer.
# Parameters:
#   $1 - Var to check
#####
check_int() {
	local -i num="$((10#${1}))"
	echo "${num}"
}

#####
# Check if network port is in the valid port range.
# Parameters:
#   $1 - Network port
#####
port_ok() {
	local port="$1"
	local -i port_num
	port_num="$(check_int "${port}" 2>/dev/null)"
	if [[ "${port_num}" -lt 1 || "${port_num}" -gt 65535 ]]; then
		message_handle 45 "NETWORK_LISTEN_PORT" "${NETWORK_LISTEN_PORT}"  
	fi
}

#####
# Check OS and version.
# Parameters:
#   None
#####
check_os() {
	if [[ -r "/etc/os-release" ]]; then
		local os_version os_name
		os_version="$(grep -oP '(?<=^REDHAT_SUPPORT_PRODUCT_VERSION=).+' /etc/os-release | head -1 | tr -d '"' | awk '{ print substr($1,0,1)}')"
		os_name="$(grep -oP '(?<=^REDHAT_SUPPORT_PRODUCT=).+' /etc/os-release | head -1 | tr -d '"' | tr '[:upper:]' '[:lower:]')"
		if [[ "${os_version}" -ne 7 || ! ( "${os_name}" =~ "centos" || "${os_name}" =~ "red hat enterprise linux" ) ]]; then
			message_handle 5
		fi
	else
		message_handle 4
	fi
}

#####
# Check if required commands are available.
# Parameters:
#   None
#####
check_cmds() {
	echo_out "Checking required commands on all hosts"
	local cmd_error_catch=0
	declare -A host_paths

	if [[ "${env_type}" == "mpp" ]]; then
		local ssh_host
		check_errs=()
		for ssh_host in ${HOSTS}; do
			host_paths["${ssh_host}"]="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'echo \"\${PATH}\"'")"
			if [[ "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_CDC}" == "y" ]]; then
				mapfile -t check_errs < <(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'cmds=(awk bc cat cp cut date dd df dirname egrep grep hostname mkdir mount readlink rm sed sort sync tail tar tee touch uname uniq wc /usr/bin/time); for cmd in \"\${cmds[@]}\"; do if ! cmd_type=\"\$(type -p \${cmd})\" || [ -z \"\${cmd_type}\" ]; then echo \"\${cmd}\"; fi; done'")
				if [[ ! -z "${check_errs}" ]]; then
					local check_err
					for check_err in "${check_errs[@]}"; do
						check_err="$(echo "${check_err}" | tr -d '\r')"
						message_handle 19 "${check_err}" "${ssh_host}"
					done
					cmd_error_catch=1
				fi
				unset check_errs
			fi
			if [[ "${NETWORK_TESTS}" == "y" ]]; then
				local iperf_pattern='iperf version 2'
				local iperf_stat
				iperf_stat="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'iperf -version'" 2>&1)"
				if [[ ! "${iperf_stat}" =~ "${iperf_pattern}" ]]; then
					message_handle 19 "${iperf_pattern}" "${ssh_host}"
					cmd_error_catch=1
				fi
			fi
		done
	else
		cmds=(awk bc cat cp cut date dd df dirname egrep grep hostname mkdir mount readlink rm sed sort sync tail tar tee touch uname uniq wc /usr/bin/time)
		local cmd
		for cmd in "${cmds[@]}"; do
			if ! cmd_type="$(type -p ${cmd})" || [ -z "${cmd_type}" ]; then 
				message_handle 19 "${cmd}" "${GLOBAL_SH_SHOST}"
				host_paths["${GLOBAL_SH_SHOST}"]="$(echo "${PATH}")"
				cmd_error_catch=1
			fi
		done
	fi

	if [[ "${cmd_error_catch}" -gt 0 ]]; then
		message_handle 20
	fi
}

#####
# Validate passwordless ssh and check for duplicate hosts in host list.
# Parameters:
#   None
#####
check_ssh() {
	echo_out "Validating host list and passwordless SSH for user [${USER}] on all hosts"
	local ssh_error_catch=0
	local exec_cmd ssh_host ssh_output_string ssh_ret_code ssh_check host_check
	exec_cmd="export GLOBAL_REMEXEC_HOST=${GLOBAL_SH_SHOST}; echo \"\${GLOBAL_REMEXEC_HOST},\$(hostname -s)\""
	neat_rem_host_list="${HOSTS}"
	short_host_list=""
	dup_hosts=()
	ssh_output=()

	for ssh_host in ${HOSTS}; do
		ssh_output_string="$(fail_if_stderr ssh -q -n -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${ssh_host}" "${exec_cmd}" 2>&1)"
		ssh_ret_code="$?"
		ssh_output=( $( echo "${ssh_output_string}" | tr -s ',' ':' | tr -d '\040\011\012\015' ) )

		if [[ "${ssh_ret_code}" -gt 0 ]]; then
			message_handle 6 "${ssh_host}"
			(( ssh_error_catch+=1 ))
		else
			ssh_check="$(echo "${ssh_output[0]}")"
			host_check="$(echo "${ssh_output[1]}")"

			if [[ "${ssh_check}" != "${GLOBAL_SH_SHOST}" ]]; then
				message_handle 21 "${ssh_host}"
				(( ssh_error_catch+=1 ))
			elif [[ "${short_hosts[@]}" =~ "${host_check}" && ! "${dup_hosts[@]}" =~ "${host_check}" ]]; then
				dup_hosts+=("${host_check}")
				message_handle 8 "${ssh_host}"
				(( ssh_error_catch+=1 ))
			else
				short_hosts["${ssh_host}"]="${host_check}"
				if [[ -z "${short_host_list}" ]]; then
					short_host_list+="[${ssh_host}: ${host_check}]"
				else
					short_host_list+=" [${ssh_host}: ${host_check}]"
				fi
				if [[ "${host_check}" == "${GLOBAL_SH_SHOST}" ]]; then
					neat_rem_host_list="$(echo "${neat_rem_host_list//$ssh_host}" | tr -s ':' ' ' | xargs)"
				fi
			fi
		fi
		unset ssh_output
		unset ssh_check
		unset host_check
	done
	if [[ "${ssh_error_catch}" -gt 0 ]]; then
		message_handle 7 "Host list/passwordless SSH validation" "${ssh_error_catch}"
	fi
	echo_out "Host list and passwordless SSH validation completed successfully!"
	rem_host_list="$(echo "${neat_rem_host_list}" | tr -s ' ' ':' | xargs)"
}

#####
# Check bash version on remote hosts.
# Parameters:
#   None
#####
check_rmt_shell() {
	echo_out "Checking for bash shell v4+ on all hosts"
	local ssh_error_catch=0
	local ssh_host shell_flag ssh_ret_code

	for ssh_host in ${HOSTS}; do
		shell_flag="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'if [ -z \"\${BASH_VERSINFO}\" ] || [ -z \"\${BASH_VERSINFO[0]}\" ]; then echo 1; elif ((\${BASH_VERSINFO[0]}<4)); then echo 2; else echo 3; fi'")"
		ssh_ret_code="$?"
		shell_flag="$(echo "${shell_flag}" | tr -d '\040\011\012\015')"

		if [[ "${ssh_ret_code}" -gt 0 ]]; then
			message_handle 22 "bash shell check" "${ssh_host}"
			(( ssh_error_catch+=1 ))
		elif [[ "${shell_flag}" -lt 3 ]]; then
			(( ssh_error_catch+=1 ))
			case "${shell_flag}" in
				1) message_handle 51 "${ssh_host}" ;;
				2) message_handle 52 "${ssh_host}" ;;
				*) message_handle 53 "${ssh_host}" ;;
			esac
		fi
	done

	if [[ "${ssh_error_catch}" -gt 0 ]]; then
		message_handle 7 "Remote bash shell check" "${ssh_error_catch}"
	fi
	echo_out "Bash shell check completed successfully!"
}

#####
# Parse config file and populate variables needed to execute tests based on user customization.
# Parameters:
#   None
#####
parse_config() {
	if [[ ! -r "${GLOBAL_CONFIG_FULL}" ]]; then
		message_handle 1
	fi
	if [[ -z "${GLOBAL_REMEXEC_HOST}" ]]; then
		echo "Using config file [${GLOBAL_CONFIG_FULL}]"
	fi

	# set default config values
	declare -A config_vars
	config_vars=(
		[HOSTS]=""
		[NETWORK_TESTS]="Y"
		[NETWORK_LISTEN_PORT]="24975"
		[PARALLEL_IO_TESTS]="N"
		[IO_TESTS_CDC]="Y"
		[CDC_DIR]=""
		[SHARED_CDC_DIR]="N"
		[IO_TESTS_DATA]="Y"
		[DATA_DIR]=""
		[SHARED_DATA_DIR]="N"
		[CLEANUP]="Y"
		[OUTPUT_TO_FILE]="Y"
		[CONFIG_VERSION]=""
	)
	local line key value entry_regex
	local config_regex_quotes="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*('[^']+'|\"[^\"]+\")[[:blank:]]*(#.*)*$"
	local config_regex_loose="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*([^#]*[^#[:blank:]])*"
	local config_output=()
	local skip_network_tests=0
	config_error_catch=0

	# parse config file and overwrite default values
	while read -r line; do
		[[ ! -z "${line}" ]] || continue
		[[ "${line}" =~ ${config_regex_quotes} ]] || [[ "${line}" =~ ${config_regex_loose} ]] || continue
		key="${BASH_REMATCH[1]}"
		[[ -z "${config_vars[${key}]+set}" ]] && continue
		if [[ "${line}" =~ ${config_regex_quotes} ]]; then
			value="${BASH_REMATCH[2]#[\'\"]}"
			value="${value%[\'\"]}"
		elif [[ "${line}" =~ ${config_regex_loose} ]]; then
			value="${BASH_REMATCH[2]}"
		fi
		config_vars["${key}"]="${value}"
	done < "${GLOBAL_CONFIG_FULL}"
	if [[ "$?" -gt 0 ]]; then	
		message_handle 2
	fi
	for key in "${!config_vars[@]}"; do
		value="${config_vars[${key}]}"
		declare -g "${key}"="${value}"
	done

	HOSTS="$(echo "${HOSTS}" | tr -s ',; ' ':' | tr '[:upper:]' '[:lower:]')"
	HOSTS="${HOSTS#:}"
	NETWORK_TESTS="$(echo "${NETWORK_TESTS}" | tr '[:upper:]' '[:lower:]')"
	IO_TESTS_DATA="$(echo "${IO_TESTS_DATA}" | tr '[:upper:]' '[:lower:]')"
	SHARED_DATA_DIR="$(echo "${SHARED_DATA_DIR}" | tr '[:upper:]' '[:lower:]')"
	IO_TESTS_CDC="$(echo "${IO_TESTS_CDC}" | tr '[:upper:]' '[:lower:]')"
	SHARED_CDC_DIR="$(echo "${SHARED_CDC_DIR}" | tr '[:upper:]' '[:lower:]')"
	PARALLEL_IO_TESTS="$(echo "${PARALLEL_IO_TESTS}" | tr '[:upper:]' '[:lower:]')"
	OUTPUT_TO_FILE="$(echo "${OUTPUT_TO_FILE}" | tr '[:upper:]' '[:lower:]')"
	CLEANUP="$(echo "${CLEANUP}" | tr '[:upper:]' '[:lower:]')"
	if [[ -z "${GLOBAL_REMEXEC_HOST}" ]]; then
		# start creating config output array - ignored if errs are found
		config_output+=("[${GLOBAL_CONFIG_FULL}] validation successful")

		echo_out "Using config file [${GLOBAL_CONFIG_FULL}]"
		echo_out "Validating config file [${GLOBAL_CONFIG_FULL}]"

		# validate config file version
		if [[ -z "${CONFIG_VERSION}" || ! "${CONFIG_VERSION}" == "${GLOBAL_CONFIG_VERSION}" ]]; then
			message_handle 3
		fi

		# make sure ips and hostnames are valid
		if [[ ! -z "${HOSTS}" ]]; then
			local host_error_catch=0
			local ip_regex="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
			local hostname_regex="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";
			local host
			for host in ${HOSTS}; do
				if [[ ! ( "${host}" =~ ${ip_regex} || "${host}" =~ ${hostname_regex} ) ]]; then
					(( host_error_catch+=1 ))
				fi
			done
			if [[ "${host_error_catch}" -gt 0 ]]; then
				message_handle 45 "HOSTS" "${HOSTS}"
			else
				host_list="$(echo "${HOSTS}" | tr -s ':' ' ' | xargs)"
			fi
		else
			message_handle 46 "${HOSTS}"
		fi

		# count number of hosts and start initial check for duplicates - addl checks in check_ssh()
		num_hosts="$(echo "${HOSTS//:/ }"  | wc -w)"
		if [[ "${num_hosts}" -eq 0 ]]; then
			message_handle 46 "HOSTS" 
		elif [[ "${num_hosts}" -gt 1 ]]; then
			env_type="mpp"
			dup_hosts=()
			for host in ${HOSTS}; do
				if [[ "$(echo "${HOSTS}" | grep -o "${host}" | wc -l)" -gt 1 && ! "${dup_hosts[@]}" =~ "${host}" ]]; then
					dup_hosts+=("${host}")
					message_handle 8 "${host}"
				fi
			done
		else
			env_type="smp"
			HOSTS="${GLOBAL_SH_SHOST}"
			host_list="${GLOBAL_SH_SHOST}"
		fi
		config_output+=("Hosts included in tests:               ${host_list}")

		if [[ -z "${NETWORK_TESTS}" ]]; then
			message_handle 46 "NETWORK_TESTS"
		elif [[ ! ( "${NETWORK_TESTS}" == "y" || "${NETWORK_TESTS}" == "n" ) ]]; then
			message_handle 45 "NETWORK_TESTS" "${NETWORK_TESTS}"
		elif [[ "${NETWORK_TESTS}" == "y" ]]; then
			if [[ "${env_type}" == "smp" ]]; then
				NETWORK_TESTS="n"
				skip_network_tests=1
				config_output+=("Perform Network Tests:                 ${NETWORK_TESTS}")
			else
				if [[ -z "${NETWORK_LISTEN_PORT}" ]]; then
					message_handle 46 "NETWORK_LISTEN_PORT"
				fi
				port_ok "${NETWORK_LISTEN_PORT}"
				(( test_count+=1 ))
				IPERF_STARTUP_TIME=1
				IPERF_THREAD_COUNT=10
				IPERF_TIMEOUT=5
				IPERF_SAMPLE_TIME=2
				readonly IPERF_STARTUP_TIME IPERF_THREAD_COUNT IPERF_TIMEOUT IPERF_SAMPLE_TIME
				config_output+=("Perform Network Tests:                 ${NETWORK_TESTS}")
				config_output+=("  Listen port for Network Tests:       ${NETWORK_LISTEN_PORT}")
			fi
		else
			config_output+=("Perform Network Tests:                 ${NETWORK_TESTS}")
		fi

		config_output+=("Perform Data directory IO Tests:       ${IO_TESTS_DATA}")
		if [[ -z "${IO_TESTS_DATA}" ]]; then
			message_handle 46 "IO_TESTS_DATA"
		elif [[ ! ( "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_DATA}" == "n" ) ]]; then
			message_handle 45 "IO_TESTS_DATA" "${IO_TESTS_DATA}"
		elif [[ "${IO_TESTS_DATA}" == "y" ]]; then
			if [[ -z "${DATA_DIR}" ]]; then
				message_handle 46 "DATA_DIR"
			elif [[ "${env_type}" == "mpp" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
				if [[ -z "${SHARED_DATA_DIR}" ]]; then
					message_handle 46 "SHARED_DATA_DIR"
				elif [[ ! ( "${SHARED_DATA_DIR}" == "y" || "${SHARED_DATA_DIR}" == "n" ) ]]; then
					message_handle 45 "SHARED_DATA_DIR" "${SHARED_DATA_DIR}"
				fi
			else
				SHARED_DATA_DIR="n"
			fi
			(( test_count+=1 ))
			config_output+=("  Data directory path:                 ${DATA_DIR}")
			config_output+=("  Data directory is shared (DNFS):     ${SHARED_DATA_DIR}")
		fi

		config_output+=("Perform CAS Disk Cache IO Tests:       ${IO_TESTS_CDC}")
		if [[ -z "${IO_TESTS_CDC}" ]]; then
			message_handle 46 "IO_TESTS_CDC"
		elif [[ ! ( "${IO_TESTS_CDC}" == "y" || "${IO_TESTS_CDC}" == "n" ) ]]; then
			message_handle 45 "IO_TESTS_CDC" "${IO_TESTS_CDC}"
		elif [[ "${IO_TESTS_CDC}" == "y" ]]; then
			if [[ -z "${CDC_DIR}" ]]; then
				message_handle 46 "CDC_DIR"
			elif [[ "${env_type}" == "mpp" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
				if [[ -z "${SHARED_CDC_DIR}" ]]; then
					message_handle 46 "SHARED_CDC_DIR"
				elif [[ ! ( "${SHARED_CDC_DIR}" == "y" || "${SHARED_CDC_DIR}" == "n" ) ]]; then
					message_handle 45 "SHARED_CDC_DIR" "${SHARED_CDC_DIR}"
				fi
			else
				SHARED_CDC_DIR="n"
			fi
			(( test_count+=1 ))
			config_output+=("  CAS Disk Cache path:                 ${CDC_DIR}")
			config_output+=("  CAS Disk Cache directory is shared:  ${SHARED_CDC_DIR}")
		fi

		if [[ "${env_type}" == "mpp" && ( "${IO_TESTS_CDC}" == "y" || "${IO_TESTS_DATA}" == "y" ) ]]; then
			if [[ -z "${PARALLEL_IO_TESTS}" ]]; then
				message_handle 46 "PARALLEL_IO_TESTS"
			elif [[ ! ( "${PARALLEL_IO_TESTS}" == "y" || "${PARALLEL_IO_TESTS}" == "n" ) ]]; then
				message_handle 45 "PARALLEL_IO_TESTS" "${PARALLEL_IO_TESTS}"
			fi
			config_output+=("Run IO Tests in parallel:              ${PARALLEL_IO_TESTS}")
		fi

		config_output+=("Clean up after tests:                  ${CLEANUP}")
		if [[ -z "${CLEANUP}" ]]; then
			message_handle 46 "CLEANUP"
		elif [[ ! ( "${CLEANUP}" == "y" || "${CLEANUP}" == "n" ) ]]; then
			message_handle 45 "CLEANUP" "${CLEANUP}"
		fi

		config_output+=("Output To log:                         ${OUTPUT_TO_FILE}")
		if [[ "${config_error_catch}" -gt 0 ]]; then
			message_handle 47 "HOSTS" "${HOSTS}"
		fi

		# TODO: validate defined host against all localhost hostnames and all NIC IPs - allow to run smp on remote host?
		if [[ "${env_type}" == "smp" ]]; then
			config_output+=("NOTE - SMP test mode detected. Defined host list will be ignored and all tests will run on [${GLOBAL_SH_SHOST}].")

			if [[ "${skip_network_tests}" -eq 1 ]]; then
				config_output+=("NOTE - Network IO tests will NOT be run in SMP mode.")
			fi
		fi

		for output in "${config_output[@]}"; do
			output="$(echo "${output}" | awk -v preFix="[${GLOBAL_SH_SHOST}]: " '{ print preFix $0; }')"
			echo "${output}"
		done

		if [[ "${auto_cont}" -eq 0 ]]; then
			local go_forth
			while true; do
				read -p "[${GLOBAL_SH_SHOST}]: Do you wish to continue? (y/n): " go_forth
				case "${go_forth}" in
					[Yy]|[Yy][Ee][Ss]) break ;;
					[Nn]|[Nn][Oo]) echo_out "Do you wish to continue? (y/n): n. Exiting..."; echo; exit ;;
					* ) echo " Please answer y or n." ;;
				esac
			done
		else
			echo "[${GLOBAL_SH_SHOST}]: Auto-accept config:                    enabled"
			config_output+=("Auto-accept config:                    enabled")
		fi
		if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
			echo "[${GLOBAL_SH_SHOST}]: Logging all output to [${GLOBAL_LOG_FILE}]"
			if [[ "${GLOBAL_TEST_MODE}" -eq 1 ]]; then
				echo_out "************TEST MODE*************"
			fi
			for output in "${config_output[@]}"; do
				echo_out "${output}"
			done
		fi
		if [[ "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_CDC}" == "y" ]]; then
			echo "[${GLOBAL_SH_SHOST}]: Running tests. This may take a while..."
		else
			echo "[${GLOBAL_SH_SHOST}]: Running tests..."
		fi
		echo
		echo_out "----------"
		echo_out "Script Name:    ${GLOBAL_SCRIPT_NAME}"
		echo_out "Script Version: ${GLOBAL_SCRIPT_VERSION}"
		echo_out "Script Build:   ${GLOBAL_SCRIPT_BUILD_ID}"
		echo_out "Config Version: ${GLOBAL_CONFIG_VERSION}"
		echo_out "Copyright (c) 2020 SAS Institute Inc."
		echo_out "Unpublished - All Rights Reserved."
	fi
}

#####
# Gather various system info from all hosts.
# Parameters:
#   None
#####
get_sys_info() {
	exec_cmd=()
	sys_info_results=()
	sys_info_array=()
	sys_info_errors=()
	local error_catch=0
	local ssh_host short_ssh_host ret_code timestamp info
	echo_out "-----------------------------"
	echo_out "Begin system information output"
	echo_out "-----------------------------"

	for ssh_host in ${HOSTS}; do
		unset sys_info_results
		unset sys_info_array
		unset exec_cmd
		short_ssh_host=""
		sys_info_results+=("-------------------------")
		sys_info_results+=("Begin system information for [${ssh_host}]")
		sys_info_results+=("-------------------------")

		if [[ "${env_type}" == "mpp" ]]; then
			short_ssh_host="${short_hosts[${ssh_host}]}"
			exec_cmd=(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "bash -c 'echo \"Bash version: \${BASH_VERSION}\"; echo \"RHEL version: \$(cat /etc/redhat-release)\"; echo \"Uname -a: \$(uname -a)\"; cmds=(\"lscpu\" \"cat /proc/meminfo\" \"/sbin/ip addr show\"); for cmd in \"\${cmds[@]}\"; do echo -e \"---------------------\\\\nBegin '\"'\"'\${cmd}'\"'\"' output\\\\n---------------------\\\\n\$(\${cmd})\\\\n---------------------\\\\nEnd '\"'\"'\${cmd}'\"'\"' output\\\\n---------------------\"; done; { currIP=\$(echo \${SSH_CONNECTION} | awk '\"'\"'{print \$3}'\"'\"') && [[ ! -z \${currIP} ]] && echo \"Current IP: \${currIP}\" && currInt=\$(/sbin/ip -o addr show | grep \${currIP} | awk '\"'\"'{print \$2}'\"'\"') && [[ ! -z \${currInt} ]] && echo \"Current interface: \${currInt}\" && ethtoolOut=\"\$(/sbin/ethtool \${currInt})\"; } 2>/dev/null && echo -e \"---------------------\\\\nBegin /sbin/ethtool NIC info\\\\n---------------------\\\\n\${ethtoolOut}\\\\n---------------------\\\\nEnd /sbin/ethtool NIC info\\\\n---------------------\" || echo \"INFO - Unable to retrieve /sbin/ethtool NIC info\"'")
		else
			short_ssh_host="${GLOBAL_SH_SHOST}"
			exec_cmd=(bash -c 'echo "Bash version: ${BASH_VERSION}"; echo "RHEL version: $(cat /etc/redhat-release)"; echo "Uname -a: $(uname -a)"; cmds=("lscpu" "cat /proc/meminfo" "/sbin/ip addr show"); for cmd in "${cmds[@]}"; do echo -e "---------------------\nBegin '"'"'${cmd}'"'"' output\n---------------------\n$(${cmd})\n---------------------\nEnd '"'"'${cmd}'"'"' output\n---------------------"; done; { currIP=$(echo ${SSH_CONNECTION} | awk '"'"'{print $3}'"'"') && [[ ! -z ${currIP} ]] && echo "Current IP: ${currIP}" && currInt=$(/sbin/ip -o addr show | grep ${currIP} | awk '"'"'{print $2}'"'"') && [[ ! -z ${currInt} ]] && echo "Current interface: ${currInt}" && ethtoolOut="$(/sbin/ethtool ${currInt})"; } 2>/dev/null && echo -e "---------------------\nBegin /sbin/ethtool NIC info\n---------------------\n${ethtoolOut}\n---------------------\nEnd /sbin/ethtool NIC info\n---------------------" || echo "INFO - Unable to retrieve /sbin/ethtool NIC info"')
		fi
		sys_info_array="$("${exec_cmd[@]}" 2>&1)"
		ret_code="$?"
		mapfile -t -O "${#sys_info_results[@]}" sys_info_results < <(echo "${sys_info_array[@]}")
		if [[ "${ret_code}" -gt 0 ]]; then
			sys_info_errors+=("${ssh_host}")
			(( error_catch+=1 ))
		fi
		sys_info_results+=("-------------------------")
		sys_info_results+=("End system information for [${ssh_host}]")
		sys_info_results+=("-------------------------")
		timestamp="$(date -u +%FT%T.%3NZ)"
		for info in "${sys_info_results[@]}"; do
			info="$(echo "${info}" | awk -v preFix="[${short_ssh_host}][${timestamp}]: " '{ print preFix $0; }')"
			echo_out "${info}" "2"
		done
	done
	echo_out "-----------------------------"
	echo_out "End system information output"
	echo_out "-----------------------------"

	if [[ "${error_catch}" -gt 0 ]]; then
		clean_work=1
		for host in "${sys_info_errors[@]}"; do
			message_handle 25 "${host}"
		done
		message_handle 7 "Gather system info" "${error_catch}"
	fi
}

#####
# Wait for given pid to finish and check return code.
# Parameters:
#   $1 - Pid to wait for
#####
pid_wait() {
	local ssh_pid="$1"
	local pid_ret_code
	wait "${ssh_pid}"
	pid_ret_code=$?
	if [[ "${pid_ret_code}" -gt 0 ]]; then
		if [[ "${pid_ret_code}" -eq 28 ]]; then
			skipped_tests["${ssh_host}"]="${curr_test}"
		else
			test_errors["${ssh_host}"]="${curr_test}"
			stop_tests=1
		fi
	fi
}

#####
# Run command over ssh and process output
#   - general commands and perf tests are handled differently.
# Parameters:
#   $1 - Command to run
#   $2 - Type of test to run
#####
run_ssh() {
	local rmt_cmd="$1"
	local test_type="$2"
	local ssh_error_catch=0
	local exec_cmd ssh_host
	declare -A ssh_status
	exec_cmd="bash -c 'export GLOBAL_LOG_FILE=${GLOBAL_LOG_FILE} && export num_hosts=${num_hosts} && export env_type=${env_type} && export test_type=${test_type} && export GLOBAL_EPOCH_TIME=${GLOBAL_EPOCH_TIME} && export GLOBAL_REMEXEC_HOST=${GLOBAL_SH_SHOST} && export GLOBAL_SH_WORKDIR=${GLOBAL_SH_WORKDIR} && export GLOBAL_TEST_MODE=${GLOBAL_TEST_MODE} && ${rmt_cmd}'"

	for ssh_host in ${HOSTS}; do
		# if test_type is set, perf tests are being started
		# if not, basic commands are being run
		if [[ ! -z "${test_type}" ]]; then
			if [[ "${PARALLEL_IO_TESTS}" == "y" ]]; then
				(fail_if_stderr ssh -q -tt -o StrictHostKeyChecking=no "${ssh_host}" "${exec_cmd}") &>"${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${ssh_host}.${GLOBAL_EPOCH_TIME}.out" & ssh_status["${ssh_host}"]="$!"
			else
				(fail_if_stderr ssh -q -tt -o StrictHostKeyChecking=no "${ssh_host}" "${exec_cmd}") &>> "${GLOBAL_LOG_FILE}" & wait "$!"
				ssh_status["${ssh_host}"]="$?"
				sleep 5
			fi
		else
			if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
				(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "${exec_cmd}") &>> "${GLOBAL_LOG_FILE}"
			else
				(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${ssh_host}" "${exec_cmd}")
			fi
		fi
		if [[ "$?" -gt 0 ]]; then
			message_handle 22 "${rmt_cmd}" "${ssh_host}"
			(( ssh_error_catch+=1 ))
		fi
	done

	# enter block if perf tests are being run
	if [[ ! -z "${test_type}" ]]; then
		if [[ "${PARALLEL_IO_TESTS}" == "y" ]]; then
			echo_out "${test_type} IO Tests running in parallel. Waiting for all hosts to finish"

			# if io tests running on a shared dir, have nodes wait for all write tests to finish before starting any read tests
			if [[ ( "${test_type}" == "DATA" && "${SHARED_DATA_DIR}" == "y" ) || ( "${test_type}" == "CDC" && "${SHARED_CDC_DIR}" == "y" ) ]]; then
				local wait_flag readhold_file ssh_ret_code clean_flag
				stop_tests=0
				echo_out "Starting write test (readhold file) watcher on all hosts to synchronize the start of read tests"
				# on remote hosts, watch for write test completion (readhold file creation) and make sure viya_perf_tool.sh stays running
				for ssh_host in "${!ssh_status[@]}"; do
					wait_flag=0
					readhold_file="${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${short_hosts[${ssh_host}]}.${GLOBAL_EPOCH_TIME}.readhold"
					wait_flag="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no ${ssh_host} "bash -c 'if ! pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null; then echo 1; exit; fi; timeout_count=0; while ( pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null ) && ( ! pgrep -u \$(whoami) -fx \"dd if=.* of=.*${GLOBAL_EPOCH_TIME}.*\" >/dev/null ); do if [[ -f \"${readhold_file}\" ]]; then echo 0; exit; fi; if [[ \${timeout_count} -lt 6 ]]; then (( timeout_count+=1 )); sleep 5; else echo 2; exit; fi; done; while ( pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null ) && [[ ! -f \"${readhold_file}\" ]]; do sleep 5; done; if pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null; then echo 0; else echo 1; fi;'")"
					ssh_ret_code="$?"
					wait_flag="$(echo "${wait_flag}" | tr -d '\040\011\012\015')"

					if [[ "${ssh_ret_code}" -gt 0 ]]; then
						# check if pid is still running
						if kill -0 "${ssh_status[${ssh_host}]}" >/dev/null 2&>1; then
							stop_tests=1
							test_errors["${ssh_host}"]="${curr_test}"
						else
							pid_wait "${ssh_status[${ssh_host}]}"
						fi
						message_handle 54 "${ssh_host}" "start watch for readhold file [${readhold_file}]"
					elif [[ "${wait_flag}" -eq 1 ]]; then
						pid_wait "${ssh_status[${ssh_host}]}"
						message_handle 55 "${ssh_host}"
					elif [[ "${wait_flag}" -eq 2 ]]; then
						stop_tests=1
						test_errors["${ssh_host}"]="${curr_test}"
						message_handle 56 "${ssh_host}" "Timeout reached waiting to validate write tests on"
					fi
				done
				# signal remote hosts to begin read tests if io test isn't being skipped on that host
				for ssh_host in "${!ssh_status[@]}"; do
					if [[ -z "${skipped_tests[${ssh_host}]}" ]]; then
						clean_flag=0
						readhold_file="${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${short_hosts[${ssh_host}]}.${GLOBAL_EPOCH_TIME}.readhold"
						clean_flag="$(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no ${ssh_host} "bash -c 'if ( pgrep -u \$(whoami) -fx \"/bin/bash ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}\" >/dev/null ) && [[ -f \"${readhold_file}\" ]]; then rm -f \"${readhold_file}\"; if [[ -f \"${readhold_file}\" ]]; then echo 2; else echo 0; fi; else echo 1; fi'")"
						ssh_ret_code="$?"
						clean_flag="$(echo "${clean_flag}" | tr -d '\040\011\012\015')"

						if [[ "${ssh_ret_code}" -gt 0 ]]; then
							# check if pid is still running
							if kill -0 "${ssh_status[${ssh_host}]}" >/dev/null 2&>1; then
								stop_tests=1
								test_errors["${ssh_host}"]="${curr_test}"
							else
								pid_wait "${ssh_status[${ssh_host}]}"
							fi
							message_handle 54 "${ssh_host}" "verify readhold file [${readhold_file}] was removed"
						elif [[ "${clean_flag}" -eq 1 ]]; then
							pid_wait "${ssh_status[${ssh_host}]}"
							message_handle 55 "${ssh_host}"
						elif [[ "${clean_flag}" -eq 2 ]]; then
							stop_tests=1
							test_errors["${ssh_host}"]="${curr_test}"
							message_handle 56 "${ssh_host}" "Unable to remove the readhold file [${readhold_file}] from"
						fi
					fi
				done
				echo_out "Write tests complete on all nodes. Starting read tests"
			fi
			# wait for all parallel tests to finish
			for ssh_host in "${!ssh_status[@]}"; do
				pid_wait "${ssh_status[${ssh_host}]}"
			done
		else
			echo_out "${test_type} IO Tests running sequentially. Waiting for all hosts to finish"
			# wait for all sequential tests to finish
			for ssh_host in "${!ssh_status[@]}"; do
				if [[ "${ssh_status[${ssh_host}]}" -gt 0 ]]; then
					if [[ "${ssh_status[${ssh_host}]}" -eq 28 ]]; then
						skipped_tests["${ssh_host}"]="${curr_test}"
					else
						test_errors["${ssh_host}"]="${curr_test}"
					fi
				fi
			done
		fi
		sync
	fi
	wait
	if [[ "${ssh_error_catch}" -gt 0 && "${skip_msg}" -eq 0 ]]; then
		message_handle 7 "SSH commands" "${ssh_error_catch}"
	fi
	if [[ ! -z "${test_type}" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
		for ssh_host in ${HOSTS}; do
			if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
				cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${ssh_host}.${GLOBAL_EPOCH_TIME}.out" >> "${GLOBAL_LOG_FILE}"
			else
				cat "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${ssh_host}.${GLOBAL_EPOCH_TIME}.out"
			fi
		done
	fi
	print_test_errors
	unset ssh_status
}

#####
# Scp file to remote hosts.
# Parameters:
#   $1 - Name of source file
#   $2 - Name of destination file
#####
run_scp() {
	local src_file="$1"
	local dst_file="$2"
	local scp_error_catch=0
	local ssh_host
	for ssh_host in ${HOSTS}; do
		if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
			(fail_if_stderr scp -q -o StrictHostKeyChecking=no "${src_file}" "${ssh_host}":"${dst_file}") &>> "${GLOBAL_LOG_FILE}"
		else
			(fail_if_stderr scp -q -o StrictHostKeyChecking=no "${src_file}" "${ssh_host}":"${dst_file}")
		fi
		if [[ "$?" -gt 0 ]]; then
			message_handle 24 "${src_file}" "${ssh_host}:${dst_file}"
			(( scp_error_catch+=1 ))
		fi
	done
	if [[ "${scp_error_catch}" -gt 0 ]]; then
		message_handle 7 "SCP copy" "${scp_error_catch}"
	fi
}

#####
# Create directory and check return code.
# Parameters:
#   $1 - Directory to create
#####
run_mkdir() {
	local dir_name="$1"
	mkdir -p "${dir_name}"
	if [[ "$?" -gt 0 ]]; then
		message_handle 12 "${dir_name}" "${GLOBAL_SH_SHOST}"
	fi
}

#####
# Start the network tests against remote hosts only.
# Parameters:
#   None
#####
start_network_tests() {
	declare -A net_listen_status
	declare -A net_send_status
	net_test_status=()
	curr_test="Sequential Network Test"
	local net_host net_test_result net_send_ret_code net_listen_ret_code timestamp
	echo_out "-----------------------------"
	echo_out "Begin Network Tests"
	echo_out "-----------------------------"
	echo_out "NOTE - Network tests are only run against remote hosts and will not be run against [${GLOBAL_SH_SHOST}]."
	echo_out "---------------------------"
	echo_out "Begin Sequential Network Tests"
	echo_out "---------------------------"

	# run sequential network tests
	for net_host in ${rem_host_list}; do
		net_test_result=""
		unset net_test_status

		echo_out "-------------------------"
		echo_out "Begin Sequential Network Test for [${net_host}]"
		echo_out "-------------------------"

		echo_out "Starting iperf listener on [${net_host}]"
		# start iperf listener on remote host
		(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${net_host}" "bash -c 'timeout --preserve-status ${IPERF_TIMEOUT} iperf -s -p ${NETWORK_LISTEN_PORT}'") >/dev/null 2>> "${GLOBAL_LOG_FILE}" & net_listen_pid="$!"
		sleep "${IPERF_STARTUP_TIME}"

		echo_out "Starting iperf sender on [${GLOBAL_SH_SHOST}] connecting to [${net_host}]"
		# connect to remote listener and run test
		(fail_if_stderr iperf -f g -c "${net_host}" -p "${NETWORK_LISTEN_PORT}" -t "${IPERF_SAMPLE_TIME}" -i "${IPERF_SAMPLE_TIME}" -P "${IPERF_THREAD_COUNT}") &>> "${GLOBAL_SH_WORKDIR}/iperf.sequential.${net_host}.${GLOBAL_EPOCH_TIME}.out"
		net_send_ret_code="$?"

		wait "${net_listen_pid}"
		net_listen_ret_code="$?"

		if [[ "${net_listen_ret_code}" -gt 0 ]]; then
			test_errors["${net_host}"]="${curr_test}"
			message_handle 14 "${net_host}"
		elif [[ "${net_send_ret_code}" -gt 0 ]]; then
			test_errors["${net_host}"]="${curr_test}"
			message_handle 15 "${GLOBAL_SH_SHOST}" "${net_host}"
		fi

		timestamp="$(date -u +%FT%T.%3NZ)"
		net_test_status+=("Listener pid: ${net_listen_pid}" "Listener return code: ${net_listen_ret_code}" "Sender return code: ${net_send_ret_code}")
		net_test_result="$(printf '%s\n' "${net_test_status[@]}" | cat - "${GLOBAL_SH_WORKDIR}/iperf.sequential.${net_host}.${GLOBAL_EPOCH_TIME}.out" | awk -v preFix="[${GLOBAL_SH_SHOST}][${timestamp}]: " '{ print preFix $0; }')"
		echo_out "${net_test_result}" "2"
		echo_out "-------------------------"
		echo_out "End Sequential Network Test for [${net_host}]"
		echo_out "-------------------------"
	done
	print_test_errors
	echo_out "---------------------------"
	echo_out "End Sequential Network Tests"
	echo_out "---------------------------"

	# only run parallel network tests if there's more than one remote host
	if [[ "${num_hosts}" -gt 2 ]]; then
		echo_out "---------------------------"
		echo_out "Begin Parallel Network Tests for hosts [${neat_rem_host_list}]"
		echo_out "---------------------------"
		curr_test="Parallel Network Test"
		unset net_listen_status
		unset net_send_status
		declare -A net_listen_status
		declare -A net_send_status

		# run parallel network tests
		# start iperf listener on all remote hosts
		for net_host in ${rem_host_list}; do
			echo "Starting iperf listener on [${net_host}]" >"${GLOBAL_SH_WORKDIR}/iperf.parallel.${net_host}.${GLOBAL_EPOCH_TIME}.out"
			(fail_if_stderr ssh -q -n -o StrictHostKeyChecking=no "${net_host}" "bash -c 'timeout --preserve-status ${IPERF_TIMEOUT} iperf -s -p ${NETWORK_LISTEN_PORT}'") 2>>"${GLOBAL_SH_WORKDIR}/iperf.parallel.${net_host}.${GLOBAL_EPOCH_TIME}.out" >/dev/null & net_listen_status["${net_host}"]="$!"
		done
		sleep "${IPERF_STARTUP_TIME}"
		# connect to all remote listeners and run tests
		for net_host in ${rem_host_list}; do
			echo "Starting iperf sender on [${GLOBAL_SH_SHOST}] connecting to [${net_host}]" >>"${GLOBAL_SH_WORKDIR}/iperf.parallel.${net_host}.${GLOBAL_EPOCH_TIME}.out"
			(fail_if_stderr iperf -f g -c "${net_host}" -p "${NETWORK_LISTEN_PORT}" -t "${IPERF_SAMPLE_TIME}" -i "${IPERF_SAMPLE_TIME}" -P "${IPERF_THREAD_COUNT}") &>>"${GLOBAL_SH_WORKDIR}/iperf.parallel.${net_host}.${GLOBAL_EPOCH_TIME}.out" & net_send_status["${net_host}"]="$!"
	  	done
		for net_host in ${rem_host_list}; do
			net_test_result=""
			unset net_test_status
			wait "${net_listen_status[${net_host}]}"
			net_listen_ret_code=$?
			wait "${net_send_status[${net_host}]}"
			net_send_ret_code="$?"
			echo_out "-------------------------"
			echo_out "Begin Parallel Network Test Results for [${net_host}]"
			echo_out "-------------------------"

			if [[ "${net_listen_ret_code}" -gt 0 ]]; then
				test_errors["${net_host}"]="${curr_test}"
				message_handle 14 "${net_host}"
			fi
			if [[ "${net_send_ret_code}" -gt 0 ]]; then
				test_errors["${net_host}"]="${curr_test}"
				message_handle 15 "${GLOBAL_SH_SHOST}" "${net_host}"
			fi

			timestamp="$(date -u +%FT%T.%3NZ)"
			net_test_status+=("Listener pid: ${net_listen_status[${net_host}]}" "Listener return code: ${net_listen_ret_code}" "Sender pid: ${net_send_status[${net_host}]}" "Sender return code: ${net_send_ret_code}")
			net_test_result="$(printf '%s\n' "${net_test_status[@]}" | cat - "${GLOBAL_SH_WORKDIR}/iperf.parallel.${net_host}.${GLOBAL_EPOCH_TIME}.out" | awk -v preFix="[${GLOBAL_SH_SHOST}][${timestamp}]: " '{ print preFix $0; }')"
			echo_out "${net_test_result}" "2"
			echo_out "-------------------------"
			echo_out "End Parallel Network Test Results for [${net_host}]"
			echo_out "-------------------------"
		done
		print_test_errors
		echo_out "---------------------------"
		echo_out "End Parallel Network Tests"
		echo_out "---------------------------"
	else
		echo_out "NOTE - Parallel network tests are only run if there's more than one remote host."
	fi

	echo_out "-----------------------------"
	echo_out "End Network Tests"
	echo_out "-----------------------------"
	curr_test=""
}

#####
# Output ls of IO test files in target dir if test failed.
# Parameters:
#   None
#####
failed_write_ls() {
	local avail_space ls_out
	avail_space="$(df -k "${target_dir}" | sed 'N;/\n \+/s/\n \+/ /;P;D' | tail -1 | awk '{print $4}')"
	ls_out="$(ls -lt "${target_dir}/vpt_${iotest_mode}_dd_write."*)"
	echo_out "Available space in [${target_dir}]: $(printf "%'.f" ${avail_space}) KB."
	echo_out "ls -lt of write attempts in [${target_dir}]:"
	echo_out "${ls_out}" "2"
}

#####
# Initialize the IO portion of the test. Validate vars and target dir.
# Parameters:
#   $1 - Type of IO test to run
#   $2 - Directory to test
#####
initialize_io() {
	local iotest_type="$1"
	local iotest_path="$2"
	skip_iotest=0
	shared_dir=0

	# remove trailing slash if iotest_path is not /
	if [[ "${iotest_path}" != "/" ]]; then
		iotest_path=${iotest_path%/}
	fi
	case "${iotest_type}" in
		data)
			tmult=1
			if [[ "${SHARED_DATA_DIR}" == "y" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
				curr_test="DNFS IO Test"
				iotest_mode=DNFS
				shared_dir=1
			else
				curr_test="PATH IO Test"
				iotest_mode=PATH
			fi
			if [[ "${GLOBAL_TEST_MODE}" -eq 1 ]]; then
				file_size_gb=1
			else
				file_size_gb=40
			fi
		;;
		cdc)
			tmult=2
			iotest_mode=CDC
			if [[ "${SHARED_CDC_DIR}" == "y" && "${PARALLEL_IO_TESTS}" == "y" ]]; then
				shared_dir=1
			fi
			if [[ "${GLOBAL_TEST_MODE}" -eq 1 ]]; then
				file_size_gb=1
			else
				file_size_gb=20
			fi
		;;
	esac

	echo_out "-------------------------"
	echo_out "Begin ${curr_test} for [${GLOBAL_SH_SHOST}]"
	echo_out "-------------------------"
	echo_out "Defined target dir: ${iotest_path}"

	if [[ -d "${iotest_path}" ]]; then
		target_dir="${iotest_path}/viya_perf_tool_${iotest_mode}_${GLOBAL_SH_SHOST}_${GLOBAL_EPOCH_TIME}"
		output_dir="${GLOBAL_SH_WORKDIR}/${iotest_mode}_${GLOBAL_SH_SHOST}_output"
		echo_out "New target dir:     ${target_dir}"
		run_mkdir "${target_dir}"
		run_mkdir "${output_dir}"

		if [[ ! -d "${target_dir}" ]]; then
			skip_iotest=1
			message_handle 12 "${target_dir}" "${GLOBAL_SH_SHOST}"
		fi
		if [[ ! -d "${output_dir}" ]]; then
			skip_iotest=1
			message_handle 12 "${output_dir}" "${GLOBAL_SH_SHOST}"
		fi
	else
		skip_iotest=1
		message_handle 26 "${iotest_path}" "${GLOBAL_SH_SHOST}"
	fi

	if [[ "${skip_iotest}" -eq 0 ]]; then 
		local tmp_file="${target_dir}/tmpfile.$$"
		dd if=/dev/zero of=/dev/null bs=1k count=1 2>"${tmp_file}"
		if [[ "$?" -gt 0 ]]; then
			rm -f "${tmp_file}" >/dev/null 2>&1
			message_handle 27 "${tmp_file}"
		fi
		rm -f "${tmp_file}" >/dev/null 2>&1
		validate_system
	else
		message_handle 28 "${curr_test}"
	fi
}

#####
# Run all of the IO test calculations based on the given system and validate everything is ready to run.
# Parameters:
#   None
#####
validate_system() {
	block_size=64
	local alloc_size_flag=0
	local max_alloc_size=0
	local total_alloc_size=0
	echo_out "--- Beginning calculations ---"

	# find cores per socket and calculate # of physical cores;
	#	num of iterations = num of physical cores * thread multiplier
	if [[ -r "/proc/cpuinfo" ]]; then
		local sockets cores_per_socket total_iterations
		sockets="$(cat /proc/cpuinfo | grep "physical id" | sort -u | wc -l)"
		if [[ "${sockets}" -eq 0 ]]; then
			message_handle 29
		fi
		cores_per_socket="$(sed -n 's/^cpu cores//p' /proc/cpuinfo 2>&1 | uniq | cut -f2- -d ':' | sed -e 's/^[[:space:]]*//')"
		total_cores="$(echo "${sockets}*${cores_per_socket}" | bc -l)"
		iterations="$(echo "${total_cores}*${tmult}" | bc -l)"
		if [[ -z "${iterations}" ]]; then
			message_handle 36
		fi
		total_iterations=$(( iterations+1 ))
	else
		message_handle 30 "/proc/cpuinfo"
	fi

	if [[ -r "/proc/meminfo" ]]; then
		total_memory="$(sed -n '/MemTotal:/p' /proc/meminfo | awk '{print $2}')"
		echo_out "Total memory: $(print_calc_2d ${total_memory}/1024/1024) GB"
	else
		message_handle 30 "/proc/meminfo"
	fi

	local mount point
	file_size_kb="$(echo "${file_size_gb}*1024*1024" | bc -l)"
	target_df="$(df -k "${target_dir}" | sed 'N;/\n \+/s/\n \+/ /;P;D' | tail -1)"
	mount_point="$(echo "${target_df}" | awk '{print $NF}')"
	target_mount="$(mount | grep -F "on ${mount_point} ")"

	# calculate allocation buffer if target_dir is an xfs file system -
	#	xfs requires special preallocation buffer calculations if not manually defined
	#
	# alloc_size_flag
	# 0 -> skip
	# 1 -> user-defined
	# 2 -> calculated
	if [[ ! -z "${target_mount}" ]]; then
		local fs_type
		fs_type="$(echo "${target_mount}" | awk '{print $5}')"
		if [[ ! -z "${fs_type}" ]]; then
			echo_out "Target file system type: ${fs_type}"
			if [[ "${fs_type}" == "xfs" ]]; then
				# extract allocsize if manually defined in mount options
				man_alloc_size="$(echo "${target_mount}" | sed -rn 's/.*allocsize=([^,]+).*/\1/p')"
				if [[ ! -z "${man_alloc_size}" ]]; then
					local unit
					unit="$(echo "${man_alloc_size}" | sed -rn 's/[0-9]+([a-zA-Z]+)/\1/p')"
					target_alloc_size="$(echo "${man_alloc_size}" | sed -rn 's/([0-9]+)[a-zA-Z]+/\1/p')"

					case "${unit}" in
						[Gg]|[Gg][Bb]|[Gg][Ii][Bb]) alloc_size_factor=1048576 ;;
						[Mm]|[Mm][Bb]|[Mm][Ii][Bb]) alloc_size_factor=1024 ;;
						[Kk]|[Kk][Bb]|[Kk][Ii][Bb]) alloc_size_factor=1 ;;
					esac
				fi

				if [[ ! -z "${alloc_size_factor}" ]]; then
					max_alloc_size="$(echo "${target_alloc_size}*${alloc_size_factor}" | bc -l)"
					alloc_size_flag=1
				else
					if [[ ! -z "${man_alloc_size}" ]]; then
						message_handle 31
					fi
					# max allocsize = (file size | 8GB), whichever is smaller
					if [[ "${file_size_kb}" -le 8388608 ]]; then
						max_alloc_size="${file_size_kb}"
					else
						max_alloc_size=8388608
					fi
					alloc_size_flag=2
				fi

				# calculate the max total allocsize for all iterations
				if [[ ! -z "${max_alloc_size}" ]]; then
					total_alloc_size="$(echo "${max_alloc_size}*${iterations}" | bc -l)"
				else
					max_alloc_size=0
					alloc_size_flag=0
					message_handle 32
				fi
			fi
		else
			message_handle 33 "${target_dir}"
		fi
	else
		message_handle 34 "${target_dir}"
	fi

	local total_space avail_space buffer target_size req_space
	total_space="$(echo "${target_df}" | awk '{print $2}')"
	avail_space="$(echo "${target_df}" | awk '{print $4}')"
	buffer="$(echo "scale=0; ${total_space}/10" | bc -l)"
	if [[ "${shared_dir}" -eq 1 ]]; then
		local tot_target_size="$(echo "scale=0; ${avail_space}-${buffer}" | bc -l)"
		target_size="$(echo "scale=0; ${tot_target_size}/${num_hosts}" | bc -l)"

		if [[ "${iotest_mode}" == "DNFS" ]]; then
			echo_out "Assuming target dir is a shared file system because [SHARED_DATA_DIR=Y]"
		else
			echo_out "Assuming target dir is a shared file system because [SHARED_CDC_DIR=Y]"
		fi
		echo_out "Total shared file system space: $(print_calc_2d ${total_space}/1024/1024) GB"
		echo_out "Available shared file system space: $(print_calc_2d ${avail_space}/1024/1024) GB"
		echo_out "10% buffer: $(print_calc_2d ${buffer}/1024/1024) GB"
		echo_out "Available space - buffer: $(print_calc_2d ${tot_target_size}/1024/1024) GB"
		echo_out "Workers: ${num_hosts}"
		echo_out "Available space per worker [(available space - buffer) / # of workers]: $(print_calc_2d ${target_size}/1024/1024) GB"
	else
		target_size="$(echo "scale=0; ${avail_space}-${buffer}" | bc -l)"
		echo_out "Total space: $(print_calc_2d ${total_space}/1024/1024) GB"
		echo_out "Available space: $(print_calc_2d ${avail_space}/1024/1024) GB"
		echo_out "10% buffer: $(print_calc_2d ${buffer}/1024/1024) GB"
		echo_out "Available space - buffer: $(print_calc_2d ${target_size}/1024/1024) GB"
	fi
	echo_out "Sockets: ${sockets}"
	echo_out "Physical cores per socket: ${cores_per_socket}"
	echo_out "Total physical cores: ${total_cores}"
	if [[ "${sockets}" -gt 2 ]]; then
		message_handle 35
	fi

	# calculate # of blocks to use per iteration (total mem/block_size)
	num_blocks="$(echo "scale=0; ${file_size_kb}/${block_size}" | bc -l)"
	# calculate total required space including one extra iteration required for flushing files from cache
	req_space="$(echo "(${file_size_kb}*${total_iterations})+${total_alloc_size}" | bc -l)"
	echo_out "Iterations (threads) per physical core: ${tmult}"
	echo_out "Total iterations: ${iterations}"
	echo_out "Block size: ${block_size} KB"
	echo_out "Blocks per iteration: $(printf "%'d" ${num_blocks})"
	echo_out "File size per iteration: ${file_size_gb} GB"
	echo_out "Total file size: $(print_calc_2d ${file_size_kb}*${iterations}/1024/1024) GB"
	if [[ "${max_alloc_size}" -gt 0 ]]; then
		[[ ! -z "${man_alloc_size}" ]] && echo_out "Mount-defined preallocation size: ${man_alloc_size}"
		echo_out "Max preallocation size per iteration: $(print_calc_2d ${max_alloc_size}/1024/1024) GB"
		echo_out "Total max preallocation size: $(print_calc_2d ${total_alloc_size}/1024/1024) GB"
	fi
	echo_out "Total required space (including an extra file for flushing file cache): $(print_calc_2d ${req_space}/1024/1024) GB"

	# check if available space - buff is less than the required space
	if [[ "${target_size}" -lt "${req_space}" ]]; then
		message_handle 37 "${target_dir}"
		# make sure available space - buff is gt 0
		if [[ "${target_size}" -lt 1 ]]; then
			message_handle 38 "${target_dir}"
		fi
		echo_out "-- Recalculating file size and # of blocks --"

		# alloc_size_flag
		# 0 -> skip
		# 1 -> user-defined
		# 2 -> calculated
		if [[ "${alloc_size_flag}" -eq 1 ]]; then
			# use user-defined preallocation size
			file_size_kb="$(echo "scale=0; (${target_size}-${total_alloc_size})/${total_iterations})" | bc -l)"
		elif [[ "${alloc_size_flag}" -eq 2 ]]; then
			local tmp_file_size_kb="$(echo "scale=0; ${target_size}/${total_iterations}" | bc -l)"
			# if file size is lt 16GB, set max preallocation size equal to file size
			# else set max preallocation size to 8GB
			if [[ "${tmp_file_size_kb}" -le 16777216 ]]; then
				file_size_kb="$(echo "scale=0; ${tmp_file_size_kb}/2" | bc -l)"
				max_alloc_size="$(echo "scale=0; ${tmp_file_size_kb}-${file_size_kb}" | bc -l)"
			else
				max_alloc_size=8388608
				file_size_kb="$(echo "scale=0; ${tmp_file_size_kb}-${max_alloc_size}" | bc -l)"
			fi
		else
			file_size_kb="$(echo "scale=0; ${target_size}/${total_iterations}" | bc -l)"
		fi
		# recalculate vars to adjust for rounding
		total_alloc_size="$(echo "${max_alloc_size}*${iterations}" | bc -l)"
		num_blocks="$(echo "scale=0; ${file_size_kb}/${block_size}" | bc -l)"
		file_size_kb="$(echo "${num_blocks}*${block_size}" | bc -l)"
		file_size_gb="$(echo "scale=2;${file_size_kb}/1024/1024" | bc -l)"
		req_space="$(echo "(${file_size_kb}*${total_iterations})+${total_alloc_size}" | bc -l)"
		echo_out "Iterations (threads) per physical core: ${tmult}"
		echo_out "Total iterations: ${iterations}"
		echo_out "Block size: ${block_size} KB"
		echo_out "Blocks per iteration: $(printf "%'d" ${num_blocks})"
		echo_out "File size per iteration: $(print_calc_2d ${file_size_gb}) GB"
		echo_out "Total file size: $(print_calc_2d ${file_size_kb}*${iterations}/1024/1024) GB"
		if [[ "${max_alloc_size}" -gt 0 ]]; then
			[[ ! -z "${man_alloc_size}" ]] && echo_out "Mount-defined preallocation size: ${man_alloc_size}"
			echo_out "Max preallocation size per iteration: $(print_calc_2d ${max_alloc_size}/1024/1024) GB"
			echo_out "Total max preallocation size: $(print_calc_2d ${total_alloc_size}/1024/1024) GB"
		fi
		echo_out "Total required space (including an extra file for flushing file cache): $(print_calc_2d ${req_space}/1024/1024) GB"
		# verify that blocks and block_size are all set before starting tests
		if [[ -z "${num_blocks}" ]]; then
			message_handle 40
		fi
		if [[ -z "${block_size}" ]]; then
			message_handle 41
		fi
	fi
	echo_out "Current time: $(date)"
	echo_out "--- Calculations complete ---"
}

#####
# Start the given IO tests.
# Parameters:
#   None
#####
start_iotests() {
	echo_out "--- Executing ${iotest_mode} IO test ---"
	echo_out "Executing write tests"
	sync
	test_pids=()
	stat_pids=()
	local pid stat
	local count=0
	while [[ "${count}" -lt "${iterations}" ]]; do
		(( count+=1 ))
		echo_out "Launching iteration: ${count}"
		(/usr/bin/time -p dd if=/dev/zero of="${target_dir}/vpt_${iotest_mode}_dd_write.${count}" bs="${block_size}k" count="${num_blocks}" conv=fsync) >"${output_dir}/vpt_${iotest_mode}_write.${count}.out" 2>&1 & test_pids+=("$!")
	done
	echo_out "Waiting for write tests to complete"
	local i=0
	for pid in "${test_pids[@]}"; do
		wait "${pid}"
		stat_pids["${i}"]="$?"
		(( i+=1 ))
	done

	# make sure all write files are the same size -
	#	checks if the FS ran out of space during test
	local size1 size2 prev_count
	count=1
	while [[ "${count}" -lt "${iterations}" ]]; do
		size1="$(ls -ltn "${target_dir}/vpt_${iotest_mode}_dd_write.${count}" 2>/dev/null | awk '{ print $5 }')"
		(( count+=1 ))
		size2="$(ls -ltn "${target_dir}/vpt_${iotest_mode}_dd_write.${count}" 2>/dev/null | awk '{ print $5 }')"
		if [[ -z "${size1}" || -z "${size2}" ]]; then
			prev_count=$(( count-1 ))
			message_handle 42 "${prev_count}" "${count}"
		elif [[ "${size1}" -ne "${size2}" ]]; then
			message_handle 43 "${target_dir}"
		fi
	done
	i=0
	for stat in "${stat_pids[@]}"; do
		if [[ "${stat}" -ne 0 ]]; then
			message_handle 49 "${target_dir}" "${i}"
		fi
		(( i+=1 ))
	done
	echo_out "Write tests complete"

	# flush test files from cache - rename one test file to create a "base" file, delete the rest, and
	#	recreate all files by copying the base file via direct IO
	echo_out "Flushing test files from cache - removing write files and creating copies via direct IO"
	sync
	unset test_pids
	unset stat_pids
	mv "${target_dir}/vpt_${iotest_mode}_dd_write.1" "${target_dir}/vpt_${iotest_mode}_dd_read.base" 2>&1 & test_pids+=("$!")
	count=1
	while [[ "${count}" -lt "${iterations}" ]]; do
		(( count+=1 ))
		rm -f "${target_dir}/vpt_${iotest_mode}_dd_write.${count}" 2>&1 & test_pids+=("$!")
	done
	for pid in "${test_pids[@]}"; do
		wait "${pid}"
		stat_pids+=("$?")
	done
	for stat in "${stat_pids[@]}"; do
		if [[ "${stat}" -ne 0 ]]; then
			message_handle 48 "remove write test files" "${target_dir}"
		fi
	done
	unset test_pids
	unset stat_pids
	count=0
	while [[ "${count}" -lt "${iterations}" ]]; do
		(( count+=1 ))
		(dd if="${target_dir}/vpt_${iotest_mode}_dd_read.base" of="${target_dir}/vpt_${iotest_mode}_dd_read.${count}" bs=1M iflag=direct oflag=direct) >/dev/null 2>&1 & test_pids+=("$!")
	done
	for pid in "${test_pids[@]}"; do
		wait "${pid}"
		stat_pids+=("$?")
	done
	rm -f "${target_dir}/vpt_${iotest_mode}_dd_read.base" 2>&1 & wait "$!"
	stat_pids+=("$?")
	for stat in "${stat_pids[@]}"; do
		if [[ "${stat}" -ne 0 ]]; then
			message_handle 48 "create copies via direct IO" "${target_dir}"
		fi
	done
	echo_out "Flushing test files from cache complete"

	# if parallel mpp test that uses a shared dir, wait for all nodes to finish writes before starting reads
	if [[ "${shared_dir}" -eq 1 ]]; then
		touch "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${GLOBAL_SH_SHOST}.${GLOBAL_EPOCH_TIME}.readhold" 2>&1
		if [[ "$?" -gt 0 ]]; then
			message_handle 39 "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${GLOBAL_SH_SHOST}.${GLOBAL_EPOCH_TIME}.readhold"
		else
			echo_out "Waiting for write tests to complete on all nodes before continuing"
			while [ -f "${GLOBAL_SH_WORKDIR}/${test_type}.parallel.${GLOBAL_SH_SHOST}.${GLOBAL_EPOCH_TIME}.readhold" ]; do
				sleep 2
			done
			echo_out "All write tests complete. Continuing"
		fi
	fi

	echo_out "Executing read tests"
	unset test_pids
	unset stat_pids
	count=0
	while [[ "${count}" -lt "${iterations}" ]]; do
		(( count+=1 ))
		echo_out "Launching iteration: ${count}"
		(/usr/bin/time -p dd if="${target_dir}/vpt_${iotest_mode}_dd_read.${count}" of=/dev/null bs="${block_size}k" count="${num_blocks}") >"${output_dir}/vpt_${iotest_mode}_read.${count}.out" 2>&1 &
		test_pids+=("$!")
	done
	echo_out "Waiting for read tests to complete"
	i=0
	for pid in "${test_pids[@]}"; do
		wait "${pid}"
		stat_pids["${i}"]="$?"
		(( i+=1 ))
	done
	for stat in "${stat_pids[@]}"; do
		if [[ "${stat}" -ne 0 ]]; then
			message_handle 50 "${target_dir}" "${stat}"
		fi
	done
	echo_out "Read tests complete"
	echo_out "--- ${iotest_mode} IO test complete ---"
}

#####
# Extract, compile and print the IO test results.
# Parameters:
#   None
#####
print_iotest_results() {
	# extract times from results files
	egrep -i "real" "${output_dir}/vpt_${iotest_mode}_"*out > "${output_dir}/vpt_${iotest_mode}.real.${iterations}" 2>/dev/null
	local total_read_time=0
	local total_write_time=0
	local result_type result_time
	while read -r result; do
		result_type="$(echo "${result}" | awk -F\: '{ print $1 }')"
		result_time="$(echo "${result}" | awk '{ print $NF }')"
		case "${result_type}" in
			"${output_dir}/vpt_${iotest_mode}_read"*) total_read_time=$(echo "scale=2;${total_read_time} + ${result_time}" | bc -l) ;;
			"${output_dir}/vpt_${iotest_mode}_write"*) total_write_time=$(echo "scale=2;${total_write_time} + ${result_time}" | bc -l) ;;
		esac
	done < "${output_dir}/vpt_${iotest_mode}.real.${iterations}"

	# calculate file sizes and throughput rates
	local file_size_mb average_read_time average_read_rate average_write_time average_write_rate
	file_size_mb="$(echo "scale=2;${file_size_kb}/1024" | bc -l)"
	average_read_time="$(echo "scale=2;${total_read_time}/${iterations}/${tmult}" | bc -l)"
	average_read_rate="$(echo "scale=2;${file_size_mb}/${average_read_time}" | bc -l)"
	average_write_time="$(echo "scale=2;${total_write_time}/${iterations}/${tmult}" | bc -l)"
	average_write_rate="$(echo "scale=2;${file_size_mb}/${average_write_time}" | bc -l)"

	# print results to output files and console
	echo_out "--- Begin ${iotest_mode} IO test results ---"
	echo_out "RESULTS"
	echo_out "TARGET DETAILS"
	echo_out "   directory:    ${target_dir}"
	echo_out "   df -k:        ${target_df}"
	echo_out "   mount point:  ${target_mount}"
	echo_out "   file size:    $(print_calc_2d ${file_size_gb}) GB"
	echo_out " STATISTICS"
	echo_out "   read time:              $(print_calc_2d ${average_read_time}) seconds per physical core"
	echo_out "   read throughput rate:   $(print_calc_2d ${average_read_rate}) MB/second per physical core"
	echo_out "   write time:             $(print_calc_2d ${average_write_time}) seconds per physical core"
	echo_out "   write throughput rate:  $(print_calc_2d ${average_write_rate}) MB/second per physical core"
	echo_out "--- End ${iotest_mode} IO test results ---"
	echo_out "Processing complete."
	echo_out "Start time: ${GLOBAL_START_TIME}."
	echo_out "End time:   $(date)."
	echo_out "-------------------------"
	echo_out "End ${curr_test} for [${GLOBAL_SH_SHOST}]"
	echo_out "-------------------------"
	curr_test=""
}

# ====================================================================
# MAIN SECTION
# ====================================================================
if [[ $# -gt 1 ]]; then
	echo -e "\nERROR: Too many parameters given. Exiting..."
	show_usage
fi

if [[ $# -gt 0 ]]; then
	case "$1" in
		-[Yy]|-[Yy][Ee][Ss]) auto_cont=1 ;;
		-"${GLOBAL_EPOCH_TIME}") ;;
		-h|--h|-help|--help) show_usage ;;
		-v|--v|-version|--version) show_version ;;
		* ) echo -e "\nERROR: Invalid parameter. Exiting...\n"; exit 125 ;;
	esac
fi

check_os
parse_config "${GLOBAL_CONFIG_FULL}"

if [[ "${env_type}" == "mpp" ]]; then
	if [[ -z "${GLOBAL_REMEXEC_HOST}" ]]; then
		trap_with_arg 'main_trap' SIGINT SIGTERM SIGHUP EXIT
		echo_out "-----------------------------"
		echo_out "Running in MPP mode"
		echo_out "-----------------------------"
		echo_out "Running as user: [$(whoami)]"
		echo_out "Number of hosts: ${num_hosts}"
		echo_out "Host list: [${host_list}]"
		check_ssh
		if [[ ! -z "${short_host_list}" ]]; then
			echo_out "Short hostnames: ${short_host_list}"
		fi
		check_rmt_shell
		echo_out "Temporary working directory: [${GLOBAL_SH_WORKDIR}]"
		echo_out "Creating temporary working directory [${GLOBAL_SH_WORKDIR}] on [${GLOBAL_SH_SHOST}]"
		run_mkdir "${GLOBAL_SH_WORKDIR}"
		full_trap=1
		if [[ "${test_count}" -gt 0 ]]; then
			check_cmds
			if [[ "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_CDC}" == "y" ]]; then
				echo_out "Creating temporary working directory [${GLOBAL_SH_WORKDIR}] on remote hosts"
				run_ssh "mkdir -p \${GLOBAL_SH_WORKDIR}"
			fi
		fi
		get_sys_info
		if [[ "${NETWORK_TESTS}" == "y" ]]; then
			start_network_tests
		fi
		if [[ "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_CDC}" == "y" ]]; then
			echo_out "Copying files to all hosts"
			run_scp "${GLOBAL_SCRIPT_DIR}/${GLOBAL_SCRIPT_NAME}" "${GLOBAL_SH_WORKDIR}/${GLOBAL_SCRIPT_NAME}"
			run_scp "${GLOBAL_CONFIG_FULL}" "${GLOBAL_SH_WORKDIR}/${GLOBAL_CONFIG_NAME}"
			if [[ "${IO_TESTS_DATA}" == "y" ]]; then
				echo_out "-----------------------------"
				echo_out "Begin DATA IO Tests"
				echo_out "-----------------------------"
				curr_test="DATA IO Test"
				run_ssh "cd \${GLOBAL_SH_WORKDIR} && ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}" "DATA"
				wait
				echo_out "-----------------------------"
				echo_out "End DATA IO Tests"
				echo_out "-----------------------------"
			fi
			if [[ "${IO_TESTS_CDC}" == "y" ]]; then
				echo_out "-----------------------------"
				echo_out "Begin CDC IO Tests"
				echo_out "-----------------------------"
				curr_test="CDC IO Test"
				run_ssh "cd \${GLOBAL_SH_WORKDIR} && ./${GLOBAL_SCRIPT_NAME} -${GLOBAL_EPOCH_TIME}" "CDC" 
				wait
				echo_out "-----------------------------"
				echo_out "End CDC IO Tests"
				echo_out "-----------------------------"
			fi
		fi
	else
		trap_with_arg 'remote_trap' SIGINT SIGTERM SIGHUP EXIT
		if [[ "${test_type}" == "DATA" ]]; then
			curr_test="Data IO Test"
			initialize_io "data" "${DATA_DIR}"
			if [[ "${skip_iotest}" -eq 0 ]]; then
				start_iotests
				print_iotest_results
				clean_up_data
			fi
		elif [[ "${test_type}" == "CDC" ]]; then 
			curr_test="CDC IO Test"
			initialize_io "cdc" "${CDC_DIR}"
			if [[ "${skip_iotest}" -eq 0 ]]; then
				start_iotests
				print_iotest_results
				clean_up_data
			fi
		fi
	fi
elif [[ "${env_type}" == "smp" ]]; then
	trap_with_arg 'main_trap' SIGINT SIGTERM SIGHUP EXIT
	echo_out "-----------------------------"
	echo_out "Running in SMP mode"
	echo_out "-----------------------------"
	echo_out "Running as user: [$(whoami)]"
	echo_out "Host list: [${host_list}]"
	echo_out "Short hostname: [${GLOBAL_SH_SHOST}]"
	# TODO: check smp host here
	if [[ "${IO_TESTS_DATA}" == "y" || "${IO_TESTS_CDC}" == "y" ]]; then
		check_cmds
	fi
	echo_out "Temporary working directory: [${GLOBAL_SH_WORKDIR}]"
	echo_out "Creating temporary working directory [${GLOBAL_SH_WORKDIR}] on [${GLOBAL_SH_SHOST}]"
	run_mkdir "${GLOBAL_SH_WORKDIR}"
	full_trap=1
	get_sys_info
	if [[ "${IO_TESTS_DATA}" == "y" ]]; then
		test_type=DATA
		curr_test="PATH IO Test"
		echo_out "-----------------------------"
		echo_out "Begin DATA IO Tests"
		echo_out "-----------------------------"
		initialize_io "data" "${DATA_DIR}"
		if [[ "${skip_iotest}" -eq 0 ]]; then
			start_iotests
			print_iotest_results
			clean_up_data
		fi
		echo_out "-----------------------------"
		echo_out "End DATA IO Tests"
		echo_out "-----------------------------"
	fi
	if [[ "${IO_TESTS_CDC}" == "y" ]]; then
		test_type=CDC
		curr_test="CDC IO Test"
		echo_out "-----------------------------"
		echo_out "Begin CDC IO Tests"
		echo_out "-----------------------------"
		initialize_io "cdc" "${CDC_DIR}"
		if [[ "${skip_iotest}" -eq 0 ]]; then
			start_iotests
			print_iotest_results
			clean_up_data
		fi
		echo_out "-----------------------------"
		echo_out "End CDC IO Tests"
		echo_out "-----------------------------"
	fi
fi

if [[ ! "${GLOBAL_REMEXEC_HOST}" ]]; then
	clean_work=1
	clean_up_rem_work
	if [[ "${OUTPUT_TO_FILE}" == "y" ]]; then
		echo "Execution is complete!"
		if [[ "${#test_errors[@]}" -eq 0 && "${#skipped_tests[@]}" -eq 0 ]]; then
			echo ""
		fi
	fi
	echo_out "Execution is complete!"
	wrapper_rc=125
	if [[ "${#test_errors[@]}" -gt 0 ]]; then
		print_test_errors
	else
		print_skipped_tests
	fi	
fi
trap - EXIT
exit 0
