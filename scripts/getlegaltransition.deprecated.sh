#!/bin/bash

# Get all domains which transition to is legal
LEGAL_TRANSITIONS=()
readarray -t LEGAL_TRANSITIONS < <(sesearch --allow -s $1 -p transition)

for transition in "${LEGAL_TRANSITIONS[@]}"; do
	#echo "$transition"
	# The types to be checked
	TYPES=()
	# Shave off everything but the type / attribute
	POTENTIAL_TYPE=${transition#allow * }
	POTENTIAL_TYPE=${POTENTIAL_TYPE%:process*}
	# String used to identify types
	TYPE_STRING='\<.*_t\>'
	if [[ $POTENTIAL_TYPE =~ "$TYPE_STRING"  ]]; then
		TYPES=( "$POTENTIAL_TYPE" )
	else
		readarray -t TYPES < <(seinfo -a "$POTENTIAL_TYPE" -x | grep -o "$TYPE_STRING")
	fi
	#echo "$TYPES"
	# Only use a class when fourth parameter has been given
	[ -n $4 ] && CLASS='' || CLASS="-c $4"
	for setype in "${TYPES[@]}"; do
		#echo "\"$setype\""
		if [ -n "setype" ] && [ -n "$(sesearch --allow -s $setype -t $2 -p $3 $CLASS)" ]; then
			echo "$setype"
		fi
	done
done

exit 0
