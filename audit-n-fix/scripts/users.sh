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
for u in "${all_users[@]}"; do
	user_vanities+=("$(id "${u}") sh=$(grep -E "^${u}:" /etc/passwd | cut -d ':' -f 7)")
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
for id in "${user_vanities[@]}"; do
	u="${all_users["${reverse_lookup["${id}"]}"]}"
	grep -qE "^${u}:"'\$' /etc/shadow || password_users+=("${id}")
done
mapfile -td '' selections < <(PS2='Select users to remove passwords from' cl-new -mo "${password_users[@]}")
for selection in "${selections[@]}"; do
	users_nullpass+=("${reverse_lookup["${selection}"]}")
done
for id in "${user_vanities[@]}"; do
	u="${all_users["${reverse_lookup["${id}"]}"]}"
	grep -qE "^${u}:"'!' /etc/shadow || locked_users+=("${id}")
done
mapfile -td '' selections < <(PS2='Select users to lock' cl-new -mo "${locked_users[@]}")
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
for u in "${users_del[@]}"; do
	userdel -rf "${u}"
done
for u in "${users_nullpass[@]}"; do
	passwd "${u}" -d
done
for u in "${users_lock[@]}"; do
	passwd "${u}" -l
done
mapfile -t shells < <(chsh -l)
for u in "${users_reshell[@]}"; do
	shell="$(PS2="Pick the new shell for user \"${u}\"" cl-new "${shells[@]}")"
	usermod -s "${shell}" "${u}"
done
for u in "${users_reuid[@]}"; do
	unset uid
	until
		[[ ${uid} =~ ^[0-9]+$ ]] &&
		! getent passwd "${uid}" /etc/passwd &> /dev/null
	do
		read -erp 'Enter the new UID: ' uid
	done
	usermod -u "${uid}" "${u}"
done
for u in "${users_regroup[@]}"; do
	# Prompt for the new primary and supplementary groups
	primary_group="${reverse_lookup["$(PS2="Select the new primary group for user \"${u}\"" cl-new -o "${group_vanities[@]}")"]}"
	mapfile -td '' selections < <(PS2="Select new supplementary groups for user \"${u}\"" cl-new -mo "${group_vanities[@]}")
	for selection in "${selections[@]}"; do
		supplementary_groups+=("${reverse_lookup["${selection}"]}")
	done
	supplementary_groups="${supplementary_groups[*]}"
	#
	# Change the groups
	((${#primary_group})) && usermod -g "${primary_group}" "${u}"
	((${#supplementary_groups})) && usermod -G "${supplementary_groups// /,}" "${u}"
done
