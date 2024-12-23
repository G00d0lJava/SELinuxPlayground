#!/bin/bash

# NAME
# checksepolicy.sh
# DESCRIPTION
# Outputs SELinux types for which specific allow rules have been defined and to which a specific type can transition.
# The general use case of this program is the following.
# Given an SELinux role for which a type with the same base name exists (like user_r and user_t), the program will check for every type defined for the role whether a process transition from the
# type with a base name to the type is possible. If a transition is possible the program will check whether there are rules giving the type to which a transition is possible
# access to one or more of the specified permissions on objects of the specified class and the given target type.
# Only the types with matching transition and allow rules are listed in the output.
# If the --sudo option is specified only types with rules allowing dac_override or dac_read_search permissions are listed.
# SYNTAX
# bash checksepolicy.sh --default-name=<DEFAULT_NAME> --target-type=<TARGET_TYPE> --object-class=<OBJECT_CLASS> --permission-list=<PERMISSION_LIST> [--sudo] [--debug]
# OPTIONS
# Only the options in brackets are optional, all other options must be specified.
# Options can be specified in any order.
# Values in pointy brackets ('<' and '>') are to be replaced by the actual values.
# Do not write any of the brackets in your input.
#
# --default-name=
# Generally the name of an SELinux role. The idea is to give the name of the default role of a user logging into the system with a default SELinux type of the same name (barring the '_r' and '_t' suffixes).
# So the role 'user_r' with the default type 'user_t' would just be specified as 'user'.
# --target-type=
# The SELinux type of an object that is to be accessed in a certain way by a subject.
# --object-class=
# The SELinux object class of the target object.
# --permission-list
# A comma separated list of SELinux permissions. Should not include any spaces. The program will search for rules allowing *any* of the specified rules, *not* all of them.
# Rules in the output may allow any of the permissions, but not the others.
# --sudo
# Specify this option when only those types should be in the output that have rules giving them dac_override or dac_read_search permissions specified.
# If specified, the output will contain these rules.
# Given rules may allow dac_override, dac_read_search, or both. 
# Rules can also be for any capability object class, not just 'capability'.
# --debug
# Used to print debug information. Will get chaotic. Not recommended for an end user.
# AUTHOR
# Michael Hartmann


# Name of the role without the '_r'
DEFAULT_NAME=''
# Name of the target type
TARGET_TYPE=''
# Name of the object class
OBJECT_CLASS=''
# List of permissions to be checked for
PERMISSION_LIST=''
# 'Boolean' to signify whether permissions overriding DAC should be checked for
IS_SUDO=0
# 'Boolean' to signify debug mode
IS_DEBUG=0

# Get values from given arguments. An error if given if there is an unknown argument.
for arg in "$@"; do
	case $arg in 
		--default-name=*)
			DEFAULT_NAME=${arg#--default-name=}
			shift
		;;
		--target-type=*)
			TARGET_TYPE=${arg#--target-type=}
			shift
		;;
		--object-class=*)
			OBJECT_CLASS=${arg#--object-class=}
			shift
		;;
		--permission-list=*)
			PERMISSION_LIST=${arg#--permission-list=}
			shift
		;;
		--sudo)
			IS_SUDO=1
			shift
		;;
		--debug)
			IS_DEBUG=1
			shift
		;;
		*)
			echo "${arg%%=*} is not a valid parameter."
			exit 1
		;;
	esac
done

# Check whether options were given. The role suffix for the name is not checked it may be part of the name.
if [ -z "$DEFAULT_NAME" ]; then
	echo "Name of selinux role must be specified. The name should not include '_r' at the end of the name." >&2
	exit 1
fi
if [ -z "$TARGET_TYPE" ]; then
	echo "Target type must be specified." >&2
	exit 1
fi
if [ -z "$OBJECT_CLASS" ]; then
	echo "Object class must be specified." >&2 
	exit 1
fi
if [ -z "$PERMISSION_LIST" ]; then
	echo "Permission list must be specified. List should be separated by commas." >&2
	exit 1
fi
# Check for spaces
if echo "$PERMISSION_LIST" | grep -E '.*[[:space:]]+.*' > /dev/null; then
	echo "Permission list may not have spaces. The list should be separated by commas." >&2
	exit 1
fi

# The types the role can have.
TYPES=()
# Get all types the role can have
TYPES_OUTPUT="$( seinfo -r "${DEFAULT_NAME}_r" -x)"
# Fail fast
if echo "$TYPES_OUTPUT" | grep -E 'Roles:[[:space:]]+0' > /dev/null; then
	echo "Role ${DEFAULT_NAME}_r does not exist" >&2
	exit 1
fi
readarray -d ' ' TYPES <<< "$( echo "$TYPES_OUTPUT" | grep -Po '(?<={ ).+(?= })' )"
# Print debug information
[ "$IS_DEBUG" -eq 1 ] && echo "${TYPES[@]}"

# Check for every type whether the default type of the role can transition to it and whether allow rules for the permissions exist
for setype in "${TYPES[@]}"; do
	# Trim white space
	setype="$( echo "$setype" | grep -Eo '[[:graph:]]+')"
	# Get transitions rules
	TRANSITION_RULES="$( sesearch --allow -s "${DEFAULT_NAME}_t" -t "$setype" -c process -p transition  )"
	[ "$IS_DEBUG" -eq 1 ] && echo "$TRANSITION_RULES"
	# Check next type when there are no transition rules
	[ -z "$TRANSITION_RULES" ] && continue
	# Get allow rules
	ALLOW_RULES="$( sesearch --allow -s "$setype" -t "$TARGET_TYPE" -c "$OBJECT_CLASS" -p "$PERMISSION_LIST"  )"
	# Fail if a target type, class or permission does not exist
	if echo "$ALLOW_RULES" | grep -E '(is not a valid)|(do not exist in the specified classes)' > /dev/null; then
		echo "$ALLOW_RULES" >&2
		exit 1
	fi
	[ "$IS_DEBUG" -eq 1 ] && echo "$ALLOW_RULES"
	# Check next type when there are no allow rules
	[ -z "$ALLOW_RULES" ] && continue
	# Get rules for overriding DAC
	DAC_OVERRIDES="$( sesearch --allow -s "$setype" -p dac_override,dac_read_search )"
	[ "$IS_DEBUG" -eq 1 ] && echo "$DAC_OVERRIDES"
	# Check next type if there are no DAC override rules but those are needed
	[ "$IS_SUDO" -eq 1 ] && [ -z "$DAC_OVERRIDES" ] && continue
	# Generate output
	echo "Type: $setype"
	echo "Rules:"
	echo -e "$ALLOW_RULES"
	if [ "$IS_SUDO" -eq 1 ]; then
		echo "DAC Overrides:"
		echo -e "$DAC_OVERRIDES"
	fi
	echo -e "\n"
done

exit 0
