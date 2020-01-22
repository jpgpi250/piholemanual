#!/bin/bash

sudo curl https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list -o /home/pi/regex.list
while read regex
do
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into domainlist (domain,type) values (\"$regex\", 3);"
	done < /home/pi/regex.list
	
