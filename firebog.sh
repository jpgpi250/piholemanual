#!/bin/bash

# Uncomment the list type you want to use (script default is Non-crossed lists)
#
# Modify the comment to match your list selection type
#
# Information about the list types can be found here:
# https://v.firebog.net/hosts/lists.php
#
# WARNING: this script only adds new lists, it doesn't remove lists that are no longer in the selected firebog list(s)!
#
# If you want to report a problem with this script, do NOT create a topic on the pihole forum!
# Report the issue on https://github.com/jpgpi250/piholemanual/issues
#

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  echo -e "${NOK}This script must be run as root (use sudo).${NC}"
  exit 1
fi

workdir=$(getent passwd $SUDO_USER | cut -d: -f6)
gravitydb="/etc/pihole/gravity.db"

dbversion=$(pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
	"SELECT value FROM 'info' \
		WHERE property = 'version';")
if [[ "${dbversion}" != "19" ]]; then
	echo -e "${NOK}This script was written for gravity database version 19 ${GREEN}(current version: ${dbversion})${NC}."
	echo -e "${INFO}Open an issue on GitHub (https://github.com/jpgpi250/piholemanual/issues)."
	exit
fi

#wget https://v.firebog.net/hosts/lists.php?type=tick -O ${workdir}/firebog.list
wget https://v.firebog.net/hosts/lists.php?type=nocross -O ${workdir}/firebog.list
#wget https://v.firebog.net/hosts/lists.php?type=all -O ${workdir}/firebog.list

if [ ! -s ${workdir}/firebog.list ]; then
	echo -e "${NOK}Could not retrieve selected firebog list!${NC}"
	exit 
fi

comment="firebog nocross"

# remove quidsub lists (malformed)
sed -i '/quidsup/d' ${workdir}/firebog.list
# remove empty lines
sed -i '/^$/d' ${workdir}/firebog.list

timestamp=$(date +"%s")

while read nocross; do
	sudo pihole-FTL sqlite3 "${gravitydb}"  ".timeout = 2000" \
		"insert or ignore into adlist \
			(address, enabled, comment, type) \
			values ('${nocross}', 1, '${comment}', 0);"
done < ${workdir}/firebog.list

sudo /usr/local/bin/pihole reloadlists
