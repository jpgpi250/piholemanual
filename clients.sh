#!/bin/bash
#
# If you want to report a problem with this script, do NOT create a topic on the pihole forum!
# Report the issue on https://github.com/jpgpi250/piholemanual/issues
#

gravitydb="/etc/pihole/gravity.db"

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

# This script will work for both v5 and v6, change the value to match your version.
# gravity database: pi-hole v5 - version = 15, v6 version = 19
dbversion=$(pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
	"SELECT value FROM 'info' \
		WHERE property = 'version';")
if [[ "${dbversion}" != "19" ]]; then
	echo -e "${NOK}This script was written for gravity database version 19 ${GREEN}(current version: ${dbversion})${NC}."
	echo -e "${INFO}Open an issue on GitHub (https://github.com/jpgpi250/piholemanual/issues)."
	exit
fi

while read client
do
	IP="$(echo $client | cut --delimiter " " --fields 1)"
	COMMENT="$(echo $client | grep -o '[^ ]*$')"
	sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into client (ip, comment) values ('$IP', '$COMMENT');"
	done < /etc/pihole/hosts/localdns.list

pihole restartdns reload-lists  
