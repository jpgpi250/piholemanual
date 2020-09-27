#!/bin/bash

# Uncomment the list type you want to use (script default is Non-crossed lists)
# Information about the list types can be found here:
# https://v.firebog.net/hosts/lists.php

workdir=/home/pi

#wget https://v.firebog.net/hosts/lists.php?type=tick -O $workdir/firebog.list
wget https://v.firebog.net/hosts/lists.php?type=nocross -O $workdir/firebog.list
#wget https://v.firebog.net/hosts/lists.php?type=all -O $workdir/firebog.list

# remove quidsub lists (malformed)
sed -i '/quidsup/d' $workdir/firebog.list
# remove cameleon list (Last updated : 2018-03-17)
sed -i '/cameleon/d' $workdir/firebog.list
# remove hosts-file.net (blocklists are dead)
sed -i '/hosts-file.net/d' $workdir/firebog.list
# remove ssl.bblck.me/blacklists/hosts-file.txt (blocklist is dead)
sed -i '/ssl.bblck.me/d' $workdir/firebog.list

while read nocross; do
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into adlist (address, comment, enabled) values (\"$nocross\", 'firebog nocross', 1);"
done < $workdir/firebog.list

pihole restartdns reload-lists
