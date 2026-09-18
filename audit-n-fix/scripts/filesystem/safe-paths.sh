#!/usr/bin/env bash

log i 'Scanning filesystem for paths which lead with non-alphanumeric characters or contain non-ASCII characters...'
find / -mindepth 1 ! -iregex '^[\x00-\x7F\n]+$' -xephem -print0 >>"${log_dir}/non-ascii-paths.txt" &
find / -mindepth 1 -iregex '^[a-zA-Z0-9_]' -xephem -print0 >>"${log_dir}/non-alphanumeric-leads.txt" &
log i 'Scan started; awaiting results...'
wait
