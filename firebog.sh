#!/bin/bash

wget https://v.firebog.net/hosts/lists.php?type=nocross -O /home/pi/firebog.list
while read nocross
do
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into adlist (address,comment,enabled) values (\"$nocross\", 'firebog nocross', 1);"
	done < /home/pi/firebog.list
