#!/bin/bash

DEFAULT_NAME=''
TARGET_TYPE=''
OBJECT_CLASS=''
PERMISSION_LIST=''
IS_SUDO=0
IS_DEBUG=0

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

TYPES=()
readarray -d ' ' TYPES <<< "$( seinfo -r "${DEFAULT_NAME}_r" -x | grep -Po '(?<={ ).+(?= })' )"
[ "$IS_DEBUG" -eq 1 ] && echo "${TYPES[@]}"

for setype in "${TYPES[@]}"; do
	setype="${setype// /}"
	TRANSITION_RULES="$( sesearch --allow -s "${DEFAULT_NAME}_t" -t "$setype" -c process -p transition  )"
	[ "$IS_DEBUG" -eq 1 ] && echo "$TRANSITION_RULES"
	[ -z "$TRANSITION_RULES" ] && continue
	ALLOW_RULES="$( sesearch --allow -s "$setype" -t "$TARGET_TYPE" -c "$OBJECT_CLASS" -p "$PERMISSION_LIST"  )"
	[ "$IS_DEBUG" -eq 1 ] && echo "$ALLOW_RULES"
	[ -z "$ALLOW_RULES" ] && continue
	DAC_OVERRIDES="$( sesearch --allow -s "$setype" -p dac_override,dac_read_search )"
	[ "$IS_DEBUG" -eq 1 ] && echo "$DAC_OVERRIDES"
	[ "$IS_SUDO" -eq 1 ] && [ -z "$DAC_OVERRIDES" ] && continue
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
