#!/bin/bash
# https://github.com/AdguardTeam/cname-trackers
#
# This script will install jq (https://stedolan.github.io/jq/) on your system!
# Don't run the the script if you do NOT want this!
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

which jq | grep -q 'jq'
if [ $? -eq 1 ]; then
	sudo apt-get -y install jq
fi

file=/home/pi/cloaked-trackers.json
sudo wget https://raw.githubusercontent.com/AdguardTeam/cname-trackers/master/script/src/cloaked-trackers.json -O $file

IFS=[,]
while read line; do
	domains=( ${line} )
	for domain in "${domains[@]}"; do 
		if [ ! -z "$domain" ]; then
			regex=(\\.\|^)${domain%.*}\\.${domain##*.}$
			sudo pihole-FTL sqlite3 "${gravitydb}" ".timeout = 2000" \
				"insert or ignore into domainlist \
					(type, domain, enabled, comment) \
					values (3, '$regex', 1, 'AdguardTeam CNAME list');"
		fi
	done
done < <(jq --raw-output "map(\"\(.domains)\")|.[]" < /home/pi/cloaked-trackers.json < ${file} | tr -d '[]"')

/usr/local/bin/pihole restartdns reload-lists
