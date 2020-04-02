#!/bin/bash

wget https://v.firebog.net/hosts/lists.php?type=nocross -O /home/pi/firebog.list

# remove quidsub lists (malformed)
sed -i '/quidsup/d' /home/pi/tmp/firebog.list
# remove cameleon list (Last updated : 2018-03-17)
sed -i '/cameleon/d' /home/pi/tmp/firebog.list
# remove hosts-file.net (blocklists are dead)
sed -i '/hosts-file.net/d' /home/pi/tmp/firebog.list

while read nocross
do
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into adlist (address, comment, enabled) values (\"$nocross\", 'firebog nocross', 1);"
	done < /home/pi/firebog.list
