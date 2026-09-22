#!/usr/bin/env bash





#
# Modify/Verify
#
# Edit/validify slices
(while
	systemd-analyze verify cnf/rsc-caps/slice-individual.slice 2>&1 | grep invalid ||
	systemd-analyze verify cnf/rsc-caps/slice-shared.slice 2>&1 | grep invalid
do
	if ((! ran)); then
		ran=1
	else
		log w 'SystemD found issue(s) with your configuration.'
		log i $'After you resume, you\'ll be made to revise your configurations again.'
		pause
	fi
	"${EDITOR}" cnf/rsc-caps/slice-individual.slice cnf/rsc-caps/slice-shared.slice cnf/rsc-caps/limits.conf
done)





#
# Install
#
install -m 640 -o 0 -g 0 -Dv cnf/rsc-caps/slice-individual.slice /etc/systemd/system/user.slice.d/override.conf
install -m 640 -o 0 -g 0 -Dv cnf/rsc-caps/slice-shared.slice /etc/systemd/system/user-.slice.d/override.conf
#
# Reload SystemD
systemctl daemon-reload
