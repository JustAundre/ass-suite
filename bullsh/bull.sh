#!/usr/bin/env bash

#
# Environment Setup
#
# Source configuration
. "$(dirname "${0}")/config.sh" || exit 1

#
# The Shell
#
# Send identifiers to a log file
log() {
	local msg
	case "${1}" in
	fail)
		shift 1
		msg="W: ${USER}/${UID}@${SSH_CLIENT%% *} with EUID ${EUID} on ${TTY} failed ${layer_at} with input: ${1}"
		;;
	pass)
		msg="i: ${USER}/${UID}@${SSH_CLIENT%% *} on ${TTY} passed onto ${layer_at}"
		;;
	enter)
		msg="i: ${USER}/${UID}@${SSH_CLIENT%% *} on ${TTY} passed into a real terminal."
		;;
	*)
		echo 'E: The function was called with a non-existent warning type.'
		return 1
		;;
	esac
	systemd-cat -t "${config[log_tag]}" <<<"${msg}"
}
#
# Function to pass into the real shell
handover() {
	# Log the successful attempt & pass into a real shell.
	log enter
	builtin exec /usr/bin/env -i SSH_CONNECTION="${SSH_CONNECTION}" SSH_CLIENT="${SSH_CLIENT}" SSH_TTY="${SSH_TTY}" SSH_ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND}" /usr/bin/bash -il
}
#
# Function to hash input
hash() {
	# Variable scoping/isolation
	# Hash the input
	local input="${input}"
	local PS1="${PS1}"
	local layer_at="${layer_at}"
	local counts="${counts}"
	python3 -c "${python_hashing_logic}" <<<"${input}"
}
#
# Function to check input
passwd_check() {
	((counts++))
	local input="${input}"
	local cmd="${input%% *}" target_hash="${hashes[$((layer_at - 1))]}" in_hashed
	#
	# Update history (L1 exclusive)
	# Simulate a fake delay (if configured)
	# Silently lock out after max_tries
	# Generate hash only if not locked out
	[[ ${layer_at} -eq 1 ]] && history -s "${input}"
	[[ ${config[fake_latency]} == y ]] && sleep "${config[fake_latency]}"
	((stop_hash)) || [[ ${counts} -gt ${config[retry_cap]} ]] && declare -r stop_hash=1
	((stop_hash)) || in_hashed="$(hash)"
	#
	# Input Parsing
	# Print a fake error & exit if the input is too big
	if [[ ${#input} -gt ${config[stdin_cap]} ]]; then
		printf "\nrbash: fork: cannot allocate memory\n"
		exit 255
	#
	# Do nothing on empty input
	elif [[ -z ${input} ]]; then
		return 1
	#
	# Check for current layers' password
	elif ((stop_hash)) || [[ -n ${input} && ${in_hashed} == "${target_hash}" ]]; then
		# Reset fail counter & return success.
		log pass
		counts=0
		return 0
	#
	# Mimic rbash restrictions & errors (L1 exclusive)
	elif [[ ${layer_at} -eq 1 ]]; then
		if [[ ${cmd} == */* ]]; then
			echo "rbash: ${cmd}: cannot specify \"/\" in command names"
			log fail "${input}"
			return 1
		elif [[ ${cmd} =~ ^(exit|logout)$ ]]; then
			exit 1
		elif [[ ${cmd} == sudo ]]; then
			if ((config[fake_root])); then
				echo 'root is not in the sudoers file.  This incident will be reported.'
			else
				sudo echo "${USER} is not in the sudoers file.  This incident will be reported."
			fi
			log fail "${input}"
			return 2
		elif [[ ${cmd} == printf ]]; then
			printf '%s' "${input/'printf '//}"
			log fail "${input}"
			return 2
		elif [[ ${cmd} == echo ]]; then
			printf '%s' "${input/'echo '//}\n"
			log fail "${input}"
			return 2
		elif [[ ${cmd} =~ ^([a-zA-Z0-9_-]+)= ]]; then
			echo "rbash: ${BASH_REMATCH[1]}: readonly variable"
			log fail "${input}"
			return 2
		elif type -t "${cmd}" &>/devnull; then
			echo "rbash: ${cmd}: Permission denied"
			log fail "${input}"
			return 2
		fi
	fi
	#
	# Log failure
	log fail "${input}"
	echo "rbash: ${cmd}: command not found"
	return 3
}
#
# Prevent changing of core logic
declare -rf log handover hash passwd_check

#
# The Honey
#
# Fake terminal loop
while :; do
	case "${layer_at}" in
	1)
		# L1 | False Terminal
		read -t "${config[timeout]}" -erp "${PS1}" -n "$((config[stdin_cap] + 1))" input || exit 1
		#
		# Check the input & move into next layer if correct.
		passwd_check || continue
		[[ ${#hashes[@]} -gt 1 ]] || handover
		#
		# Check the input & move into next layer or pass into real shell if no more layers.
		stty -echo
		trap '' INT TERM
		echo 'This account is currently not available.'
		((layer_at++))
		;;
	2)
		# L2 | Silence
		read -t "${config[timeout]}" -ern "$((config[stdin_cap] + 1))" input || exit 1
		#
		# Check the input & move into next layer...
		# Or pass into real shell if no more layers.
		passwd_check || continue
		[[ ${#hashes[@]} -gt 2 ]] || handover
		((layer_at++))
		;;
	3)
		# L3 | Silence (Again)
		read -t "${config[timeout]}" -ern "$((config[stdin_cap] + 1))" input || exit 1
		#
		# Check the input & move into next layer or pass into real shell if no more layers.
		passwd_check || continue
		[[ ${#hashes[@]} -gt 3 ]] || handover
		((layer_at++))
		;;
	*)
		# Fallback for unexpected layer_at values
		layer_at=1
		;;
	esac
done
