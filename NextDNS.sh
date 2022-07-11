#!/bin/bash
# https://github.com/nextdns/cname-cloaking-blocklist
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

dbversion=$(pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
	"SELECT value FROM 'info' \
		WHERE property = 'version';")
if [[ "${dbversion}" != "15" ]]; then
	echo -e "${NOK}This script was written for gravity database version 15 ${GREEN}(current version: ${dbversion})${NC}."
	echo -e "${INFO}Open an issue on GitHub (https://github.com/jpgpi250/piholemanual/issues)."
	exit
fi

file=/home/pi/domains
sudo wget https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains -O $file

while read domain
do
	if ! [[ "$domain" == \#* ]]; then
		if [ ! -z "$domain" ]; then
			regex=(\\.\|^)${domain%.*}\\.${domain##*.}$
			sudo pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
				"insert or ignore into domainlist \
					(type, domain, enabled, comment) \
					values (3, '$regex', 1, 'NextDNS CNAME list');"
			fi
		fi
	done < $file
	
/usr/local/bin/pihole restartdns reload-lists
