#!/usr/bin/env bash





#
# Inactive Module Management
#
# Block all currently inactive modules from ever loading.
if [[ ! -d /lib/modules/$(uname -r) ]]; then
	log e 'The kernel modules for your active kernel no longer exist on the disk.' 'Please restart your machine.'
	exit 10
fi
#
# Subtract list of active modules from list of all modules to get list of inactive modules.
mapfile -td '' mods  < <(sort < <(
	find "/lib/modules/$(uname -r)" -type f -name '*.ko*' -printf '%f\n' | cut -d '.' -f1
	grep -oE '^\w+' /proc/modules | sed 's/_/-/g'
) | uniq -u)
confirm 'Prevent currently unused kernel modules from ever being loaded' && for mod in "${mods[@]}"; do
	echo "install ${mod} /bin/false" >>/etc/modprobe.d/hardening.conf
done
log i 'The new blacklist can be found at "/etc/modprobe.d/hardening.conf".'
