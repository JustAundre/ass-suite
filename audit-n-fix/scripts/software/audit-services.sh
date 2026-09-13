#!/usr/bin/env bash





#
# Service Audit
#
# Enumerate services and prompt a checklist for which to remove.
mapfile -t services < <(TERM=dumb systemctl list-unit-files --type=service --no-legend --plain | awk '{ print $1 }')
mapfile -td '' flagged_services < <(PS2='Select services to REMOVE' cl-new -m "${services[@]}")
#
# Remove selected services
for flagged_service in "${flagged_services[@]}"; do
	# Attempt to remove package behind service
	if ! apt-get remove --purge -y "$(dpkg -S "/etc/systemd/system/${flagged_service}.service" | cut -d: -f1)"; then
		# Fallback to just disabling & masking the service.
		systemctl disable --now "${flagged_service}"
		systemctl mask "${flagged_service}"
	fi
done
#
# Reload SystemD
systemctl daemon-reload
