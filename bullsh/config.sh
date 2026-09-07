#!/usr/bin/env bash





#
# Anti-DDoS
#
# Kill extra sessions of the script from the same user
pgrep -f "${0}" -u "${USER}" | grep -v "^$$\$" | xargs kill -9 &> /dev/null





#
# Configuration
#
# Configure hashes used for authentication (SHA-256).
declare -r hashes=(
	249694f401f802a11b17b75b597aaca095eb716385f75322cd570549090d1db45bea25dc91bb602c59228c2b32bd77efe9ac84b7fe798809de577f62fae13ab1
	b04232e51b1e2e37d2690f6a2b8fef8502342eea5983171f98b9c60bb5b1b1f2af6a24ace5b87a9275842b32199135408e9f92dc930cfd5c165dcc7c026d26a7
	108eb11bd9dd27ccd670adb6dacdeb3da42709d0bc68ffdc64031110e4e535b36e9c452c1acaf30a66ce2a3c98396c92de118a08e8f6705ebfe7d35691bf529e
)
#
# General BullSH configurations
declare -Ar config=(
	# JournalCTL log tag
	[log_tag]=bullsh
	#
	# Limitations
	# stdin_cap limits how many characters can be parsed.
	# stdin_cap can parse up to its value + 1 due to the way it is scripted.
	# timeout determines how long a user has to press enter before being forced out.
	# retry_cap determines how many times BullSH will attempt to hash the user's inputs for the password before quitting hashing.
	[stdin_cap]=256
	[timeout]=30
	[retry_cap]=5
	#
	# Extra Flare
	# fake_root determines whether the PS1 variable will display 'root' as the user. Takes a boolean of y/n, T/F, or 1/0.
	# fake_latency determines how much delay there is between each [ENTER].
	[fake_root]=1
	[fake_latency]="0.$((RANDOM % 3 + 1))"
	#
	# Advanced Options
	# hashing_rounds determines for how many rounds will input be hashed
	[hashing_rounds]=2500
)





#
# Safety Nets/Dynamic Variables
#
# TMOUT kills *real* shells after 1 second of inactivity. Acts as a safety net in the event of a command injection vuln.
# Python logic to use for quick hashing
declare -rx TMOUT=1
declare -r python_hashing_logic="import hashlib, sys; h = sys.stdin.read().encode(); exec('for _ in range(${config[hashing_rounds]}):\n    h = hashlib.sha512(h).hexdigest().encode()'); print(h.decode())"
#
# Which layer # start at
# Whether the script stops checking for the password (y/n)
# The amount of login attempts to start with
layer_at=1
stop_hash=0
counts=0
if ((config[fake_root])); then
	declare -x PS1="[root@${HOSTNAME%%.*} ~]# "
else
	declare -x PS1="[${USER}@${HOSTNAME%%.*} ~]$ "
fi
#
# NOT read as:			"if TTY variable = result from TTY command",
# Correctly read as:	"if tty command is successful (whose result happens to be assigned to the TTY var)".
if TTY="$(tty)"; then
	TTY="${TTY#*/*/}"
	SSH_TTY="${TTY}"
else
	TTY="${SSH_TTY}"
fi
declare -rx TTY SSH_TTY
#
# Dynamic handling for SSH_CONNECTION/ip_from
[[ -z ${SSH_CLIENT} ]] && SSH_CLIENT=Local
