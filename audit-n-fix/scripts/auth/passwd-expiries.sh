#!/usr/bin/env bash





#
# Enforce Password Expiries
#
for user in "${int_users[@]}"; do
	# Skips the iterated user if they're the user running the script
	# Apply the password age restrictions to the user
	# Sets the date they last changed their password to current date to avoid accidental lockouts
	[[ "${u}" == "${SUDO_USER}" ]] && continue
	timestamp="$(date +%Y-%m-%d)"
	chage -m 7 -M 90 -W 14 "${user}" &&
		log i "Set minimum password reset delay to 1 week, mandatory reset to 90 days, and warning at 2 weeks for user: \"${u}\"."
	chage -d "${timestamp}" "${user}" &&
		log i "Changed password age for user \"${user}\" to ${timestamp}"
done
