#!/usr/bin/env bash
# Curly brackets to stop output of staging commands
{
	# Set secure/safe shell configurations
	set +o xtrace verbose monitor nolog ignoreeof
	set -o functrace errtrace pipefail nounset noclobber
	shopt -s histappend histverify cmdhist dotglob globstar interactive_comments
	shopt -u cdable_vars cdspell dirspell extglob nocaseglob nocasematch expand_aliases progcomp
	umask 077
	#
	# Lock down variables
	declare -rx PROMPT_COMMAND='history -a; history -w; sleep .15'
	declare -rx HISTIGNORE=
	declare -rx HISTCONTROL=ignoreboth
	declare -rx LD_PRELOAD=
	declare -rx HISTSIZE=-1
	declare -rx HISTFILESIZE=-1
	PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
	TTY="$(tty)"
	declare -rx TTY="${TTY##*/}"
	declare -rx SSH_TTY="${TTY}"
	UID="$(< /proc/self/loginuid)"
	[[ "${UID}" == 4294967295 ]] && UID="$(id -u)"
	declare -rx UID
	USER="$(id -nu)"
	HOME="$(getent passwd "${USER}" | cut -f6)"
	HOSTNAME="$(hostname)"
	declare -rx USER HOME HOSTNAME
	declare -rx LOGNAME="${USER}"
	declare -rx HISTFILE="${HOME}/.bash_history"
	for var in SSH_CONNECTION SSH_CLIENT; do
		[[ -z "${var}" ]] && declare -rx "${var}=Local"
	done
	declare -rx SSH_ORIGINAL_COMMAND
	#
	# Remove usage of commands which allow bypasses or unauthorized forensics
	builtin enable -n set shopt umask kill builtin command getopts unalias ulimit disown enable times alias echo printf
} &>/dev/null
