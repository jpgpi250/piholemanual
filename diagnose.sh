#!/bin/bash

# the integrity of the whiptail dialogs was verified, running PUTTY, full screen required.

# script tested, using pihole v5.0 on Raspberry Pi OS (32-bit) Lite, version may 2020.
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

# first release, Sun 14 Jun 2020
# please report bugs as an issue at https://github.com/jpgpi250/piholemanual/issues 

# usage:
# diagnose the database: ./diagnose.sh
# diagnose the result of pihole query: pihole -q- all <domain> | ./diagnose.sh
# example: pihole -q -all eulerian.net  | ./diagnose.sh

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
# pihole -q contains these entries if there is a match for exact or regex entries
regexMatchArray=(whitelist blacklist)

starttime() {
start="$(date  "+%y%m%d %R" -d "$1")"
timezone="$(date  "+%Z")"
begintm=$(TZ=${timezone} date --date="${start}" +"%s")
echo $begintm
}

telnetinstalled=$(which telnet)
if [ -z "${telnetinstalled}" ]; then
	echo -e "${NOK}${BLUE}telnet${NC} is not installed on this system."
	whiptail --title "Information" --msgbox "This script will be more efficient it you install telnet, \
	this to retrieve the clients, only known to FTL." 10 60
fi

stdin="$(ls -l /proc/self/fd/0)"
stdin="${stdin/*-> /}"

if [[ "$stdin" =~ ^/dev/pts/[0-9] ]]; then
	# use database, complete overview
	pipe=false
	list=$(whiptail --title "Group Management" --radiolist \
	"Please select" 16 78 5 \
	"adlist" "adlists entries" ON \
	"blacklist" "exact or wildcard blacklist entries" OFF \
	"regex blacklist" "regex blacklist entries" OFF \
	"whitelist" "exact or wildcard whitelist entries" OFF \
	"regex whitelist" "regex whitelist entries" OFF \
		3>&1 1>&2 2>&3)
	if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
		exit
	else
		echo -e "${INFO}${BLUE}${list}${NC} diagnosis selected."
	fi
	case ${list} in
		"adlist")
			dbtable="adlist"
			field="address"
			query=""
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
	esac

	# read matching entries into array
	mapfile -t ListArray < <(sqlite3 ${gravitydb} ".timeout = 2000" \
		"SELECT id, ${field} FROM ${dbtable}${query} \
		ORDER by id;")
