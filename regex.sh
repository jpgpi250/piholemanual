#!/bin/bash

# this script imports the regular expressions from mmotti into the gravity database.
# existing (duplicate) entries will not cause an error ('insert or ignore' in the sqlite3 statement).
# existing entries will not be updated (no change).

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

sudo curl https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list -o /home/pi/regex.list
while read -r regex; do
	if [[ ${regex} = ^* ]]; then
		sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('$regex', 3, 1, 'mmotti regex');"
	fi
done < /home/pi/regex.list
	
pihole restartdns reload-lists  
