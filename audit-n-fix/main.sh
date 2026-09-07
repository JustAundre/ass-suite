#!/usr/bin/env bash





#
# Environment Setup
#
# CD into the script's parent directory;
# Source global functions and variables.
cd "$(dirname "${0}")" || exit 1
#
# Source library commands
[[ -d "../lib/" ]] || exit 1
for function in "../lib/"*; do
	. "${function}"
done
#
# Set editor
# Secure UMASK
# Include hidden directories when globbing
# Trying to avoid errors when globbing results in nothing, & set case insensitivity for responses.
# Unset aliases & disable alias expansion
# Make a pipeline's exit code the exit code of the last failed command of the pipelines
export EDITOR
until [[ -x "${EDITOR}" ]] || hash "${EDITOR}" &>/dev/null; do
	log w 'EDITOR environment variable is invalid or empty; try nano or vi?'
	read -erp 'Type a text editor and hit [ENTER] to confirm: ' EDITOR
done
umask 077
shopt -s dotglob nullglob nocasematch
unalias -a
set -o pipefail





#
# Helper Variables
#
# Load the PATH variable into an array, then all executables in the PATH into an array
mapfile -td ':' paths < <(printf '%s' "${PATH}")
mapfile -td '' binaries < <(find -- "${paths[@]}" -maxdepth 1 -type f -executable -print0)
#
# Load all interactive, non-interactvie, and all users into their respective arrays
mapfile -t int_users < <(
	grep -vE '/(nologin|false|true)$' /etc/passwd |
		awk -F: '$3 >= 1000 { print $1 }'
)
mapfile -t nonint_users < <(
	grep -E '/(nologin|false|true)$' /etc/passwd |
		awk -F: '$3 < 1000 { print $1 }'
)
mapfile -t all_users < <(cut -d: -f1 < /etc/passwd)
#
# Store OS details in an associative array.
declare -A os_info
while IFS='=' read -r key value; do
	value="${value%\"}"
	value="${value#\"}"
	os_info["${key}"]="${value}"
done < /etc/os-release





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
[[ "$(< /proc/1/comm)" == systemd ]] || errors+=('System is not using SystemD which is the only system daemon supported by this script.')
[[ -t 0 ]] || errors+=('All scripts here require an interactive terminal.')
#
# If any of the above, alert.
if [[ ${#errors[@]} -ge 1 ]]; then
	log e "${errors[@]}"
	log e "Failed ${#errors[@]} startup checks."
	confirm 'Continue' || exit 2
fi
log i 'Passed startup checks.'





#
# Discovery & Execution
#
# Enumerate all scripts, select 1 for execution.
mapfile -td '' scripts < <(find scripts -name '*.sh' -print0 | sort -z)
script="$(cl-new -t 'Choose a script to run' "${scripts[@]}")"
. "${script}"





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
