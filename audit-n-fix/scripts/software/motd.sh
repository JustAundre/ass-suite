#!/usr/bin/env bash





#
# Install MOTDs
#
# MOTD locations
motds=(
	/etc/issue
	/etc/issue.net
	/etc/motd
)
#
# Install the original to the first path specified.
# (Most common MOTD location)
log i "You'll be put into a text editor to revise a MOTD file template as needed." "Once you're done, it'll be installed to the following files:"
printf "%s\n" "${motds[@]}"
pause
install -m 640 -o 0 -g 0 -D cnf/motd "${motds[0]}"
#
# Hardlink to other likely MOTD file locations
for path in "${motds[@]:1}"; do
	link -- "${motds[0]}" "${path}"
done





#
# Delete Unecessary MOTDs
#
rm -rfv /etc/update-motd.d/
