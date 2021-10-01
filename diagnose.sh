#!/bin/bash

# diagnose.sh also requires duplicate.sh
# copy both scripts to your system to use the duplicate diagnosis

# the integrity of the whiptail dialogs was verified, running PUTTY and OpenSSH, full screen required.

# script tested, using pihole v5.2.1 on Raspberry Pi OS Lite, version december 2020.
# you don't need to run the script with sudo, the script doesn't perform any writes.
# data is retrieved form the pihole databases, FTL (using the telnet API) and nmap.

# for optimal results, telnet and nmap need to be installed on the system,
# telnet to retrieve clients, using the FTL API
# nmap to determine the number of clients in a client subnet entry

# client discovery:
# initially, clients from the database are added
# if a client subnet entry is defined in the database, the subnet is evaluated, using nmap
# clients, found with nmap, NOT already selected from the databaser are added.
# if the default group is selected, clients found by FTL, using telnet (API), are added

# first release, Mon 15 Jun 2020
# updated, Thu 18 Jun 2020, bug fixes, added diagnoses for clients, groups, and discovered devices (telnet)
# updated, Fri 19 Jun 2020, ready for pihole v5.1
# updated, Fri 21 Dec 2021, ready for v.5.3.1, database version 14
# please report bugs as an issue at https://github.com/jpgpi250/piholemanual/issues 

# usage:
# diagnose the database: ./diagnose.sh
# diagnose the result of pihole query: pihole -q -exact -all <domain> | ./diagnose.sh
# example: pihole -q -exact -all eulerian.net  | ./diagnose.sh

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
OK=" [${GREEN}√${NC}] "
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

gravitydb="/etc/pihole/gravity.db"
piholeFTLdb="/etc/pihole/pihole-FTL.db"

