#!/usr/bin/env bash





#
# Anacron & Cron Jobs
#
# Locate scheduled task files, prompt to review/edit each, then enqueue for removal
mapfile -td '' cron_files < <(find /etc/cron* /var/spool/anacron/cron* /etc/anacrontab -type f -print0)
if [[ "${#cron_files[@]}" -ge 1 ]]; then
	for task in "${cron_files[@]}"; do
		log i "Reviewing scheduled task: \"${task}\"."
		pause 5
		"${EDITOR}" -- "${task}"
		if confirm "Enqueue \"${task}\" for removal"; then
			delete_queue+=("${task}")
			log i "\"${task}\" was queued for removal."
		else
			log i "\"${task}\" was not queued for removal."
		fi
	done
	[[ ${#delete_queue[@]} -ge 1 ]] && if rm -v "${delete_queue[@]}"; then
		log i 'Removed all selected (Ana)Cron jobs.'
	else
		log e 'Something went wrong during the deletion.'
	fi
else
	log w 'No (Ana)Cron jobs were found.'
fi





#
# AtD Jobs
#
if hash atd &>/dev/null; then
	# AtD does not have a standardized directory where it stores Atd jobs, so you have to dig deep into its binary for it
	mapfile -td '' paths < <(strings "$(which atd)" | grep -zoE '/var/spool/.+')
	for path in "${paths[@]}"; do
		# Cycle through the possible candidate AtD jobs directories until 1 sticks
		[[ -d "${path}" && -x "${path}" ]] || continue
		if [[ ! -d "${path}" ]]; then
			log w "Candidate AtD jobs directory \"${path}\" doesn't exist."
			continue
		fi
		#
		# Once a directory sticks, iterate through all the job files in it as necessary.
		log i "Successfully located AtD job directory @ \"${path}\""
		mapfile -td '' jobs < <(find -- "${path}" ! -name '.SEQ' -type f)
		for job in "${jobs[@]}"; do
			log i "Reviewing AtD job \"${job}\"..."
			pause 3
			"${EDITOR}" -- "${job}"
			rm -vi -- "${job}"
		done
	done
else
	log w 'AtD not found in the PATH; skipped AtD checks.'
fi





#
# Crontabs
#
# Prompt to review, edit and/or delete the crontab of every user
if hash crontab &>/dev/null; then
	for u in "${all_users[@]}"; do
		log i "Reviewing crontab of user: \"${u}\"..."
		pause 5
		if crontab -u "${u}" -l &>/dev/null; then
	    	crontab -eu "${u}"
	    	crontab -riu "${u}"
		else
			log i "Skipped empty crontab for user: \"${u}\"."
		fi
	done
else
	log w 'Crontab not found in the PATH; skipped AtD checks.'
fi





#
# SystemD .timers & .paths
#
# Map out the .timers/.paths
if [[ ${init} == 'systemd' ]]; then
	mapfile -t triggers < <(
		systemctl list-units --all --plain --no-legend |
			awk '{ print $1 }' |
			xargs systemctl show -p FragmentPath --value -- |
			grep -E '\.(timer|path)$'
	)
	#
	# Audit them & act accordingly.
	for trigger in "${triggers[@]}"; do
		log i "Reviewing trigger: \"${trigger}\"."
		pause 3
		"${EDITOR}" -- "${trigger}" &&
			confirm "Delete \"${trigger}\"" &&
			systemctl disable --now -- "${trigger}" &&
			rm -v -- "${trigger}"
	done
	unset triggers
	#
	# Pushes changes into SystemD
	systemctl daemon-reload
else
	log w 'Init. system is not SystemD; skipped SystemD timer checks.'
fi
