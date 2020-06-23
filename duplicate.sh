#!/bin/bash

# Don't use this script, using the command line
# This script is called by diagnose.sh

# More info can be found in the comments of diagnose.sh

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
OK=" [${GREEN}√${NC}] "
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

gravitydb="/etc/pihole/gravity.db"

entryEnabled() {
if [[ "$1" -eq "0" ]]; then
	echo -e "${NOK}The ${BLUE}$2${NC} entry ${RED}isn't enabled${NC}."
	whiptail --title "Diagnose" --msgbox "The selected $2 entry isn't enabled." 10 60
	exit
else
	echo -e "${OK}The ${BLUE}$2${NC} entry ${GREEN}is enabled${NC}."
fi
}

notAssigned() {
if [ $1 == 0 ]; then
	echo -e "${NOK}The ${BLUE}$2${NC} entry ${RED}isn't assigned to a group${NC}."
	whiptail --title "Diagnose" --msgbox "The $2 entry isn't assigned to a group." 10 60
	exit
fi
}

retrieveGroups() {
mapfile -t GroupArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT group_id FROM 'domainlist_by_group' \
				WHERE domainlist_id = $1 \
				ORDER by group_id;")
# no group assignments?
notAssigned "${#GroupArray[@]}" "$3"
# result of function will be assigned to variable
echo "${GroupArray[@]}"
}

getGroupName() {
result=$(sqlite3 ${gravitydb} ".timeout = 2000" \
	"SELECT name, description FROM 'group' \
			WHERE id = '$1';")
IFS='|' read -r name description  <<< "${result}"
	if [ -z "${description}" ]; then
		echo "${name}"
	else
		echo "${name} (${description})"
	fi
}

# diagnose.sh passes the id of the selected whitelist entry
if [ "$#" -ne 1 ]; then
    echo -e "${NOK}No argument passed (exact or regex whitelist id)."
	echo -e "${INFO}Run ${GREEN}./diagnnose.sh${NC} and select ${GREEN}duplicate${NC}"
	exit
fi

# retrieve the whitelist entry info
whitelistRecord=$(sqlite3 ${gravitydb} ".timeout = 2000" \
	"SELECT id, type, enabled, domain FROM 'domainlist' \
			WHERE id = '$1';")
IFS='|' read -r WLid WLtype WLenabled WLValue  <<< "${whitelistRecord}"
# entry enabled?
entryEnabled "${WLenabled}" "whitelist"
result=$(retrieveGroups "${WLid}" ${WLgroups} "whitelist")
IFS=', ' read -r -a WLgroups <<< "$result"
# type 0 (exact whitelist) -> exact blacklist type 1
# type 2 (regex whitelist) -> exaxt blacklist type 3
BLtype=$((${WLtype}+1))
# retrieve the blacklist entry info
blacklistRecord=$(sqlite3 ${gravitydb} ".timeout = 2000" \
	"SELECT id, enabled FROM 'domainlist' \
			WHERE domain = '${WLValue}' \
				AND type = '${BLtype}';")
IFS='|' read -r BLid BLenabled  <<< "${blacklistRecord}"
# entry enabled?
entryEnabled "${BLenabled}" "blacklist"
result=$(retrieveGroups "${BLid}" ${BLgroups} "blacklist")
IFS=', ' read -r -a BLgroups <<< "$result"
duplicateGroups=()
for (( i=0; i<${#WLgroups[@]}; i++ )); do
	for (( j=0; j<${#BLgroups[@]}; j++ )); do
		if [[ "${WLgroups[i]}" == "${BLgroups[j]}" ]]; then
			duplicateGroups+=("${WLgroups[i]}")
		fi
	done
done

if (( ${#duplicateGroups[@]} > 0 )); then
	for (( i=0; i<${#duplicateGroups[@]}; i++ )); do
		groupName=$(getGroupName ${duplicateGroups[i]})
		echo -e "${NOK}The group ${GREEN}${groupName}${NC} has a ${RED}conficting assignment${NC}, ${BLUE}whitelist${NC} WINS!"
	done
else
	echo -e "${INFO}There are ${GREEN}no conflicting asignments${NC} for this duplicate entry"
fi
