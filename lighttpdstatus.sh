#!/bin/bash

# fastcgi-php is no longer part of pi-hole since v5.15
if ! ls -l /etc/lighttpd/conf-enabled/ | grep -q "fastcgi-php"; then
	sudo lighttpd-enable-mod fastcgi-php
fi

# add lighttpd server-status config file (if it doesn't exist)
if ! [ -f "/etc/lighttpd/conf-available/51-serverstatus.conf" ]; then
	{
		echo "server.modules += ("
		echo "	\"mod_status\""
		echo ")"
		echo "status.status-url = \"/server-status\""
	} | sudo tee -a /etc/lighttpd/conf-available/51-serverstatus.conf >/dev/null

	# enable config, creates a link in /etc/lighttpd/conf-enabled/
	sudo lighttpd-enable-mod serverstatus
fi

# check configuration, this should echo Syntax OK
lighttpd -t -f /etc/lighttpd/lighttpd.conf

# restart lighttpd
sudo service lighttpd force-reload
