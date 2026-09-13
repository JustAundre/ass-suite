#!/usr/bin/env bash
#
# Environment Setup
#
# Create and echo the random file path for the decompilation directory
if ! decompilation_dir="$(mktemp -d /tmp/decompilation-XXXXXX)"; then
	printf 'E: Failed to create temporary data directory for decompilation of data @ "%s".' "$(date)"
	exit 1
fi
printf 'Path of temporary decompilation data: %s' "${decompilation_dir}"
#
# Set auto-cleanup on exit.
trap 'rm -rf "${decompilation_dir}"' EXIT





#
# Pattern Check
#
pattern_chk() {
	local link_name="${1}" readable_name="${2}" args=()
	local -n link="${1}" || return 1
	shift 2
	for arg in "${@}"; do
		args+=(-e "${arg}")
	done
	mapfile -t "${link_name}" < <(rg -i "${args[@]}" --trim | sort -u)
	echo "JAR references ${readable_name} ${#link[@]} times."
	[[ ${#link[@]} -gt 0 ]] && printf '%s\n' "${link[@]}"
	echo
}





#
# Scoring Engine
#
# Scoring engine which utilizes counts of different flagged categories to dynamically score.
# This scoring engine is probably longer than the evaluation of patterns.
calc_score() {
	local i='' capped='' counter=0 numerator="${1}" denominator="${2}" base_add="${3}" quad_mod="${4}" min="${5}" max="${6}" readable_name="${7}" link_name="${8}"
	local -n link="${8}" || return 1
	#
	# Loop over ... as many times as the amount of items inside the array the nameref "flagged" resolves to.
	for ((
		i = 0;
		i < "${#link[@]}";
		i++
	)); do
		# For every "numerator" in "denominator" instances of "flagged" starting from 1, quadratically increase the score by "quad_mod"
		# Bash doesn't really have fractions so this is the closest we're getting without the bc command.
		if ((i % denominator < numerator)); then
			((counter += base_add))
			((base_add += quad_mod))
		fi
		#
		# Enforce the bounds
		if ((counter > max)); then
			# Send score breakdown with notice of score being rounded down
			capped=true
			printf 'Points from %s: %s/%s (rounded down from %s)\n' "${readable_name}" "${max}" "${max}" "${counter}"
			counter="${max}"
			break
		fi
		if (("${#link[@]}" > 0 && quad_mod < 0 && counter < min)); then
			# Ditto but rounded up
			capped=true
			printf 'Points from %s: %s/%s (rounded up from %s)\n' "${readable_name}" "${min}" "${max}" "${counter}"
			counter="${min}"
			break
		fi
	done
	#
	# If scoring wasn't pruned (and as a result, a breakdown was already sent), then don't send another.
	[[ -z ${capped} ]] && printf 'Points from %s: %s/%s\n' "${readable_name}" "${counter}" "${max}"
	#
	# Assign score to its own index inside an associative array.
	score["${link_name}"]="${counter}/${max}"
}
combine_scores() {
	local val total total_max message="${1}"
	shift 1
	for key in "${@}"; do
		val="${score["${key}"]:-0/0}"
		local total="$((total + ${val%%/*}))" total_max="$((total_max + ${val##*/}))"
	done
	printf '%s: %s/%s\n' "${message}" "${total}" "${total_max}"
}





#
# Decompilation
#
# Enumerate all JAR files in passed path (if passed path was passed and exists, else CWD).
if [[ -n ${1} && -e ${1} ]]; then
	mapfile -td '' jars < <(find "${1}" -type f -name '*.jar' -print0)
elif [[ -n ${1} ]]; then
	echo 'W: Provided path does not exist; falling back to CWD.'
else
	mapfile -td '' jars < <(find . -type f -name '*.jar' -print0)
fi
#
# Exit if no JARs were found
if [[ ${#jars[@]} -eq 0 ]]; then
	echo 'E: No files ending in ".jar" were found.' >&2
	exit 2
fi
#
# Enqueue all JARs for simultanious decompilation.
for jar in "${jars[@]}"; do
	printf '%s: Decompiling "%s"...\n' "$(date)" "$(pwd)/${jar}"
	cfr "${jar}" --outputdir "${decompilation_dir}/$(basename "${jar}" .jar)" --silent true &
done
echo 'i: Awaiting decompilation of JARs to finish...'
wait
echo 'i: Decompilation of JARs has finished!'





#
# Evaluation
#
for jar in "${jars[@]}"; do (
	printf 'Analyzing "%s" @ "%s"...\n\n' "$(pwd)/${jar}" "$(date)"
	declare -A score sum
	#
	# Move into provided directory for scanning
	cd "${decompilation_dir}/$(basename "${jar}" .jar)" || exit 4
	#
	# Start the scan
	pattern_chk 'oshi' 'operating system & hardware identifiers' '\bjava\.time\.ZoneId\b' '\boshi\.\w+' '\bSystem\.getProperty\(' '\bgpu\.get\w+\(\)'
	pattern_chk 'misc_id' 'miscellaneous identifiers' '\bFabricLoader\.getInstance\(\)\.options\b' '\bFabricLoader\.getInstance\(\)\.get\w+\('
	pattern_chk 'uncommon_fsi' 'uncommon filesystem interactions' '\b(FileUtils\.)?list\(' '\bparallelStream\('
	pattern_chk 'concerning_fsi' 'concerning filesystem interactions' '\b(vbox|virtualbox|vmware|qemu)\b' '\b(wmic|sc query)\b' 'file\.attribute' 'setAttribute' '\.getFileSystem\(' 'FileAttributes' 'FilePermissions'
	pattern_chk 'common_moia' 'common methods of internet access' '\bjava\.net\.(http|URL)\b' '\bjava\.io\.InputStreamReader\b'
	pattern_chk 'uncommon_moia' 'uncommon methods of internet access' '\borg\.apache\.http\b' '\bokhttp3\b' '\bretrofit2\b' '\bUnirest\b' '\bJsoup\b'
	pattern_chk 'concerning_moia' 'concerning methods of internet access' '\bjava\.net\.(Socket|ServerSocket|DatagramPacket)\b' '\bjava\.nio\.channels\.(SocketChannel|AsynchronousSocketChannel)\b'
	pattern_chk 'common_moo' 'common methods of obfuscation' 'new String\(' 'base[0-9]{1,3}\.decode' '\bCipher\.getInstance\(' '\bHexFormat\.of' '\bDatatypeConverter\.parseHexBinary\b' '\bCharacter\.toString\('
	pattern_chk 'common_mor' 'common methods of reflection' '\bClass\.forName\('
	pattern_chk 'concerning_mor' 'concerning methods of reflection' '\.getDeclaredMethod\(' '\bMethod\.invoke\(' '\bdefineClass\(' '\bSecureClassLoader\b' '\bClassLoader\b' '\bMethodHandles\b' '\bUnsafe\b' '\bsun\.misc\.Unsafe\b'
	pattern_chk 'rce' 'remote code execution' '\bRuntime\.getRuntime\(\)\.exec' '\b(ProcessBuilder|ScriptEngineManager|Nashorn)\b' '\bURLClassLoader\b'
	pattern_chk 'jni' 'native code execution' '\bSystem\.load(Library)?\(' '\.(dll|so|dylib)\b'
	pattern_chk 'concerning_di' 'concerning data interactions' '\b((Login|Web) Data|Local State|Cookies|Network\\Cookies|Mozilla|Chrome|Edge|Brave|Firefox|Opera)\b' '\b(createScreenCapture|Toolkit\.getDefaultToolkit|java\.awt\.Robot)\b' '\b(DataFlavor|Clipboard)\b' 'webhook'
	#
	# Scoring of sub-categories
	calc_score 1 2 5 1 0 85 'OSHI' 'oshi'
	calc_score 1 3 3 1 0 65 'Misc. IDs' 'misc_id'
	calc_score 1 1 75 -50 20 100 'Remote Code Executions' 'rce'
	calc_score 1 1 60 -15 20 150 'Native Code Executions' 'jni'
	calc_score 1 4 5 1 0 100 'common methods of obfuscation' 'common_moo'
	calc_score 1 4 5 1 0 100 'common methods of reflection' 'common_mor'
	calc_score 1 1 40 -5 0 100 'concerning methods of reflection' 'concerning_mor'
	calc_score 1 1 25 -3 30 80 'uncommon filesystem interactions' 'uncommon_fsi'
	calc_score 1 1 35 -4 40 80 'concerning filesystem interactions' 'concerning_fsi'
	calc_score 1 1 25 -3 30 80 'uncommon methods of internet access' 'uncommon_moia'
	calc_score 1 1 35 -4 45 80 'concerning methods of internet access' 'concerning_moia'
	calc_score 1 1 35 -4 40 80 'concerning data interactions' 'concerning_di'
	#
	# Score combinations for the 3 pillars
	combine_scores 'Visible potential invasiveness' oshi misc_id uncommon_fsi concerning_fsi concerning_di
	combine_scores 'Visible potential for destruction' rce jni uncommon_fsi concerning_fsi uncommon_moia concerning_moia
	combine_scores 'Likelihood of intent masking' common_mor concerning_mor common_moo
	printf '\n\n\n\n\n'
) > >(tee "$(mktemp mc-sast-"$(basename "${jar}" .jar)"-XXXXX.txt)"); done
