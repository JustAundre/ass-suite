#!/usr/bin/env bash





#
# Password & Shadow Files
#
# Check for discrepencies between /etc/passwd and /etc/group.
pwck
#
# Migrate stray hashes from passwd to shadow & from group to gshadow
[[ -f /etc/shadow ]] && shadow_old="$(< /etc/shadow)"
[[ -f /etc/gshadow ]] && gshadow_old="$(< /etc/gshadow)"
pwconv
grpconv
#
# Check for differences between the old and new shadow file
if [[ -z "${shadow_old}" ]];
	then log i 'No shadow file prior to pwconv so no discrepencies to note.'
elif diff -u <(echo "${shadow_old}") /etc/shadow; then
	log i 'Nothing changed between the old /etc/shadow file.'
fi
#
# Check for differences between the old and new gshadow file
if [[ -z "${gshadow_old}" ]]; then
	log i 'No gshadow file prior to grpconv so no discrepencies to note.'
elif diff -u <(echo "${gshadow_old}") /etc/gshadow; then
	log i 'Nothing changed between the old /etc/gshadow file.'
fi
