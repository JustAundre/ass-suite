#!/usr/bin/env bash





#
# FirewallD TUI
#
hash firewall-cmd && while true; do
	# Get persistence state
	persistences=(
		'On-disk'
		'In-memory'
		'On-disk & in-memory'
	)
	if hash firewall-cmd; then
		persistence="$(cl-new -t 'Where should this rule go?' "${persistences[@]}")"
	else
		persistence='On-disk & in-memory'
	fi
	#
	# Gather the IP version, source/destination IPs and ports, the protocol, and the action.
	# (Subshell for variable clearing again.)
	(
		input=(
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
			clear
			rich_rule=$'--add-rich-rule=\''
			#
			# Interprets the IP family;
			# Only valid inputs are ipv4/ipv6.
			[[ -n "${input[0]}" ]] && rich_rule+="rule family=\"${input[0]}\" "
			[[ "${input[0]}" =~ ^ipv[46]$ ]] &&
				readable="Set an ${input[0]} rule which " ||
				readable='Set an N/A rule which '
			#
			# Interprets the source IP
			# Uses `ip route get` as a linter for IP addresses.
			[[ -n "${input[1]}" ]] && rich_rule+="source address=\"${input[1]}\" "
			if [[ -z "${input[1]}" ]]; then
				readable+='finds requests from anywhere, '
			elif
				ip route get "${input[1]}" &>/dev/null
				status="$?"
				[[ ! "${status}" -eq 1 ]]
			then
				readable+="finds requests from ${input[1]}, "
			else
				readable+='finds requests from N/A, '
			fi
			#
			# Interprets the source port
			# The lowest port number is 0 (exclusive) and 2^16 - 1 (inclusive).
			[[ -n "${input[2]}" ]] && rich_rule+="source-port port=\"${input[2]}\" "
			if [[ "${input[2]}" =~ ^[0-9]{1,5}$ && "${input[2]}" -gt 0 && "${input[2]}" -le 65535 ]]; then
				readable+="port ${input[2]}, "
			elif [[ -z "${input[2]}" ]]; then
				readable+="coming from any port, "
			else
				readable+="port N/A, "
			fi
			#
			# Interprets the destination port
			# Same underlying logic as source port/[2]
			# [3] is partially parsed here and [4] is partially parsed below because-
			# the ip/port format is flipped to port/ip in the English transcription in favor of sentence flow.
			[[ -n "${input[3]}" ]] && rich_rule+="destination address=\"${input[3]}\" "
			if [[ "${input[4]}" =~ ^[0-9]{1,5}$ && "${input[4]}" -gt 0 && "${input[4]}" -le 65535 ]]; then
				readable+="en route to port ${input[4]} "
			elif [[ -z "${input[4]}" ]]; then
				readable+="en route to any port "
			else
				readable+="en route to port N/A "
			fi
			#
			# Interprets the destination IP
			# Same underlying logic as source IP/[1]
			[[ -n "${input[4]}" ]] && rich_rule+="port port=\"${input[4]}\" "
			if [[ -z "${input[3]}" ]]; then
				readable+='of any IP '
			elif
				ip route get "${input[3]}" &>/dev/null
				status="$?"
				[[ ! "${status}" -eq 1 ]]
			then
				readable+="of ${input[3]} "
			else
				readable+='of N/A '
			fi
			#
			# Interprets the protocol;
			# Only valid options are tcp/udp.
			[[ -n "${input[5]}" ]] && rich_rule+="protocol=\"${input[5]}\" "
			if [[ "${input[5]}" =~ ^(udp|tcp)$ ]]; then
				readable+="with the ${input[5]} protocol "
			elif [[ -z "${input[5]}" ]]; then
				readable+='with any protocol '
			else
				readable+='with the N/A protocol '
			fi
			#
			# Interprets the action;
			# Only valid options are accept/reject/drop.
			[[ -n "${input[6]}" ]] && rich_rule+="${input[6]}"
			[[ "${input[6]}" =~ ^(accept|reject|drop)$ ]] && readable+="and ${input[6]}s it." || readable+="and N/As it."
			#
			# Closes the rule.
			rich_rule+=\'
			#
			# Prints the live composition, plain-English transcription, and current working field.
			printf '%s\n\n%s\n\e[1;32m> %s\e[0m\n' "${rich_rule}" "${readable}" "${input["${target}"]}"
			#
			# Read input character by character
			# Backspace works as backspace.
			# Change fields with [ENTER].
			IFS='' read -srn1 char
			if [[ "${char}" == $'\x7f' || "${char}" == $'\b' ]]; then
				input["${target}"]="${input[${target}]%?}"
			elif [[ -z "${char}" ]]; then
				((target++))
			elif [[ "${char}" =~ ^[a-zA-Z0-9.:/]$ ]]; then
				input["${target}"]+="${char}"
			else
				log w "Invalid character \"${char}\"" && pause
			fi
			#
			# Exit once all fields are filled
			[[ "${target}" -ge "${#input[@]}" ]] && break
		done
		firewall_cmd_args+=("${rich_rule}")
		echo "firewall-cmd ${firewall_cmd_args[*]}"
		#
		# Stop execution if the rule is incorrect
		# shellcheck disable=SC2106
		confirm 'Is this correct' || continue
		#
		# Commit rule to disk/memory respectively if selected.
		[[ "${persistence,,}" =~ 'in-memory' ]] && firewall-cmd "${firewall_cmd_args[@]}"
		[[ "${persistence,,}" =~ 'on-disk' ]] && firewall_cmd_args+=('--permanent')
		firewall-cmd "${firewall_cmd_args[@]}"
	)
	#
	# Is it time to exit?
	confirm 'Make another rule' || break
done
