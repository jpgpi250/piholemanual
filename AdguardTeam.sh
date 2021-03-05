#!/bin/bash
# https://github.com/AdguardTeam/cname-trackers

file=/home/pi/cloaked-trackers.json
sudo wget https://raw.githubusercontent.com/AdguardTeam/cname-trackers/master/script/src/cloaked-trackers.json -O $file

IFS=[,]
while read line; do
	domains=( ${line} )
	for domain in "${domains[@]}"; do 
		if [ ! -z "$domain" ]; then
			#echo $domain
			regex=(\\.\|^)${domain%.*}\\.${domain##*.}$
			sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into domainlist (type, domain, enabled, comment) values (3, \"$regex\", 1, 'AdguardTeam CNAME list');"
		fi	done
done < <(jq --raw-output "map(\"\(.domains)\")|.[]" < /home/pi/cloaked-trackers.json < ${file} | tr -d '[]"')

/usr/local/bin/pihole restartdns reload-lists
