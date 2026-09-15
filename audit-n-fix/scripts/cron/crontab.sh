#!/usr/bin/env bash





#
# Crontabs
#
# Prompt to review, edit and/or delete the crontab of every user
hash crontab &>/dev/null || exit 10
for u in "${all_users[@]}"; do
	log i "Reviewing crontab of user: \"${u}\"..."
	if crontab -u "${u}" -l &>/dev/null; then
    	pause 3
    	crontab -eu "${u}"
    	crontab -riu "${u}"
	else
		log i "No crontab found for user: \"${u}\". Skipping."
	fi
done
