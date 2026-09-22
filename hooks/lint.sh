#!/usr/bin/env bash
# shellcheck shell=bash





#
# lint.sh - static checks for shell scripts in this repository
#
# Usage:
#   hooks/lint.sh              check all tracked shell scripts
#   hooks/lint.sh --staged     check only files staged for commit
#   hooks/lint.sh --fix        auto-fix trailing whitespace and missing EOF newlines
#   hooks/lint.sh --strict     treat shellcheck findings as failures
#
# Failures (always block):       bash syntax errors, whitespace issues
# Advisories (block only with --strict): shellcheck findings
#
# Exit codes:
#   0  checks passed
#   1  a failure was found
#   2  usage error

set -u

MODE="all"
STRICT=0
FIX=0

files=()
failures=0
findings=0

for arg in "${@}"; do
	case "$arg" in
		--staged) MODE='staged' ;;
		--strict) STRICT=1 ;;
		--fix) FIX=1 ;;
		-h|--help)
			sed -n '2,20p' "${0}"
			exit 0
			;;
		*)
			printf 'E: Unknown option: %s\n' "${arg}" >&2
			exit 2
			;;
	esac
done

is_bash_file() {
	case "${1}" in
		*.sh|*.bash|*.rc) return 0 ;;
	esac
	head -n1 "${1}" 2>/dev/null | grep -qE '^#!.*\bbash\b'
}

if [[ "${MODE}" == "staged" ]]; then
	mapfile -t candidates < <(git diff --cached --name-only --diff-filter=ACM)
else
	mapfile -t candidates < <(git ls-files)
fi

for file in "${candidates[@]}"; do
	[[ -f "${file}" ]] || continue
	is_bash_file "${file}" && files+=("${file}")
done


for file in "${files[@]}"; do
	if ! bash -n "${file}"; then
		printf 'E: Bash interpretation/syntax error in "%s".\n' "${file}"
		((failures++))
	fi
done

tmp="$(mktemp)"
trap 'rm -rf "${tmp}"' EXIT
for file in "${files[@]}"; do
	grep -Pz '(?<!(?<!\n)\n{6})#\n# \w+\n#\n' "${file}"
	flags="$(grep -Pzc '(?<!(?<!\n)\n{6})#\n# \w+\n#\n' "${file}")"
	if [[ ${flags} -gt 0 ]] && (( FIX )); then
		mkdir -p "$(dirname "${tmp}/${file}")"
		cp -p "${file}" "${tmp}/${file}"
		perl -0777 -pi -e 's/\n*#\n# (.+)\n#\n/\n\n\n\n\n\n#\n# $1\n#\n/g' "${file}"
		diff -d "${tmp}/${file}" "${file}"
		exit_status="$?"
		[[ "${exit_status}" -eq 1 ]] &&
			printf 'i: Fixed %s instances of improperly spaced headers in "%s".' "${flags}" "${file}"
	elif [[ ${flags} -gt 0 ]]; then
		((failures += flags))
		printf 'E: Found %s instances of improperly spaced headers in "%s".' "${flags}" "${file}"
	fi
done

for file in "${files[@]}"; do
	if matches="$(grep -nE '[[:blank:]]+$' "${file}")"; then
		if (( FIX )); then
			sed -i 's/[[:blank:]]\+$//' "${file}"
			git add -- "${file}"
			printf 'i: Fixed trailing whitespace in "%s".\n' "${file}"
		else
			printf 'E: Found trailing whitespace in "%s".\n' "${file}"
			printf '%s\n' "$matches" | sed 's/^/    /'
			((failures++))
		fi
	fi
	if [[ -s "${file}" && -n "$(tail -c 1 "${file}")" ]]; then
		if (( FIX )); then
			printf '\n' >>"${file}"
			git add -- "${file}"
			printf 'i: Fixed missing newline at EOF of "%s".\n' "${file}"
		else
			printf 'E: Found missing newline at EOF of "%s".\n' "${file}"
			((failures++))
		fi
	fi
done

if command -v shellcheck &>/dev/null; then
	for file in "${files[@]}"; do
		if ! shellcheck "${file}"; then
			if (( STRICT )); then
				printf 'W: shellcheck: %s\n' "${file}"
				((failures++))
			else
				printf 'W: shellcheck findings in: %s (run hooks/lint.sh --strict to enforce)\n' "${file}"
				((findings++))
			fi
		fi
	done
else
	printf 'E: shellcheck not installed; skipped lint.\n'
fi

printf '\n'
if [[ ${#files[@]} -eq 0 ]]; then
	printf 'i: No shell scripts to check.\n'
elif (( findings > 0 )); then
	printf 'i: %d file(s) checked, %d advisory finding(s).\n' "${#files[@]}" "${findings}"
elif (( failures > 0 )); then
	printf 'E: %d failure(s) found; aborting...\n' "${failures}"
	exit 1
else
	printf 'OK: %d file(s) checked, 0 advisories or critical errors.\n' "${#files[@]}"
fi
exit 0
