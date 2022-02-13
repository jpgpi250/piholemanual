#!/bin/bash

while read client
do
	IP="$(echo $client | cut --delimiter " " --fields 1)"
	COMMENT="$(echo $client | grep -o '[^ ]*$')"
	sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into client (ip, comment) values ('$IP', '$COMMENT');"
	done < /etc/localdns.list

pihole restartdns reload-lists  
