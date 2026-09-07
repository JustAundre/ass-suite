#!/usr/bin/env bash





#
# AtD Jobs
#
if ! hash atd &>/dev/null; then
	log e 'The AtD program is not installed, there is nothing to do.'
	exit 10
fi
#
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
