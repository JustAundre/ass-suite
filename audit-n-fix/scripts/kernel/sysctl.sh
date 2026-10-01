#!/usr/bin/env bash

# Save parameters before execution
before="$(sysctl -a)"
#
# Iterate over each category
mkdir -pv /etc/sysctl.d
for category in ./cnf/sysctl/*; do
	# Enumerate options for each category
	for conf in ./cnf/sysctl/"${category}"/*.conf; do
		choices+=("${conf%'.conf'}")
	done
	#
	# Query for which options to enforce and enforce selected options
	mapfile -td '' selections < <(PS2="Select ${category} hardening sysctl parameters" cl-new -mo "${choices[@]}")
	for selection in "${selections[@]}"; do
		hyphenated="${selection// /-}" install -m 600 -o 0 -g 0 -v "./cnf/sysctl/${category}/${selection}.conf" "/etc/sysctl.d/99-zz-${hyphenated@L}.conf"
	done
done
#
# Apply changes
sysctl --system > /dev/null
#
# Save parameters post-execution
after="$(sysctl -a)"
#
# Compare pre/post execution results
diff -q <(printf '%s' "${before}") <(printf '%s' "${after}")
