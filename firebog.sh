#!/bin/bash

# Uncomment the list type you want to use (script default is Non-crossed lists)
#
# Modify the comment to match your list selection type
#
# Information about the list types can be found here:
# https://v.firebog.net/hosts/lists.php
#
# WARNING: this script only adds new lists, it doesn't remove lists that are no longer in the selected firebog list(s)!

workdir="/home/pi"
gravitydb="/etc/pihole/gravity.db"

#wget https://v.firebog.net/hosts/lists.php?type=tick -O $workdir/firebog.list
wget https://v.firebog.net/hosts/lists.php?type=nocross -O ${workdir}/firebog.list
#wget https://v.firebog.net/hosts/lists.php?type=all -O $workdir/firebog.list

comment="firebog nocross"

# remove quidsub lists (malformed)
sed -i '/quidsup/d' ${workdir}/firebog.list
# remove cameleon list (Last updated : 2018-03-17)
sed -i '/cameleon/d' ${workdir}/firebog.list
# remove hosts-file.net (blocklists are dead)
sed -i '/hosts-file.net/d' ${workdir}/firebog.list
# remove ssl.bblck.me/blacklists/hosts-file.txt (blocklist is dead)
sed -i '/ssl.bblck.me/d' ${workdir}/firebog.list
# remove hosts.nfz.moe/basic/hosts (blocklist is dead)
sed -i '/hosts.nfz.moe/d' ${workdir}/firebog.list

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

dbversion=$(pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
	"SELECT value FROM 'info' \
		WHERE property = 'version';")
if [[ "${dbversion}" != "15" ]]; then
	echo -e "${NOK}This script was written for gravity database version 14 ${GREEN}(current version: ${dbversion})${NC}."
	echo -e "${INFO}Open an issue on GitHub (https://github.com/jpgpi250/piholemanual/issues)."
	exit
fi

timestamp=$(date +"%s")

while read nocross; do
	sudo pihole-FTL sqlite3 "${gravitydb}"  ".timeout = 2000" \
		"insert or ignore into adlist \
			(address, enabled, date_added, date_modified, comment, date_updated, number, invalid_domains, status) \
			values ('${nocross}', 1, '${timestamp}', '${timestamp}', '${comment}', 0, 0, 0, 0);"
done < ${workdir}/firebog.list

pihole restartdns reload-lists