else
	# use output from pihole -q -all <domain> | ./diagnose.sh, selected overview
	pipe=true
	searchdomain=$(ps -ef | grep -v "grep" | grep "/usr/local/bin/pihole -q" | rev | cut -d " " -f1 | rev)
	echo -e "${INFO}Using piped output from '${BLUE}pihole -q${NC}'."
	echo -e "${INFO}Diagnosing domain ${GREEN}${searchdomain}${NC}"
	pipeArray=()
	while read -r line; do
		pipeArray+=("$line")
	done <<< "$(</dev/stdin)"
	
	resultArray=()
	match=false
	for (( i=0; i<${#pipeArray[@]}; i++ )); do
		# find lines containing text Match found in
		if [[ ${pipeArray[i]} == *"Over 100 results found"* ]]; then
			echo -e "${NOK}'pihole -q' returned ${RED}over 100 results${NC}."
			echo -e "${INFO}use '${GREEN}pihole -q -all${NC}' to retrieve all results."
			whiptail --title "Information" --msgbox "Your 'pihole -q' search returned over 100 results. \
			\nUse 'pihole -q -all' to retrieve all results." 10 60
			exit
		elif [[ "$match" == "true" ]]; then
			match=false
			IFS=' ' read -r listName Enabled <<< "${pipeArray[i]}"
			resultArray+=("${listName}")
			match=false
		elif [[ ${pipeArray[i]} == "Match found in"* ]]; then
			# get the adlists
			for (( j=0; j<${#listMatchArray[@]}; j++ )); do
				if [[ ${pipeArray[i]} == *"${listMatchArray[j]}"* ]]; then
					resultArray+=("$(echo ${pipeArray[i]} | sed 's/.$//' | sed 's/Match found in //g' )")
					break
				fi
			done
			# get exact or regex entries
			for (( j=0; j<${#regexMatchArray[@]}; j++ )); do
				# the whitespace in front of ${regexMatchArray[j]} isn't a typo
				# it ensures only the correct entries are selected
				# adlists URLs may contain the word blacklist or whitelist, but never whitespace
				if [[ ${pipeArray[i]} == *" ${regexMatchArray[j]}"* ]]; then
					# the next line is a regex or exact entry
					match=true
					break
				fi
			done
		fi
	done
	
	dbtableArray=()
	fieldArray=()
	ListArray=()
	idArray=()
	# read matching entries into array
	for (( i=0; i<${#resultArray[@]}; i++ )); do
		dbtable="domainlist"
		field="domain"
		for (( j=0; j<${#listMatchArray[@]}; j++ )); do
			if [[ ${resultArray[i]} == *"${listMatchArray[j]}"* ]]; then
				dbtable="adlist"
				field="address"
				break
			fi
		done
	dbtableArray+=("${dbtable}")
	fieldArray+=("${field}")
	result=$(sqlite3 ${gravitydb} ".timeout = 2000" \
		"SELECT id, ${field} FROM ${dbtable} \
			WHERE ${field} = '${resultArray[i]}';")
	IFS='|' read -r listID Value <<< "${result}"
	ListArray+=("${i}|${Value}")
	idArray+=("${listID}")
	done
fi

lenListArray=${#ListArray[@]}
if [ ${lenListArray} == 0 ]; then
	if [[ "$pipe" == "true" ]]; then
		echo -e "${NOK}'pihole -q' returned ${RED}no results${NC}."
		whiptail --title "Diagnose" --msgbox "'pihole -q' returned no results." 10 60
	else
		echo -e "${NOK}There are ${RED}no ${list} entries${NC} in the database."
		whiptail --title "Diagnose" --msgbox "There are no ${list} entries in the database." 10 60
	fi
	exit
fi

# start building the whiptail array
WhiptailArray=()
WhiptailLength=0

for (( i=0; i<${lenListArray}; i++ )); do
	IFS='|' read -r listID Value <<< "${ListArray[$i]}"
	WhiptailArray+=("${listID}")
	WhiptailArray+=("${Value} ")
	[[ " $i " =~ " 0 " ]] && WhiptailArray+=("ON") || WhiptailArray+=("OFF")
	if (( "${#Value}" > "${WhiptailLength}" )); then WhiptailLength=${#Value}; fi
done
WhiptailLength=$( expr ${WhiptailLength} + 21 )
if (( ${lenListArray} > 9 )); then WhiptailHight=9; else WhiptailHight=${lenListArray}; fi
SelectedID=$(whiptail --title "Group Management" --radiolist "Please select ${list} entry" 16 ${WhiptailLength} ${WhiptailHight} "${WhiptailArray[@]}" 3>&1 1>&2 2>&3)
if [ \( $? -eq 1 \) -o \( $? -eq 255 \) ]; then
	# ESC or CANCEL
	exit
else
	if [[ "$pipe" == "true" ]]; then
		dbtable=${dbtableArray[${SelectedID}]}
		field=${fieldArray[${SelectedID}]}
		SelectedID=${idArray[${SelectedID}]}
		if [[ "$dbtable" == "domainlist" ]]; then
			type=$(sqlite3 ${gravitydb} ".timeout = 2000" \
				"SELECT type FROM ${dbtable} \
					WHERE id = '${SelectedID}';")
			case ${type} in
				"0")
					list="whitelist"
					;;
				"1")
					list="blacklist"
					;;
				"2")
					list="regex whitelist"
					;;
				"3")
					list="regex blacklist"
					;;
				esac
		else
			list="adlist"
		fi
	fi
	printf "${INFO}${BLUE}${list}${NC} entry selected: ${GREEN}"
	# can't echo the entry, let sqlite3 print the result.
	sqlite3 ${gravitydb} ".timeout = 2000" \
		"SELECT ${field} FROM ${dbtable} \
			WHERE id = ${SelectedID};"
	printf "${NC}"
	# entry enabled?
	enabled=$(sqlite3 ${gravitydb} ".timeout = 2000" \
		"SELECT enabled FROM ${dbtable} \
			WHERE id = '${SelectedID}';")
	if [ "${enabled}" -eq "0" ]; then
		echo -e "${NOK}The selected ${BLUE}${list}${NC} entry ${RED}isn't enabled${NC}."
		whiptail --title "Diagnose" --msgbox "The selected ${list} entry isn't enabled." 10 60
		exit
	else
		echo -e "${OK}The selected ${BLUE}${list}${NC} entry ${GREEN}is enabled${NC}."
	fi
fi

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
fi

# start building the client whiptail array
WhiptailArray=()
WhiptailHight=0
clientIPLength=0
clientCommentLength=0
WhiptailSelect=false

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
		nmapinstalled=$(which nmap)
		if [ -z "${nmapinstalled}" ]; then
			echo -e "${NOK}${BLUE}nmap${NC} is not installed on this system."
			echo -e "${NOK}subnet entry ${GREEN}${clientIP}${NC} not evaluated!"
			whiptail --title "Information" --msgbox "This script will be more efficient if you install nmap, \
			this to evaluate subnet client entries." 10 60
		else
			mapfile -t SubnetArray < <(sudo nmap -sL -n ${clientIP} | grep "Nmap scan report for" | cut --delimiter " " --fields 5)
			lenSubnetArray=${#SubnetArray[@]}
			echo -e "${INFO}Evaluating subnet entry ${GREEN}${clientIP}${NC} (${BLUE}${lenSubnetArray}${NC} possible clients)."
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
		fi
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
if [[ ( ! -z "${telnetinstalled}" ) && ( "${SelectedGroup}" == "0" ) ]]; then
	printf "${INFO}Telnet result: "
	mapfile -t UnknownClientArray < <(( echo ">top-clients withzero"; echo ">quit"; sleep 1; ) \
		| telnet 127.0.0.1 4711 \
		| sed '/Trying/d' \
		| sed '/Connected to/d' \
		| sed '/Escape character is/d' \
		| cut --delimiter " " --fields 3 )
	lenUnknownClientArray=${#UnknownClientArray[@]}

	# add clients, retrieved, using the API to the array
	if (( $lenUnknownClientArray > 0 )); then
		for (( i=0; i<$lenUnknownClientArray; i++ )); do
			if [[ ! " ${WhiptailArray[@]} " =~ " ${UnknownClientArray[$i]} " ]]; then
				WhiptailHight=$((WhiptailHight+1))
				WhiptailArray+=("${UnknownClientArray[$i]}")
				clientComment="discovered (telnet) "
				WhiptailArray+=("${clientComment}")
				if [ "${WhiptailSelect}" = true ]; then  WhiptailArray+=("OFF"); else WhiptailArray+=("ON"); WhiptailSelect=true;fi
				if (( "${#UnknownClientArray[$i]}" > "${clientIPLength}" )); then clientIPLength=${#UnknownClientArray[$i]}; fi
				if (( "${#clientComment}" > "${clientCommentLength}" )); then clientCommentLength=${#clientComment}; fi
			fi
		done
	fi
fi

lenWhiptailArray=${#WhiptailArray[@]}
if [ ${lenWhiptailArray} == 0 ]; then
	echo -e "${NOK}The selected group ${RED}doesn't have any clients assigned${NC}."
	whiptail --title "Diagnose" --msgbox "The selected group doesn't have any clients assigned." 10 60
	exit
fi

# adjust the whiptail dialog hight (number of entries found)
WhiptailLength=$(( ${clientIPLength} + ${clientCommentLength} + 21 ))
if (( ${WhiptailHight} > 9 )); then WhiptailHight=9; fi
SelectedClient=$(whiptail --title "Group Management" --radiolist "Please select a client" 16 ${WhiptailLength} ${WhiptailHight} "${WhiptailArray[@]}" 3>&1 1>&2 2>&3)
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

# check if the client is using pihole
starttm=$(starttime "12 hours ago")
count=$(sqlite3 ${piholeFTLdb} ".timeout = 2000" \
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
			count=$(sqlite3 /etc/pihole/pihole-FTL.db ".timeout = 2000" \
				"SELECT count(*) FROM "queries" \
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
				result=$(sqlite3 /etc/pihole/pihole-FTL.db ".timeout = 2000" \
					"SELECT type, status FROM "queries" \
						WHERE domain = '${searchdomain}' \
							AND client = '${SelectedClient}' \
					LIMIT  ${count} OFFSET 1;")
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
				echo -e "${INFO}Query type: ${GREEN}${typeArray[${type}]}${NC}"
				if ((${status} >= 2 && ${status} <= 4)); then
					echo -e "${INFO}Status: ${GREEN}${statusArray[${status}]}${NC} (${commentArray[${status}]})"
				else
					echo -e "${INFO}Status: ${RED}${statusArray[${status}]}${NC} (${commentArray[${status}]})"
				fi
			fi
		fi
	fi
fi
