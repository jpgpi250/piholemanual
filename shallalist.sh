#!/bin/bash

file=shallalist.tar.gz
wget http://www.shallalist.de/Downloads/$file -O /home/pi/$file
wget http://www.shallalist.de/Downloads/$file.md5 -O /home/pi/$file.md5

md5sum --check /home/pi/$file.md5 | grep "shallalist.tar.gz: OK" &> /dev/null

if [ $? == 0 ]; then
	echo "download OK (MD5 checksum)"
else
	echo  "download failed (MD5 checksum)"
	exit
fi
cd ..

tar xzf /home/pi/$file -C /home/pi
