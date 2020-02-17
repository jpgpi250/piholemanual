#!/bin/bash
# https://github.com/nextdns/cname-cloaking-blocklist

file=/home/pi/tmp/domains
sudo wget https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains -O $file

while read domain
do
	if ! [[ "$domain" == \#* ]]; then
		if [ ! -z "$domain" ]; then
			#echo $domain
			regex=(\\.\|^)${domain%.*}\\.${domain##*.}$
			sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into domainlist (type, domain, enabled, comment) values (3, \"$regex\", 1, 'NextDNS CNAME list');"
			fi
		fi
	done < $file
	
pihole restartdns reload-lists
