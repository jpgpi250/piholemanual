#!/bin/bash

# WARNING
# This script uses the group name and
# the whitelist comments to
# execute the sqlite3 statements
# change all matches, if desired, or the script will not work!

# If you previously entered whitelist entries, to allow google ads,
# you need to remove them, they probabbly apply to all devices,
# the effect of the new group will NOT be noticable if you dont remove them.

# whitelist entries
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googleadservices.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('dartsearch.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googletagmanager.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('www.googletagservices.com', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('ad.doubleclick.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('clickserve.dartsearch.net', 0, 1, 'allow google ads');"
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into domainlist (domain, type, enabled, comment) values ('t.myvisualiq.net', 0, 1, 'allow google ads');"

# group
sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "insert or ignore into 'group' (enabled, name, description) values ( 1, 'googleads', 'devices with google ads');"
GROUP_ID="$(sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "SELECT id FROM 'group' WHERE name = 'googleads';")"

# assign whitelist entries to group
mapfile -t DOMAIN_ID < <(sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "SELECT id FROM 'domainlist' WHERE comment = 'allow google ads';")
lenArray=${#DOMAIN_ID[@]}

for (( i=0; i<$lenArray; i++ )); do
	sudo pihole-FTL sqlite3 "/etc/pihole/gravity.db" "update 'domainlist_by_group' set group_id='$GROUP_ID' WHERE domainlist_id = '${DOMAIN_ID[$i]}';"
done

pihole restartdns reload-lists
