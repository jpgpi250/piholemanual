#!/bin/bash

# this script imports the regular expressions from mmotti into the gravity database.
# existing (duplicate) entries will not cause an error ('insert or ignore' in the sqlite3 statement).
# existing entries will not be updated (no change).

sudo curl https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list -o /home/pi/regex.list
while read -r regex; do
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into "domainlist" (domain, type, enabled, comment) values (\"$regex\", 3, 1, \"mmotti regex\");"
done < /home/pi/regex.list
	
pihole restartdns reload-lists  
