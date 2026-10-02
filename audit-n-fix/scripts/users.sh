#!/usr/bin/env bash
# TODO: FreeBSD compatibility needed





#
# Environment Setup
#
mapfile -t shells < <(chsh -l)
#
# Compile vanity tags for display in checklists
# Create reverse-lookup associative array for matching backwards-matching from vanity to IDs
declare -A reverse_lookup
confirm 'Exclude system users from audit'
include_sys="${?}"
for entry in "${passwd[@]}"; do
	IFS=':' read -rd $'\n' user hash uid gid gecos home shell <<<"${entry}"
	((!include_sys)) && [[ "${shell}" =~ /(nologin|false)$ ]] && continue
	user_vanities+=("$(id "${uid}") sh=${shell@Q}")
	reverse_lookup["${user_vanities["$((${#user_vanities[@]} - 1))"]}"]="${user}"
done
for entry in "${group[@]}"; do
	IFS=':' read -rd $'\n' group hash gid members <<<"${entry}"
	group_vanities+=("gid=${gid}(${group})")
	reverse_lookup["${group_vanities["$((${#group_vanities[@]} - 1))"]}"]="${group}"
done





#
# Prompting
#
mapfile -td '' selections < <(PS2='Select users to modify' cl-new -mo "${user_vanities[@]}")
for selection in "${selections[@]}"; do
	declare -A index
	choices=(
		'Delete user'
		'Lock user'
		'Remove password'
		'Change password'
		'Change shell'
		'Change UID'
		'Change GID'
		'Change Supplementary groups'
	)
	for choice in "${!choices[@]}"; do
		declare index["${choice}"]=0
	done
	mapfile -td '' selections_2 < <(PS2='Modifying user: '"${selection}" cl-new -mo "${choices[@]}")
	for selection_2 in "${selections_2[@]}"; do
		index["${selection_2}"]=1
	done
	if ((index['Delete user'] && ${#selections_2[@]} > 1)); then
		log e 'users.sh: [Delete] is mutually exclusive with all other options.'
		log i "users.sh: skipping all processing (as a result of the above error) for user: ${selection}"
		continue
	elif ((index['Remove password'] && index['Change password'])); then
		log e 'users.sh: [Remove password] is mutually exclusive with [Change password].'
		log i "users.sh: skipping all processing (as a result of the above error) for user: ${selection}"
		continue
	fi
	user="${reverse_lookup["${selection}"]}"
	if ((index['Delete user'])); then
		userdel -rf "${user}"
	fi
	if ((index['Lock user'])); then
		passwd "${user}" -l
	fi
	if ((index['Remove password'])); then
		passwd "${user}" -d
	fi
	if ((index['Change password'])); then
		passwd "${user}"
	fi
	if ((index['Change shell'])); then
		unset shell
		shell="$(PS2="Pick the new shell for user: ${user@Q}" cl-new "${shells[@]}")"
		usermod -s "${shell}" "${user}"
	fi
	if ((index['Change UID'])); then
		unset uid
		until
			[[ ${uid} =~ ^[0-9]+$ ]] &&
			! getent passwd "${uid}" /etc/passwd &> /dev/null
		do
			read -erp 'Enter the new UID: ' uid
		done
		usermod -u "${uid}" "${user}"
	fi
	if ((index['Change GID'])); then
		unset primary_group
		primary_group="${reverse_lookup["$(PS2="Select the new primary group for user \"${user}\"" cl-new -o "${group_vanities[@]}")"]}"
		usermod -g "${primary_group}" "${user}"
	fi
	if ((index['Change supplementary groups'])); then
		unset supplementary_groups selections_3
		mapfile -td '' selections_3 < <(PS2="Select new supplementary groups for user \"${user}\"" cl-new -mo "${group_vanities[@]}")
		for selection_3 in "${selections_3[@]}"; do
			supplementary_groups+=("${reverse_lookup["${selection_3}"]}")
		done
		supplementary_groups="${supplementary_groups[*]}"
		((${#supplementary_groups})) && usermod -G "${supplementary_groups// /,}" "${user}"
	fi
done
