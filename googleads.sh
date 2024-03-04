#!/bin/bash

# WARNING
# This script uses the group name and
# the whitelist comments to
# execute the sqlite3 statements
# change all matches, if desired, or the script will not work!

# If you previously entered whitelist entries, to allow google ads,
# you need to remove them, they probabbly apply to all devices,
# the effect of the new group will NOT be noticable if you dont remove them.

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

# whitelist entries
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googleadservices.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('dartsearch.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googletagmanager.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googletagservices.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('ad.doubleclick.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('clickserve.dartsearch.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into domainlist (domain, type, enabled, comment) values ('t.myvisualiq.net', 0, 1, 'allow google ads');"

# group
sudo pihole-FTL sqlite3 "${gravitydb}" "insert or ignore into 'group' (enabled, name, description) values ( 1, 'googleads', 'devices with google ads');"
GROUP_ID="$(sudo pihole-FTL sqlite3 "${gravitydb}" "SELECT id FROM 'group' WHERE name = 'googleads';")"

# assign whitelist entries to group
mapfile -t DOMAIN_ID < <(sudo pihole-FTL sqlite3 "${gravitydb}" "SELECT id FROM 'domainlist' WHERE comment = 'allow google ads';")
lenArray=${#DOMAIN_ID[@]}

for (( i=0; i<$lenArray; i++ )); do
	sudo pihole-FTL sqlite3 "${gravitydb}" "update 'domainlist_by_group' set group_id='$GROUP_ID' WHERE domainlist_id = '${DOMAIN_ID[$i]}';"
done

pihole restartdns reload-lists
