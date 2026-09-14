#!/usr/bin/env bash
#
# Environment Setup
#
# CD into the script's parent directory.
cd "$(dirname "${0}")" || exit 1
#
# Source library commands/vars
[[ -d "../lib/" ]] || exit 2
for function in "../lib/"*; do
	. "${function}"
done
#
# Set editor
export EDITOR
hash "${EDITOR}" &>/dev/null || for EDITOR in nano micro mcedit tilde joe e3 hx nvim vim vi kak emacs ed mp jed ash vis sam; do
	hash "${EDITOR}" &>/dev/null && break
done
until hash "${EDITOR}" &>/dev/null; do
	log w 'The EDITOR variable is invalid or undeclared.' "A recognized editor couldn't be found in the PATH."
	read -erp 'Type a text editor and hit [ENTER] to confirm: ' EDITOR
done





#
# Environment Check
#
log i 'Running environment checks...'
#
# 1. Is this running in Bash & NOT sourced?
# 2. Does this script have root permissions?
# 3. Is the active init. system SystemD?
# 4. Is the output a terminal?
[[ ${BASH_SOURCE[0]} == "${0}" ]] || errors+=('Script must be ran by Bash intepreter & must NOT be sourced.')
[[ ${EUID} -eq 0 ]] || errors+=("Must run as root. Try (sudo bash ${0}).")
[[ "$(< /proc/1/comm)" == 'systemd' ]] || errors+=('Your init. system is unsupported (must be using SystemD).')
[[ -t 0 ]] || errors+=('All scripts here require an interactive terminal.')
#
# If any of the above, alert.
if [[ ${#errors[@]} -ge 1 ]]; then
	log e "${errors[@]}" "Failed ${#errors[@]} startup checks."
	confirm 'Proceed anyway' || exit 3
else
	log i 'Passed environment checks.'
fi





#
# Script Selection
#
mapfile -td '' scripts < <(find scripts -name '*.sh' -print0 | sort -z)
mapfile -td '' selections < <(PS2='Choose a script to run' cl-new -m "${scripts[@]}")
for script in "${selections[@]}"; do
	(
		#
		# Shell Opts & Helper Variables
		#
		# Define secure UMASK
		# Make a pipeline's exit code the exit code of the last failed command of the pipelines
		# Load the PATH variable into an array
		# Load all executables in the PATH into an array
		# Load users into arrays by type
		# Store OS details in an associative array
		trap 'exit 130' SIGINT
		umask 0077
		set -o pipefail
		mapfile -td ':' paths < <(printf '%s' "${PATH}")
		mapfile -td '' binaries < <(find -- "${paths[@]}" -maxdepth 1 -type f -executable -print0)
		mapfile -t int_users < <(
			grep -vE '/(nologin|false|true)$' /etc/passwd |
				awk -F: '$3 >= 1000 { print $1 }'
		)
		mapfile -t nonint_users < <(
			grep -E '/(nologin|false|true)$' /etc/passwd |
				awk -F: '$3 < 1000 { print $1 }'
		)
		mapfile -t all_users < <(cut -d: -f1 < /etc/passwd)
		declare -A os_info
		while IFS='=' read -r key value; do
			value="${value%\"}"
			value="${value#\"}"
			os_info["${key}"]="${value}"
		done < /etc/os-release
		export paths binaries int_users nonint_users all_users os_info
		#
		# Execute the script.
		. "${script}"
	)
	if ((${?} == 130)); then
		log i 'Sending SIGINT (CTRL + C) during script execution sends you back to the main menu.' 'Send SIGINT again to terminate the script.'
		pause
		exec "${0}"
	fi
done





#
# Exit
#
clear -x
cat <<- EOF
	  ---{=========}###[@]###{===========}---
	        WINDOWS AT LOSS AT THE
	           AGAPE FREEDOM OF LINUX
	  ---{=========}###[@]###{===========}---

	      Cybersecurity is great; though,
	    people often have their priorities
	       mixed up. Make sure you have
	        good password hygiene and
	         a good password manager.

EOF
exit 0
