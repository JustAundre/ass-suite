#!/usr/bin/env bash





#
# Environment Setup
#
# List of valid resource items in limits.conf
valid_items=(
	core
	data
	fsize
	memlock
	msgqueue
	nice
	locks
	maxlogins
	maxsyslogins
	priority
	nproc
	as
	rss
	cpu
	rtprio
	rttime
	sigpending
	nofile
)
#
# Function to check if an item is in an array
contains_element() {
	local match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}





#
# Modify/Verify
#
pass=0
until ((pass)); do
	pass=1
	"${EDITOR}" cnf/rsc-caps/limits.conf

	while read -r domain type item value extra; do
		# Ignore lines with extra trailing fields or empty values
		if [[ -z "${domain}" || -z "${type}" || -z "${item}" || -z "${value}" || -n "${extra}" ]]; then
			pass=0
			break
		fi
		#
		# Validate domain, type (soft, hard, or -), item, and integer (plus -1 or 'unlimited')
		if ! {
			[[ "${domain}" =~ ^@[0-9]+(:[0-9]+)?$ || "${domain}" =~ ^[0-9]+(:[0-9]+)?$ || "${domain}" == '*' ]] ||
			{ [[ "${domain}" =~ ^[@%]([a-zA-Z_.-]{1,32})$ ]] && getent group "${BASH_REMATCH[1]}" &>/dev/null; } ||
			{ [[ "${domain}" =~ ^([a-zA-Z_.-]{1,32})$ ]] && getent passwd "${BASH_REMATCH[1]}" &>/dev/null; }
		} || ! {
			[[ "${type}" =~ ^(soft|hard|-)$ ]] &&
			[[ "${value}" =~ ^(-1|[0-9]+|unlimited)$ ]] &&
			contains_element "${item}" "${valid_items[@]}"
		}; then
			pass=0
			break
		fi
	done < <(grep -Ev '^\s*(#|$)' cnf/rsc-caps/limits.conf)

	if ((! pass)); then
		log w 'There was a syntax error in your limits.conf.'
		read -rp "Press [ENTER] to re-edit, or wait 10 seconds to exit." -t 10 || exit 10
	fi
done





#
# Install
#
install -m 644 -o 0 -g 0 -Dv cnf/rsc-caps/limits.conf /etc/security/limits.conf
