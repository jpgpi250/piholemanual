#!/bin/bash

mkdir -p /home/pi/quidsup

file=notrack-blocklist.txt
if [ -f /tmp/$file ] ; then
	rm /tmp/$file
fi
wget https://gitlab.com/quidsup/notrack-blocklists/raw/master/$file -O /tmp/$file
if [ -s /tmp/$file ] ; then
	sed -i 's/ #.*//g' /tmp/$file
	if [ -f /home/pi/quidsup/$file ] ; then
		rm /home/pi/quidsup/$file
	fi
	mv /tmp/$file /home/pi/quidsup/$file
fi	

file=notrack-malware.txt
if [ -f /tmp/$file ] ; then
	rm /tmp/$file
fi
wget https://gitlab.com/quidsup/notrack-blocklists/raw/master/$file -O /tmp/$file
if [ -s /tmp/$file ] ; then
	sed -i 's/ #.*//g' /tmp/$file
	if [ -f /home/pi/quidsup/$file ] ; then
		rm /home/pi/quidsup/$file
	fi
	mv /tmp/$file /home/pi/quidsup/$file
fi	
