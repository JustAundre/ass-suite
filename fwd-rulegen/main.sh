#!/usr/bin/env bash
#
# Environment Setup
#
cd "$(dirname "${0}")" || exit 1
[[ -d "../lib/" ]] || exit 2
for function in ../lib/*; do
	. "${function}"
done
persistences=(
	'Persistent'
	'Ephemeral'
)





#
# Main Loop
#
# Get persistence state
persistence="$(cl-new -t 'Select persistence state' "${persistences[@]}")"
#
# Gather the IP version, source/destination IPs and ports, the protocol, and the action.
# (Subshell for variable clearing again.)
fields=(
	'ipv4'      # IP version
	'1.0.0.0'   # Source IP
	'30'        # Source port
	'2.0.0.0/8' # Destination IP
	'60'        # Destination port
	'tcp'       # Protocol
	'drop'      # Action
)
target=0
while true; do
	# Show the composition of the rule live
	printf '\033[H\033[J'
	rich_rule=$'--add-rich-rule=\''
	#
	# Interprets the IP family;
	# Only valid values are ipv4/ipv6.
	[[ -n "${fields[0]}" ]] && rich_rule+="rule family=\"${fields[0]}\" "
	if [[ "${fields[0]}" =~ ^ipv[46]$ ]]; then
		plaintext="Set an ${fields[0]} rule which "
	else
		plaintext='Set an N/A rule which '
	fi
	#
	# Interprets the source IP
	# Uses `ip route get` as a linter for IP addresses.
	[[ -n "${fields[1]}" ]] && rich_rule+="source address=\"${fields[1]}\" "
	if [[ -z "${fields[1]}" ]]; then
		plaintext+='finds requests from anywhere, '
	elif
		ip route get "${fields[1]}" &>/dev/null
		status="$?"
		[[ ! "${status}" -eq 1 ]]
	then
		plaintext+="matches requests from ${fields[1]}, "
	else
		plaintext+='matches requests from N/A, '
	fi
	#
	# Interprets the source port
	# The lowest port number is 0 (exclusive) and 2^16 - 1 (inclusive).
	[[ -n "${fields[2]}" ]] && rich_rule+="source-port port=\"${fields[2]}\" "
	if [[ "${fields[2]}" =~ ^[0-9]{1,5}$ && "${fields[2]}" -gt 0 && "${fields[2]}" -le 65535 ]]; then
		plaintext+="port ${fields[2]}, "
	elif [[ -z "${fields[2]}" ]]; then
		plaintext+="coming from any port, "
	else
		plaintext+="port N/A, "
	fi
	#
	# Interprets the destination port
	# Same underlying logic as source port/[2]
	# [3] is partially parsed here and [4] is partially parsed below because-
	# the ip/port format is flipped to port/ip in the English transcription in favor of sentence flow.
	[[ -n "${fields[3]}" ]] && rich_rule+="destination address=\"${fields[3]}\" "
	if [[ "${fields[4]}" =~ ^[0-9]{1,5}$ && "${fields[4]}" -gt 0 && "${fields[4]}" -le 65535 ]]; then
		plaintext+="en route to port ${fields[4]} "
	elif [[ -z "${fields[4]}" ]]; then
		plaintext+="en route to any port "
	else
		plaintext+="en route to port N/A "
	fi
	#
	# Interprets the destination IP
	# Same underlying logic as source IP/[1]
	[[ -n "${fields[4]}" ]] && rich_rule+="port port=\"${fields[4]}\" "
	if [[ -z "${fields[3]}" ]]; then
		plaintext+='of any IP '
	elif
		ip route get "${fields[3]}" &>/dev/null
		status="$?"
		[[ ! "${status}" -eq 1 ]]
	then
		plaintext+="of ${fields[3]} "
	else
		plaintext+='of N/A '
	fi
	#
	# Interprets the protocol;
	# Only valid options are tcp/udp.
	[[ -n "${fields[5]}" ]] && rich_rule+="protocol=\"${fields[5]}\" "
	if [[ "${fields[5]}" =~ ^(udp|tcp)$ ]]; then
		plaintext+="with the ${fields[5]} protocol "
	elif [[ -z "${fields[5]}" ]]; then
		plaintext+='using any protocol '
	else
		plaintext+='with the N/A protocol '
	fi
	#
	# Interprets the action;
	# Only valid options are accept/reject/drop.
	[[ -n "${fields[6]}" ]] && rich_rule+="${fields[6]}"
	[[ "${fields[6]}" =~ ^(accept|reject|drop)$ ]] && plaintext+="and ${fields[6]}s it." || plaintext+="and N/As it."
	#
	# Closes the rule.
	rich_rule+=\'
	#
	# Prints the live composition, plain-English transcription, and current working field.
	printf '%s\n\n%s\n\e[1;32m> %s\e[0m' "${rich_rule}" "${plaintext}" "${fields["${target}"]}"
	#
	# Read fields character by character
	# Backspace works as backspace.
	# Change fields with [ENTER].
	IFS='' read -sn1 'input[0]'
	if [[ "${input[0]}" == $'\E' ]]; then
		IFS='' read -sn2 'input[1]'
	else
		unset input[1]
	fi
	case "${input[0]}${input[1]}" in
	$'\x7f'|$'\b')
		fields["${target}"]="${fields["${target}"]%?}"
		;;
	$'\E[D')
		((target<=0)) || ((target--))
		;;
	$'\E[C')
		((target>=${#fields[@]}-1)) || ((target++))
		;;
	'')
		printf '\033[H\033[J'
		break
		;;
	*)
		[[ "${input[0]}${input[1]}" =~ ^[a-zA-Z0-9.:/]$ ]] && fields["${target}"]+="${input[0]}"
		;;
	esac
done
[[ "${persistence,,}" =~ 'Persistent' ]] && firewall_cmd_args+=('--permanent')
firewall_cmd_args+=("${rich_rule}")
echo "firewall-cmd ${firewall_cmd_args[*]}"
