#!/usr/bin/env bash





#
# Environment Setup
#
# Prompt for users to ...
# Delete, remove password, lock, reshell, reUID & regroup.
mapfile -td '' users_del < <(PS2='Select users to delete' cl-new -m "${all_users[@]}")
mapfile -td '' users_nullpass < <(PS2='Select users to remove passwords from' cl-new -m "${all_users[@]}")
mapfile -td '' users_lock < <(PS2='Select users to lock' cl-new -m "${all_users[@]}")
mapfile -td '' users_reshell < <(PS2='Select users to select a new shell for' cl-new -m "${all_users[@]}")
mapfile -td '' users_reuid < <(PS2='Select users to assign a new UID' cl-new -m "${all_users[@]}")
mapfile -td '' users_regroup < <(PS2='Select users to reassign groups for' cl-new -m "${all_users[@]}")





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
	userdel -rf "${u}" && log i "Successfully deleted user \"${u}\"."
done
for u in "${users_nullpass[@]}"; do
	passwd "${u}" -d && log i "Successfully unset password for user \"${u}\"."
done
for u in "${users_lock[@]}"; do
	passwd "${u}" -l && log i "Successfully locked user \"${u}\"."
done
for u in "${users_reshell[@]}"; do
	while [[ ! -x ${shell} ]]; do
		read -erp 'Enter the path to the new shell: ' shell
	done
	usermod -s "${shell}" "${u}" && log i "Successfully changed shell for user \"${u}\"."
	unset shell
done
for u in "${users_reuid[@]}"; do
	while
		[[ ! ${uid} =~ ^[0-9]+$ ]] ||
			getent passwd "${uid}" /etc/passwd &> /dev/null
	do
		read -erp 'Enter the new UID: ' uid
	done
	usermod -u "${uid}" "${u}" && log i "Successfully changed UID of \"${u}\" to ${uid}."
	unset uid
done
for u in "${users_regroup[@]}"; do
	# Prompt for the new primary group
	while
		[[ -z ${primary_group} ]] ||
			grep -qE "^[^:]+:[^:]+:${primary_group}" /etc/group &> /dev/null
	do
		read -erp 'Enter new primary group: ' primary_group
	done
	#
	# Prompt for the new supplementary groups
	until ((stop)); do
		read -erp 'Enter new supplemental groups (space-separated): ' -a supplemental_groups
		for group in "${supplemental_groups[@]}"; do
			grep -qE "^${group}:" /etc/group || stop=1
		done
	done
	#
	# Change the groups
	usermod -g "${primary_group}" "${u}" && log i "Successfully changed primary group for user \"${u}\" to \"${primary_group}\"."
	usermod -G "${supplemental_groups[*]// /,}" "${u}" && log i "Successfully changed supplementary groups for user \"${u}\" to \"${supplemental_groups[*]// /,}\"."
	unset primary_group supplemental_groups
done
#
# Secures root user
# (L)ocks user (root) & (d)eletes their password
confirm "Lock & remove password for UID 0 user \"$(id -nu 0)\"" && passwd root -ld
