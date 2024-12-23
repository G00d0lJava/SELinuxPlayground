#!/bin/bash

# Check whether seinfo is installed
if ! rpm -q setools-console > /dev/null || ! which seinfo > /dev/null ; then
	echo "Error: Package setools-console not installed or command seinfo not found. Install the package via 'dnf install setools-console' or check path variable." >&2
	exit 1
fi
echo 'rpm has run'
# SELinux type this script needs to work
SE_TYPE='selinux_tester_t'

# Check whether type exists
if seinfo -t "$SE_TYPE" | grep 'Types: 0' > /dev/null ; then
	echo "Error: Type $SE_TYPE does not exist. Make sure the correct policy is loaded." >&2
	exit 1
fi
echo 'seinfo has run'
# Get own entry from ps
PS_ENTRY="$( ps -eZ | grep -E "$$.*(${0##*/}|bash)"  )"
echo 'ps has run'
#echo "$PS_ENTRY"
#echo "$$"
#echo "${0#./}"
#echo "$( ps -eZ )"
if [ -z "$PS_ENTRY" ]; then
	echo "Error: could not find own entry in process list" >&2
	exit 1
fi

# Pattern for names of SELinux users, roles and types. Without suffix
NAME_PATTERN='[[:graph:]]+?'
# Pattern for level part of a context
LEVEL_PATTERN='s[[:digit:]]+(:c[[:digit:]]+(.c[[:digit:]]+)?)?'
# Get context
# \<[[:graph:]]+?_u:[[:graph:]]+?_r:[[:graph:]]+?_t:s[[:digit:]]+(:c[[:digit:]]+(.c[[:digit:]]+)?)?(-s[[:digit:]]+(:c[[:digit:]]+(.c[[:digit:]]+)?)?)?\>
CONTEXT="$( echo "$PS_ENTRY" | grep -Eo "\\<${NAME_PATTERN}_u:${NAME_PATTERN}_r:${NAME_PATTERN}_t:$LEVEL_PATTERN(-$LEVEL_PATTERN)?\\>" )"

if [ -z "$CONTEXT" ]; then
	echo "Error: Could not find own SELinux context" >&2
	exit 1
fi

# For debugging
echo "ps entry: $PS_ENTRY"
echo "Context: '$CONTEXT'"
echo "Needed type: '$SE_TYPE'"

# Change own domain if domain is not correct
if ! [[ "$CONTEXT" =~ .*$SE_TYPE.* ]]; then
	# Exit with error if domain change has already been tried
	for arg in "$@"; do
		if [ "$arg" = "--exec" ]; then
			CURRENT_DOMAIN="${CONTEXT%_t*}_t"
			CURRENT_DOMAIN="${CURRENT_DOMAIN##*:}"
			echo "Could not obtain correct domain. Current domain is ${CURRENT_DOMAIN}. Should be $SE_TYPE. Make sure policy is loaded." >&2
			exit 1
		fi
	done
	# Get path to own executable
	OWN_PATH="$( dirname "$( realpath $0  )"  )/${0##*/}"
	# Get permissions of executable file
	OWN_PERM="$( stat -c '%a' "$OWN_PATH"  )"
	# Execute own file or fail if not executable for others
	EXECUTE_STATUS="${OWN_PERM:2:1}"
	if [ "$(( "$EXECUTE_STATUS" % 2  ))" -eq 1 ]; then
		# Transition to new domain.
		exec $OWN_PATH "$@" "--exec"
		exit 0
	else
		echo "Error: File is not executable"
	fi
# If domain is correct list files is /var/log/
else
	ls -l /var/log/
	exit 0
fi
exit 0
