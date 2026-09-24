#!/usr/bin/env bash
# TODO: FreeBSD compatibility needed





#
# Environment Setup
#
# Gather all groups & respective GIDs into an array
mapfile -t all_groups < <(cut -d ':' -f 1 < /etc/group)
mapfile -t all_gids < <(cut -d ':' -f 3 < /etc/group)
#
# Compile vanity tags for display in checklists
for user in "${all_users[@]}"; do
	user_vanities+=("$(id "${user}") sh=$(grep -E "^${user}:" /etc/passwd | cut -d ':' -f 7)")
done
for ((i=0; i<${#all_groups[@]}; i++)); do
	group_vanities+=("gid=${all_gids["${i}"]}(${all_groups["${i}"]})")
done
#
# Create reverse-lookup associative array for matching backwards-matching from vanity to IDs
declare -A reverse_lookup
for ((i=0; i<${#user_vanities[@]}; i++)); do
	reverse_lookup["${user_vanities["${i}"]}"]="${all_users["${i}"]}"
done
for ((i=0; i<${#group_vanities[@]}; i++)); do
	reverse_lookup["${group_vanities["${i}"]}"]="${all_groups["${i}"]}"
done
#
# Prompt checklists
mapfile -td '' selections < <(PS2='Select users to delete' cl-new -mo "${user_vanities[@]}")
for selection in "${selections[@]}"; do
	users_del+=("${reverse_lookup["${selection}"]}")
done
for vanity in "${user_vanities[@]}"; do
	user="${reverse_lookup["${vanity}"]}"
	grep -qE "^${u}:"'[^!:]+\$' /etc/shadow || password_users+=("${vanity}")
done
mapfile -td '' selections < <(PS2='Select users to remove passwords from' cl-new -mo "${password_users[@]}")
for selection in "${selections[@]}"; do
	users_nullpass+=("${reverse_lookup["${selection}"]}")
done
for vanity in "${user_vanities[@]}"; do
	user="${reverse_lookup["${vanity}"]}"
	grep -qE "^${u}:"'!' /etc/shadow || unlocked_users+=("${vanity}")
done
mapfile -td '' selections < <(PS2='Select users to lock' cl-new -mo "${unlocked_users[@]}")
for selection in "${selections[@]}"; do
	users_lock+=("${reverse_lookup["${selection}"]}")
done
mapfile -td '' selections < <(PS2='Select users to select a new shell for' cl-new -mo "${user_vanities[@]}")
for selection in "${selections[@]}"; do
	users_reshell+=("${reverse_lookup["${selection}"]}")
done
mapfile -td '' selections < <(PS2='Select users to assign a new UID' cl-new -mo "${user_vanities[@]}")
for selection in "${selections[@]}"; do
	users_reuid+=("${reverse_lookup["${selection}"]}")
done
mapfile -td '' selections < <(PS2='Select users to reassign groups for' cl-new -mo "${user_vanities[@]}")
for selection in "${selections[@]}"; do
	users_regroup+=("${reverse_lookup["${selection}"]}")
done





#
# Main Logic
#
# Delete users flagged as to be deleted.
# Delete passwords of users flagged to have their password removed.
# Lock users flagged to be locked.
# Prompt to change the shell for users flagged to be reshelled.
# Prompt to change the UID of users flagged to be reUIDed.
# Prompt to change the primary & supplementary groups of users flagged to be regrouped.
for user in "${users_del[@]}"; do
	userdel -rf "${user}"
done
for user in "${users_nullpass[@]}"; do
	passwd "${user}" -d
done
for user in "${users_lock[@]}"; do
	passwd "${user}" -l
done
mapfile -t shells < <(chsh -l)
for user in "${users_reshell[@]}"; do
	unset shell
	shell="$(PS2="Pick the new shell for user \"${user}\"" cl-new "${shells[@]}")"
	usermod -s "${shell}" "${user}"
done
for user in "${users_reuid[@]}"; do
	unset uid
	until
		[[ ${uid} =~ ^[0-9]+$ ]] &&
		! getent passwd "${uid}" /etc/passwd &> /dev/null
	do
		read -erp 'Enter the new UID: ' uid
	done
	usermod -u "${uid}" "${user}"
done
for user in "${users_regroup[@]}"; do
	# Prompt for the new primary and supplementary groups
	unset primary_group selections selection supplementary_groups
	primary_group="${reverse_lookup["$(PS2="Select the new primary group for user \"${user}\"" cl-new -o "${group_vanities[@]}")"]}"
	mapfile -td '' selections < <(PS2="Select new supplementary groups for user \"${user}\"" cl-new -mo "${group_vanities[@]}")
	for selection in "${selections[@]}"; do
		supplementary_groups+=("${reverse_lookup["${selection}"]}")
	done
	supplementary_groups="${supplementary_groups[*]}"
	#
	# Change the groups
	((${#primary_group})) && usermod -g "${primary_group}" "${user}"
	((${#supplementary_groups})) && usermod -G "${supplementary_groups// /,}" "${user}"
done
