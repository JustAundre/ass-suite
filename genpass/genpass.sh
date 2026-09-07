#!/usr/bin/env bash
#
# Environment Setup
#
# Source library commands
[[ -d "../lib/" ]] || exit 69
for function in "$../lib/"*; do
	. "${function}"
done
#
# Filename/path of dictionary file & URL to fallback dictionary.
mapfile -td '' dict_locations < <(find /usr/share/dict -type f,l -readable -print0)
dict_location="${dict_locations[0]}"
dict_url='https://www.mit.edu/~ecprice/wordlist.10000'
#
# Create a new terminal output stream; "${ui}" will be used for UI-element outputs.
exec {ui}>&2
#
# Helper function to pull a random word
word_pull() {
	# Pull a word within length constraints
	local word kill
	while [[
		${#word} -lt ${min} ||
		${#word} -gt ${max}
	]]; do
		# Verbose output: print scrapped words
		[[ -n ${verbose} && -n ${word} ]] &&
			log w "Dropped word \"${word}\" because it did not meet complexity requirements."
		#
		# Error out if failed to find a word matching set constraints for more than 250 cycles
		if [[ ${kill} -gt 250 ]]; then
			log e 'E: Script took too long to find a word within constraints, stopping to avoid system stress...'
			return 4
		fi
		#
		# Shuffle the dictionary, pull 1 word...
		# ...& increase cycle count
		word="$(shuf -n1 "${dict_location}")"
		if [[ -z ${word} ]]; then
			log e 'Failed to fetch word from the dictionary.'
			return 2
		fi
		((kill++))
	done
	#
	# Capitalize beginning of word as needed, then print result.
	[[ ${capitals} =~ ^[yY]$ ]] && printf '%s' "${word^}" || printf '%s' "${word}"
}
#
# Parse CLI arguments
while getopts 's:m:M:c:a:p:v' arg; do
	case "${arg}" in
	s) separator="${OPTARG}" ;;
	m) min="${OPTARG}" ;;
	M) max="${OPTARG}" ;;
	c) capitals="${OPTARG}" ;;
	a) password_amount="${OPTARG}" ;;
	p) pattern="${OPTARG}" ;;
	v) verbose=y ;;
	*)
		log e "Invalid argument \"${arg}\""
		exit 2
		;;
	esac
done





#
# Generation Tuning
#
# Separator
# Minimum word length
# Maximum word length
# Whether to capitalize the first character of words
# How many passwords to generate
# Generation pattern
[[ -z ${separator} && -t 0 ]] && read -erp 'Enter a separator (Default is -): ' separator >&"${ui}"
[[ -z ${min} && -t 0 ]] && read -erp 'Minimum word length (Default is 4): ' min >&"${ui}"
[[ -z ${max} && -t 0 ]] && read -erp 'Max word length (Default is 8): ' max >&"${ui}"
[[ -z ${capitals} && -t 0 ]] && read -erp 'Capitalize first letters? [Y/n]: ' capitals >&"${ui}"
[[ -z ${password_amount} && -t 0 ]] && read -erp 'Amount of passwords (Default is 1): ' password_amount >&"${ui}"
if [[
	-z ${pattern} &&
	-t 0
]]; then
	cat >&"${ui}" <<- 'EOF'
		w = Random word
		n = Random number
		s = Provided separator
	EOF
	read -erp 'Enter your generation pattern (Default is "wnswnswn"): ' pattern >&"${ui}"
fi





#
# Input Validation
#
# Ensures the separator is not empty (defaults to hyphen)
if [[ -z ${separator} ]]; then
	log w 'No separator given; defaulting to a hyphen "-"'
	separator=-
fi
#
# Ensures the minimum length is a number (defaults to 4)
if [[ ! ${min} =~ ^[0-9]+$ ]]; then
	log w 'Invalid/missing minimum length; defaulting to "4".'
	min=4
fi
#
# Ensures the maximum length is a number (defaults to 8)
if [[ ! ${max} =~ ^[0-9]+$ ]]; then
	log w 'Invalid/missing maximum length; defaulting to "8".'
	max=8
fi
#
# Ensures the minimum is not greater than the maximum
if [[ ${min} -gt ${max} ]]; then
	log w <<- EOF
		Minimum (${min}) is greater than maximum (${max}) is an unfufilable condition;
		    Swapping the values of min/max from ${min}/${max} to ${max}/${min} to fix contradiction & proceeding...
	EOF
	read max min <<< "${min} ${max}"
fi
#
# Ensures the response to capitals is a yes/no
capitals="${capitals:0:1}"
if [[ ! ${capitals} =~ ^[yYnN]$ ]]; then
	log w 'Invalid/missing response; defaulting to [y]es.'
	capitals=y
fi
#
# Ensures the pattern exists
if [[ -z ${pattern} ]]; then
	log w 'Invalid/missing response; defaulting to wnswnswn.'
	pattern=wnswnswn
fi
#
# Ensures the password count is at least 1
if [[ ${password_amount} -lt 1 ]]; then
	log w 'Invalid/missing response; defaulting to 1.'
	password_amount=1
fi





#
# Password generation
#
# If no dictionary is present...
if [[
	! -f ${dict_location} &&
	! -f en_US-dict.txt
]]; then
	# Attempt to download one (with consent)...
	echo "W: A pre-existing dictionary couldn't be located in \"${dict_location}\"."
	dict_location='en_US-dict.txt'
	#
	# if there's a terminal.
	if [[ -t 0 ]]; then
		read -erp "Download a dictionary from '${dict_url}' to '$(pwd)/${dict_location}? (aprox. ~76kb of characters, 10k words) [y/N]: '" download >&2
	else
		log e <<- 'EOF'
			As this is non-interactive,
			    a prompt won't be shown for downloading an external dictionary,
			    the dictionary won't be downloaded & the script will now close.
		EOF
		exit 3
	fi
	#
	# Start the download (if consented)
	if [[ ${download} =~ ^[yY] ]]; then
		echo 'i: Downloading...' >&2
		#
		# Will timeout if download takes too long.
		if ! curl -s "${dict_url}" --connect-timeout 5 > "${dict_location}"; then
			# Alert user of the error
			log e <<- EOF
				Failed to download dictionary; the curl command exited with code "$?".
				    deleting possible remnant file(s) & quitting...
			EOF
			#
			# Remove remnant empty file
			[[ -f ${dict_location} ]] &&
				rm -v "${dict_location}"
			exit 1
		fi
	fi
fi
#
# Generate password(s)
echo 'Generated password(s):' >&2
for ((x = 0; x < password_amount; x++)); do
	unset result
	for ((y = 0; y < ${#pattern}; y++)); do
		char="${pattern:y:1}"
		case "${char}" in
			w | W)
				# Parse w/W into a random word
				word="$(word_pull)" || exit "$?"
				result+="${word}"
				;;
			n | N)
				# Parse n/N into a random number [0-9]
				result+="$((RANDOM % 10))"
				;;
			s | S)
				# Parse s/S into the given separator
				result+="${separator}"
				;;
			*)
				# More input validation
				log w "Unrecognized character \"${char}\" in pattern at line 1, column ${y}. Ignoring..."
				;;
		esac
	done
	#
	# Return password
	echo "${result}"
done