# pihole -q contains these entries if there is a match for an adlist
listMatchArray=(https:// http:// file:///)
typeMatchArray=("exact whitelist" "exact blacklist" "regex whitelist" "regex blacklist")

starttime() {
start="$(date  "+%y%m%d %R" -d "$1")"
timezone="$(date  "+%Z")"
begintm=$(TZ=${timezone} date --date="${start}" +"%s")
echo $begintm
}

ListCount() {
Count=$(sqlite3 ${gravitydb} ".timeout = 2000" \
	"SELECT count(*) FROM '$1' \
		WHERE group_id = '$2';")
if [[ "${Count}" == "0" ]]; then
	echo -e "${NOK}There are ${RED}no $3s${NC} assigned to this ${BLUE}group${NC}."
	whiptail --title "Diagnose" --msgbox "There are no $3s assigned to this group." 10 60
else
	echo -e "${OK}${GREEN}${Count} $3(s)${NC} assigned to this ${BLUE}group${NC}."
fi
}

getAPIclients() {
UnknownClientArray=()
printf "${INFO}Telnet result: "
mapfile -t apiClientArray < <(( echo ">top-clients withzero"; echo ">quit"; sleep 1; ) \
	| telnet 127.0.0.1 4711 \
	| sed '/Trying/d' \
	| sed '/Connected to/d' \
	| sed '/Escape character is/d' \
	| cut --delimiter " " --fields 3 )
#lenUnknownClientArray=${#UnknownClientArray[@]}
if (( ${#apiClientArray[@]} > 0 )); then
	echo -e "${INFO}${GREEN}${#apiClientArray[@]}${NC} devices discovered, using the API (telnet)."
	mapfile -t allClientsArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
		"SELECT ip FROM 'client';")
	for (( i=0; i<${#apiClientArray[@]}; i++ )); do
		if [[ ! " ${allClientsArray[@]} " =~ " ${apiClientArray[$i]} " ]]; then
			UnknownClientArray+=("${apiClientArray[i]}")
		fi
	done
	if (( ${#UnknownClientArray[@]} > 0 )); then
		echo -e "${INFO}Found ${GREEN}${#UnknownClientArray[@]}${NC} additional client(s), using the API (telnet)."
	else
		echo -e "${INFO}All clients, found using the API (telnet), are in the database."
	fi
else
	echo -e "${NOK}There are {$RED}no devices{$NC} discovered, using the API (telnet)."
fi
}

isPackageInstalled() {
installed=$(which $1)
if [ -z "${installed}" ]; then
	echo -e "${NOK}${BLUE}$1${NC} is not installed on this system."
	whiptail --title "Information" --msgbox "This script requires you to install $1" 10 60
	exit
fi
}

dbversion=$(sqlite3 ${gravitydb} ".timeout = 2000" \
	"SELECT value FROM 'info' \
		WHERE property = 'version';")
if [[ "${dbversion}" != "14" ]]; then
	echo -e "${NOK}This script was written for gravity database version 14 (current version: ${GREEN}${dbversion}${NC})."
	echo -e "${INFO}Retrieve the latest version from ${BLUE}GitHub${NC}."
	whiptail --title "Information" --msgbox "This script was written for gravity database version 14." 10 60
	exit
else
	echo -e "${INFO}Database version ${GREEN}${dbversion}${NC} detected."
fi

isPackageInstalled "telnet"

stdin="$(ls -l /proc/self/fd/0)"
stdin="${stdin/*-> /}"

if [[ "$stdin" =~ ^/dev/pts/[0-9] ]]; then
	# use database, complete overview
	pipe=false
	list=$(whiptail --title "Group Management" --radiolist \
	"Please select" 15 73 9 \
	"group" "group entries " ON \
	"client" "client entries (database) " OFF \
	"devices" "client(s), discovered,using API " OFF \
	"adlist" "adlists entries " OFF \
	"blacklist" "exact or wildcard blacklist entries " OFF \
	"regex blacklist" "regex blacklist entries " OFF \
	"whitelist" "exact or wildcard whitelist entries " OFF \
	"regex whitelist" "regex whitelist entries " OFF \
	"duplicate" "duplicate white/blacklist (regex) entries " OFF \
		3>&1 1>&2 2>&3)
	if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
		exit
	else
		echo -e "${INFO}${BLUE}${list}${NC} diagnosis selected."
	fi
	case ${list} in
		"group")
			dbtable="group"
			field="name"
			comment=", description"
			query=" "
			;;
		"client")
			dbtable="client"
			field="ip"
			comment=", comment"
			query=" "
			;;
		"devices")
			;;
		"adlist")
			dbtable="adlist"
			field="address"
			query=" "
			;;
		"blacklist")
			dbtable="domainlist"
			field="domain"
			query=" WHERE type = '1'"
			;;
		"regex blacklist")
			dbtable="domainlist"
			field="domain"
			query=" WHERE type = '3'"
			;;
		"whitelist")
			dbtable="domainlist"
			field="domain"
			query=" WHERE type = '0'"
			;;
		"regex whitelist")
			dbtable="domainlist"
			field="domain"
			query=" WHERE type = '2'"
			;;
		"duplicate")
			dbtable="domainlist"
			field="domain"
			;;
	esac
	
	if [[ "${list}" = "duplicate" ]]; then
		mapfile -t DuplicateArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT count(*) c, ${field} FROM '${dbtable}' \
			GROUP BY ${field} HAVING c > 1;")
		if [ ${#DuplicateArray[@]} == 0 ]; then
			listArray=()
		else 
			for (( i=0; i<${#DuplicateArray[@]}; i++ )); do
			IFS='|' read -r count Value  <<< "${DuplicateArray[i]}"
			resultID=$(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT id FROM '${dbtable}' \
				WHERE (type = '0' OR type = '2') \
					AND domain = '${Value}' \
			ORDER by id;")
			ListArray+=("${resultID}|${Value}")
			done
		fi
	elif [[ "${list}" = "devices" ]]; then
		getAPIclients
		if (( ${#UnknownClientArray[@]} > 0 )); then
			for (( i=0; i<${#UnknownClientArray[@]}; i++ )); do
				ListArray+=("$i|${UnknownClientArray[i]}")
			done
		fi
	else
		# read matching entries into array
		mapfile -t ListArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT id, ${field}${comment} FROM '${dbtable}'${query} \
			ORDER by id;")
	fi
else
	# use output from pihole -q -all <domain> | ./diagnose.sh, selected overview
	pipe=true
	list="pihole -q"
	process=$(ps -ef | grep -v "grep" | grep "/usr/local/bin/pihole -q")
	if [[ $(echo ${process} | grep "\-exact" | grep "\-all") ]]; then
		#searchdomain=$(ps -ef | grep -v "grep" | grep "/usr/local/bin/pihole -q" | rev | cut -d " " -f1 | rev)
		searchdomain=$(echo ${process} | rev | cut -d " " -f1 | rev)
		echo -e "${INFO}Using piped output from '${BLUE}pihole -q${NC}'."
		echo -e "${INFO}Diagnosing domain ${GREEN}${searchdomain}${NC}"
	else
		echo -e "${NOK}Please use ${GREEN}pihole -q -exact -all${NC} to retrieve the correct results."
		whiptail --title "Information" --msgbox "Please use 'pihole -q -exact -all' to retrieve the correct results." 10 60
		exit
	fi
	pipeArray=()
	while read -r line; do
		pipeArray+=("$line")
	done <<< "$(</dev/stdin)"
	
	# parse the output of pihole -q, collect the necessary info to process
	resultArray=()
	count=0
	for (( i=0; i<${#pipeArray[@]}; i++ )); do
		# find lines containing text Match found in
		if [[ ${pipeArray[i]} == *"No exact results found"* ]]; then
			break
		fi
		if [[ ! ${pipeArray[i]} == "Exact match"* ]]; then
			if [[ ${pipeArray[i]} == *"://"* ]]; then
				# it's an adlist
				entry=$(echo ${pipeArray[i]} | sed 's/.* //')
				ID=$(sqlite3 ${gravitydb} ".timeout = 2000" \
					"SELECT id FROM 'adlist' \
						WHERE address = '${entry}';")
				resultArray+=("${count}∞adlist∞address∞0∞adlist∞${ID}∞${entry}")
				count=$((count+1))
			else
				# it's an exact or regexx whitelist or blacklist entry
				entry=${pipeArray[i]%" (disabled)"}
				entry=$(echo ${entry} | sed 's/^[ \t]*//')
				ID=$(sqlite3 ${gravitydb} ".timeout = 2000" \
					"SELECT id FROM 'domainlist' \
						WHERE domain = '${entry}' \
							AND type = '${type}';")
				resultArray+=("${count}∞domainlist∞domain∞${type}∞${comment}∞${ID}∞${entry}")
				count=$((count+1))
			fi
		else
			if [[ ${pipeArray[i]} == "Exact match found in"* ]]; then
				if [[ " ${typeMatchArray[@]} " =~ " ${pipeArray[$i]: -15} " ]]; then
					for (( j=0; j<${#typeMatchArray[@]}; j++ )); do
						if [[ "${typeMatchArray[$j]}" = "${pipeArray[$i]: -15}" ]]; then
							comment=${typeMatchArray[$j]}
							type=${j}
						fi
					done
				fi
			fi
		fi
	done
	
	ListArray=()
	for (( i=0; i<${#resultArray[@]}; i++ )); do
		IFS='∞' read -r ArrayID dbtable field type Comment ListID Value <<< "${resultArray[i]}"
		ListArray+=("${ArrayID}∞${Value}∞${Comment}")
	done
fi

if [ ${#ListArray[@]} == 0 ]; then
	if [[ "${list}" != "devices" ]]; then
		if [[ "$pipe" == "true" ]]; then
			echo -e "${NOK}'pihole -q' returned ${RED}no results${NC}."
			whiptail --title "Diagnose" --msgbox "'pihole -q' returned no results." 10 60
		else
			echo -e "${NOK}There are ${RED}no ${list} entries${NC} in the database."
			whiptail --title "Diagnose" --msgbox "There are no ${list} entries in the database." 10 60
		fi
	fi
	exit
fi

# start building the whiptail array
WhiptailArray=()
WhiptailLength=0

for (( i=0; i<${#ListArray[@]}; i++ )); do
	if [[ ( "${list}" = "client" ) || ( "${list}" = "group" ) ]]; then
		IFS='|' read -r listID Value Comment<<< "${ListArray[$i]}"
		if [ ! -z "${Comment}" ]; then
			Value="${Value} (${Comment})"
		fi
	elif [[ ("${pipe}" = "true" ) ]]; then
		IFS='∞' read -r listID Value Comment<<< "${ListArray[$i]}"
		if [[ ("${Comment}" = "adlist" ) ]]; then
			Value="${Value}"
		else
			Value="${Comment}:  ${Value}"
		fi
	else
		IFS='|' read -r listID Value <<< "${ListArray[$i]}"
	fi
	WhiptailArray+=("${listID}")
	WhiptailArray+=("${Value} ")
	[[ " $i " =~ " 0 " ]] && WhiptailArray+=("ON") || WhiptailArray+=("OFF")
	if (( "${#Value}" > "${WhiptailLength}" )); then WhiptailLength=${#Value}; fi
done
WhiptailLength=$( expr ${WhiptailLength} + 21 )
if (( ${#ListArray[@]} > 9 )); then WhiptailHight=9; else WhiptailHight=${#ListArray[@]}; fi
SelectedID=$(whiptail --title "Group Management" --radiolist "Please select ${list} entry" 16 ${WhiptailLength} ${WhiptailHight} "${WhiptailArray[@]}" 3>&1 1>&2 2>&3)
if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
	# ESC or CANCEL
	exit
else
	if [[ "$pipe" == "true" ]]; then
		IFS='∞' read -r ArrayID dbtable field type list ListID Value <<< "${resultArray[${SelectedID}]}"
		SelectedID=${ListID}
	fi
	if [[ "${list}" != "devices" ]]; then
		printf "${INFO}${BLUE}${list}${NC} entry selected: ${GREEN}"
		# can't echo the entry, let sqlite3 print the result.
		sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT ${field} FROM '${dbtable}' \
				WHERE id = ${SelectedID};"
		printf "${NC}"
			
		if [[ "${list}" = "duplicate" ]]; then
			SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
			if [ -f "${SCRIPTPATH}/duplicate.sh" ]; then
				${SCRIPTPATH}/duplicate.sh ${SelectedID}
			else
				echo -e "${NOK}Cannot locate the script to perform duplicate diagnostics"
			fi
			exit
		fi
		
		# entry enabled?
		if [[ "${list}" = "client" ]]; then
			SelectedClient=$(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT ip FROM '${dbtable}' \
				WHERE id = '${SelectedID}';")
		else
			enabled=$(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT enabled FROM '${dbtable}' \
					WHERE id = '${SelectedID}';")
			if [[ "${enabled}" -eq "0" ]]; then
				echo -e "${NOK}The selected ${BLUE}${list}${NC} entry ${RED}isn't enabled${NC}."
				whiptail --title "Diagnose" --msgbox "The selected ${list} entry isn't enabled." 10 60
				exit
			else
				echo -e "${OK}The selected ${BLUE}${list}${NC} entry ${GREEN}is enabled${NC}."
			fi
		fi
	else
		SelectedClient=${UnknownClientArray[${SelectedID}]}
		echo -e "${INFO}${BLUE}${list}${NC} entry selected: ${GREEN}${SelectedClient}${NC}"
	fi
fi

if [[ "${list}" != "devices" ]]; then
	if [[ "${list}" = "group" ]]; then
		SelectedGroup=$(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT id FROM '${dbtable}' \
				WHERE id = '${SelectedID}';")
		ListCount "adlist_by_group" "${SelectedID}" "adlist"
		ListCount "domainlist_by_group" "${SelectedID}" "domain"
	else
		# retrieve all the groups, the selected entry is assigned to
		mapfile -t GroupArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
			"SELECT group_id FROM '${dbtable}_by_group' \
				WHERE ${dbtable}_id = ${SelectedID} \
				ORDER by group_id;")

		lenGroupArray=${#GroupArray[@]}
		if [ ${lenGroupArray} == 0 ]; then
			echo -e "${NOK}The selected ${BLUE}${list}${NC} entry ${RED}isn't assigned to a group${NC}."
			whiptail --title "Diagnose" --msgbox "The selected ${list} entry isn't assigned to a group." 10 60
			exit
		fi

		# start building the group whiptail array
		WhiptailArray=()
		WhiptailLength=0

		for (( i=0; i<${lenGroupArray}; i++ )); do
			GroupName=$(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT id, name, description FROM 'group' \
					WHERE id = ${GroupArray[$i]};")
			IFS='|' read -r groupID groupName groupDescription <<< "${GroupName}"
			WhiptailArray+=("${groupID}")
			if [ ! -z "${groupDescription}" ]; then
				groupName="${groupName} (${groupDescription})"
			fi
			WhiptailArray+=("${groupName}")
			[[ " $i " =~ " 0 " ]] && WhiptailArray+=("ON") || WhiptailArray+=("OFF")
			if (( "${#groupName}" > "${WhiptailLength}" )); then WhiptailLength=${#groupName}; fi
		done

		WhiptailLength=$( expr ${WhiptailLength} + 21 )
		if (( ${lenGroupArray} > 9 )); then WhiptailHight=9; else WhiptailHight=${lenGroupArray}; fi
		SelectedGroup=$(whiptail --title "Group Management" --radiolist "Please select a group" 16 ${WhiptailLength} ${WhiptailHight} "${WhiptailArray[@]}" 3>&1 1>&2 2>&3)
		if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
			# ESC or CANCEL
			exit
		else
			printf "${INFO}Group selected: ${GREEN}"
			sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT name FROM 'group' \
					WHERE id = ${SelectedGroup};"
			printf "${NC}"
			# entry enabled?
			enabled=$(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT enabled FROM 'group' \
					WHERE ID=${SelectedGroup};")
			if [ "${enabled}" -eq "0" ]; then
				echo -e "${NOK}The selected group ${RED}isn't enabled${NC}."
				whiptail --title "Diagnose" --msgbox "The selected group entry isn't enabled." 10 60
				exit
			else
				echo -e "${OK}The selected group ${GREEN}is enabled${NC}."
			fi
			if [[ "${list}" = "client" ]]; then
				ListCount "adlist_by_group" "${SelectedGroup}" "adlist"
				ListCount "domainlist_by_group" "${SelectedGroup}" "domain"
			fi
		fi
	fi

	if [[ ( "${list}" != "client" ) || ( "${SelectedClient}" == *"/"* ) ]]; then
		# start building the client whiptail array
		WhiptailArray=()
		WhiptailHight=0
		clientIPLength=0
		clientCommentLength=0
		WhiptailSelect=false

		if [[ "${SelectedClient}" == *"/"* ]]; then
			WhiptailText="Evaluating subnet entry, please select a client"
			mapfile -t SubnetArray < <(sudo nmap -sL -n ${SelectedClient} | grep "Nmap scan report for" | cut --delimiter " " --fields 5)
			lenSubnetArray=${#SubnetArray[@]}
			echo -e "${INFO}Evaluating subnet entry ${GREEN}${SelectedClient}${NC} (${GREEN}${lenSubnetArray}${NC} possible clients)."
			for (( j=0; j<${lenSubnetArray}; j++ )); do
				if [[ ! " ${WhiptailArray[@]} " =~ " ${SubnetArray[$j]} " ]]; then
					WhiptailHight=$((WhiptailHight+1))
					WhiptailArray+=("${SubnetArray[$j]}")
					clientComment=$(sqlite3 ${gravitydb} ".timeout = 2000" \
						"SELECT comment FROM 'client' \
							WHERE ip = '${SubnetArray[$j]}';")
					if [ -z "${clientComment}" ]; then clientComment=("discovered, subnet ${SelectedClient} (nmap) ");	fi
					WhiptailArray+=("${clientComment}")
					if [ "${WhiptailSelect}" = true ]; then  WhiptailArray+=("OFF"); else WhiptailArray+=("ON"); WhiptailSelect=true; fi
					if (( "${#SelectedClient}" > "${clientIPLength}" )); then clientIPLength=${#SelectedClient}; fi
					if (( "${#clientComment}" > "${clientCommentLength}" )); then clientCommentLength=${#clientComment}; fi
				fi
			done
		else
			WhiptailText="Please select a client"
			# retrieve clients, assigned to the selected group
			mapfile -t ClientArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT client_id FROM 'client_by_group' \
					WHERE group_id = ${SelectedGroup} \
				ORDER by client_id;")
			lenClientArray=${#ClientArray[@]}

			# add the clients from the database to the array
			for (( i=0; i<${lenClientArray}; i++ )); do
				ClientName=$(sqlite3 ${gravitydb} ".timeout = 2000" \
					"SELECT id, ip, comment FROM 'client' \
						WHERE id = ${ClientArray[$i]};")
				IFS='|' read -r clientID clientIP clientComment <<< "${ClientName}"
				if [[ ${clientIP} == *"/"* ]]; then
					isPackageInstalled "nmap"
					mapfile -t SubnetArray < <(sudo nmap -sL -n ${clientIP} | grep "Nmap scan report for" | cut --delimiter " " --fields 5)
					lenSubnetArray=${#SubnetArray[@]}
					echo -e "${INFO}Evaluating subnet entry ${GREEN}${clientIP}${NC} (${GREEN}${lenSubnetArray}${NC} possible clients)."
					for (( j=0; j<${lenSubnetArray}; j++ )); do
						if [[ ! " ${WhiptailArray[@]} " =~ " ${SubnetArray[$j]} " ]]; then
							WhiptailHight=$((WhiptailHight+1))
							WhiptailArray+=("${SubnetArray[$j]}")
							clientComment=$(sqlite3 ${gravitydb} ".timeout = 2000" \
								"SELECT comment FROM 'client' \
									WHERE ip = '${SubnetArray[$j]}';")
							if [ -z "${clientComment}" ]; then clientComment=("discovered, subnet ${clientIP} (nmap) ");	fi
							WhiptailArray+=("${clientComment}")
							if [ "${WhiptailSelect}" = true ]; then  WhiptailArray+=("OFF"); else WhiptailArray+=("ON"); WhiptailSelect=true; fi
							if (( "${#clientIP}" > "${clientIPLength}" )); then clientIPLength=${#clientIP}; fi
							if (( "${#clientComment}" > "${clientCommentLength}" )); then clientCommentLength=${#clientComment}; fi
						fi
					done
				else
					if [[ ! " ${WhiptailArray[@]} " =~ " ${clientIP} " ]]; then
						WhiptailHight=$((WhiptailHight+1))
						WhiptailArray+=("${clientIP}")
						WhiptailArray+=("${clientComment}")
						if [ "${WhiptailSelect}" = true ]; then  WhiptailArray+=("OFF"); else WhiptailArray+=("ON"); WhiptailSelect=true;fi
						if (( "${#clientIP}" > "${clientIPLength}" )); then clientIPLength=${#clientIP}; fi
						if (( "${#clientComment}" > "${clientCommentLength}" )); then clientCommentLength=${#clientComment}; fi
					fi
				fi
			done

			# if telnet is installed, retrieve the clients, known to FTL
			# only used, if the default group is selected.
			if  (( "${SelectedGroup}" == "0" ));then
				getAPIclients
				# add clients, retrieved, using the API to the array
				if (( ${#UnknownClientArray[@]} > 0 )); then
					for (( i=0; i<${#UnknownClientArray[@]}; i++ )); do
						WhiptailHight=$((WhiptailHight+1))
						WhiptailArray+=("${UnknownClientArray[$i]}")
						clientComment="discovered (telnet) "
						WhiptailArray+=("${clientComment}")
						if [ "${WhiptailSelect}" = true ]; then  WhiptailArray+=("OFF"); else WhiptailArray+=("ON"); WhiptailSelect=true;fi
						if (( "${#UnknownClientArray[$i]}" > "${clientIPLength}" )); then clientIPLength=${#UnknownClientArray[$i]}; fi
						if (( "${#clientComment}" > "${clientCommentLength}" )); then clientCommentLength=${#clientComment}; fi
					done
				fi
			fi

			lenWhiptailArray=${#WhiptailArray[@]}
			if [ ${lenWhiptailArray} == 0 ]; then
				echo -e "${NOK}There are ${RED}no clients${NC} assigned to this ${BLUE}group${NC}."
				whiptail --title "Diagnose" --msgbox "There are no clients assigned to this group." 10 60
				exit
			fi
		fi

		# adjust the whiptail dialog hight (number of entries found)
		WhiptailLength=$(( ${clientIPLength} + ${clientCommentLength} + 21 ))
		if (( ${WhiptailHight} > 9 )); then WhiptailHight=9; fi
		SelectedClient=$(whiptail --title "Group Management" --radiolist "${WhiptailText}" 16 ${WhiptailLength} ${WhiptailHight} "${WhiptailArray[@]}" 3>&1 1>&2 2>&3)
		if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
			# ESC or CANCEL
			exit
		else
			clientInfo=$(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT comment FROM 'client' \
					WHERE ip='${SelectedClient}';")
			if [ -z "${clientInfo}" ]; then
				echo -e "${INFO}Client selected: ${GREEN}${SelectedClient}${NC}"
			else
				echo -e "${INFO}Client selected: ${GREEN}${SelectedClient}${NC} (${clientInfo})."
			fi
		fi
	fi
fi

# retrieve time of last entry from database
timeOfLastEntry=$(sqlite3 ${piholeFTLdb} ".timeout = 5000" \
	"SELECT timestamp FROM 'queries' \
		ORDER BY id
		DESC LIMIT 1;")
echo -e "${INFO}Time of last entry in query database: ${GREEN}$(date -d @${timeOfLastEntry})${NC}"	
echo -e "${INFO}${RED}More recent queries NOT evaluated...${NC}"

# check if the client is using pihole
starttm=$(starttime "12 hours ago")
count=$(sqlite3 ${piholeFTLdb} ".timeout = 5000" \
	"SELECT count(*) FROM "queries" \
		WHERE client = '${SelectedClient}' \
			AND "timestamp" > ${starttm};")
if [[ "${count}" == "0" ]]; then
	echo -e "${NOK}The client ${RED}hasn't used pihole${NC} as a DNS server in the last 12 hours"
	whiptail --title "Diagnose" --msgbox "This client hasn't used pihole as a DNS server in the last 12 hours." 10 60
else
	echo -e "${OK}This client ${GREEN}is using pihole${NC} as a DNS server."
	if [[ "$pipe" == "true" ]]; then
		if [ -z "${searchdomain}" ]; then
			echo -e "${NOK}Could not retrieve search ('ps -ef' failed)."
		else
			# check if the client queried the searchdomain (pihole -q- all <domain>)
			count=$(sqlite3 ${piholeFTLdb} ".timeout = 5000" \
				"SELECT count(*) FROM 'queries' \
					WHERE domain = '${searchdomain}' \
						AND client = '${SelectedClient}' \
						AND "timestamp" > ${starttm};")
			if [[ "${count}" == "0" ]]; then
				echo -e "${NOK}The client ${RED}hasn't queried${NC} ${GREEN}${searchdomain}${NC} in the last 12 hours"
				whiptail --title "Diagnose" --msgbox "This client hasn't queried ${searchdomain} in the last 12 hours." 10 60
			else
				echo -e "${OK}This client ${GREEN}has queried${NC} ${searchdomain}."
				count=$((count-1))
				# retrieve type and status of last query
				result=$(sqlite3 ${piholeFTLdb} ".timeout = 5000" \
					"SELECT type, status FROM 'queries' \
						WHERE domain = '${searchdomain}' \
							AND client = '${SelectedClient}' \
					ORDER BY id
					DESC LIMIT 1;")
#					LIMIT  ${count} OFFSET 1;")

				IFS='|' read -r type status <<< "${result}"
				typeArray=(A AAAA ANY SRV SOA PTR TXT)
				statusArray=(Unknown Blocked Allowed Allowed Blocked Blocked Blocked Blocked Blocked Blocked Blocked Blocked)
				commentArray=("was not answered by forward destination" \
								"Domain contained in gravity database" \
								"Forwarded" \
								"Known, replied to from cache" \
								"Domain matched by a regex blacklist filter" \
								"Domain contained in exact blacklist" \
								"By upstream server (known blocking page IP address)" \
								"By upstream server (0.0.0.0 or ::)" \
								"By upstream server (NXDOMAIN with RA bit unset)" \
								"Domain contained in gravity database (deep CNAME inspection)" \
								"Domain matched by a regex blacklist filter (deep CNAME inspection)" \
								"Domain contained in exact blacklist (deep CNAME inspection)")
				# there is no query type 0, adjusting to retrieve array value
				type=$((type-1))
				echo -e "${INFO}Last query type: ${GREEN}${typeArray[${type}]}${NC}"
				if ((${status} >= 2 && ${status} <= 4)); then
					echo -e "${INFO}Status: ${GREEN}${statusArray[${status}]}${NC} (${commentArray[${status}]})"
				else
					echo -e "${INFO}Status: ${RED}${statusArray[${status}]}${NC} (${commentArray[${status}]})"
				fi
			fi
		fi
	fi
fi
