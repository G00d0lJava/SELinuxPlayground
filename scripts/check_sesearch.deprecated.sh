#!/bin/bash 

# Space separated list of domains to check permissions for
SOURCE_TYPE_LIST=''
# Space separated list of object types for which the source types should have permissions
TARGET_TYPE_LIST=''
# The class of the objects for which permissions should be checked
OBJECT_CLASS=''
# Space separated list of permsissions
PERMISSION_LIST=''
# Rule to be checked for. Not optional
RULE_TYPE=''

# Searches for a single rule fitting the given parameters. First argument is the source type, second is the target type, third is the object class,
# fourth is a comma-separated list of permissions and fifth is the rule type 
function search_rule () {
	#echo "1: |$1|"
	#echo "2: |$2|"
	#echo "3: |$3|"
	#echo "4: |$4|"
	#echo "5: |$5|"
	SOURCE_TYPE=''
	TARGET_TYPE=''
	CLASS=''
	PERMISSIONS=''
	RULE="--$5"
	if [ -n "$1" ]; then
		SOURCE_TYPE="-s $1"
	fi
	if [ -n "$2" ]; then
		TARGET_TYPE="-t $2"
	fi
	if [ -n "$3" ]; then
		CLASS="-c $3"
	fi
	if [ -n "$4" ]; then
		PERMISSIONS="-p $4"
	fi
	# Arguments for sesearch
	ARGS=( $RULE $SOURCE_TYPE $TARGET_TYPE $CLASS $PERMISSIONS )
	# Print source type and target type
	echo -e "\E[0;36m${SOURCE_TYPE#-s }\E[0m\E[0;33m${TARGET_TYPE#-t }\E[0m"
	sesearch ${ARGS[@]}
}

for arg in "$@"; do
	case $arg in 
		--source-type-list=*)
			SOURCE_TYPE_LIST=${arg#--source-type-list=}
			shift
		;;
		--target-type-list=*)
			TARGET_TYPE_LIST=${arg#--target-type-list=}
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
		--rule-type=*)
			RULE_TYPE=${arg#--rule-type=}
			shift
		;;
		*)
			echo "${arg%%=*} is not a valid parameter."
			exit 1
		;;
	esac
done

# Rule type is not optional
if [ -z RULE_TYPE ]; then
	echo "Rule type must be specified"
	exit 1
fi

# Change separating character
PERMISSION_LIST=${PERMISSION_LIST// /,}

SOURCE_ARR=( '' )
TARGET_ARR=( '' )

# Convert lists to actual arrays
if [ -n "$SOURCE_TYPE_LIST" ]; then
	readarray -d ' ' SOURCE_ARR <<< $SOURCE_TYPE_LIST
fi
if [ -n "$TARGET_TYPE_LIST" ]; then
	readarray -d ' ' TARGET_ARR <<< $TARGET_TYPE_LIST
fi


SOURCE_COUNTER=0

# Check every source and target type combination.
# Both are checked at least once in case no types were specifed
while	
	TARGET_COUNTER=0
	while 
		search_rule "${SOURCE_ARR[$SOURCE_COUNTER]}" "${TARGET_ARR[$TARGET_COUNTER]}" "$OBJECT_CLASS" "$PERMISSION_LIST" "$RULE_TYPE"
		TARGET_COUNTER=$(($TARGET_COUNTER + 1))
		[ "$TARGET_COUNTER" -lt "${#TARGET_ARR[@]}" ]; do
			true
	done
	SOURCE_COUNTER=$(($SOURCE_COUNTER + 1))
	[ "$SOURCE_COUNTER" -lt "${#SOURCE_ARR[@]}" ]; do
		true
done

exit 0
