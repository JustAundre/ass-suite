#!/usr/bin/env bash





#
# Repository URL Checks
#
# Loop over all repository files
mapfile -td '' repo_files < <(find /etc/yum.repos.d/ /etc/apt/sources.list.d/ /etc/apt/sources.list -mindepth 1 ! -type d -print0)
for repo_file in "${repo_files[@]}"; do
	# Loop over every line URL in the repositories file
	mapfile -td '' urls < <(grep -oE 'https?://[^/ ]+' "${repo_file}" | sort -z | uniq -zu)
	for url in "${urls[@]}"; do
		# Compare the domains of the newly found URL with the URL from the /etc/os-release file.
		# If the domains match, log it; otherwise, flag it.
		[[ -n "${url}" ]] && if compdom "${os_info[HOME_URL]}" "${url}"; then
			log i "URL \"${url}\" was identified."
		else
			log w "URL with foreign domain \"${url}\" found in file \"${repo_file}\"."
		fi
	done
done
