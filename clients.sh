#!/bin/bash

while read client
do
	IP="$(echo $client | cut --delimiter " " --fields 1)"
	sudo sqlite3 /etc/pihole/gravity.db "insert or ignore into client (ip) values (\"$IP\");"
	done < /etc/localdns.list
  
