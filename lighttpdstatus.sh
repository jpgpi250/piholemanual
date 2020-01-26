#!/bin/bash

# add lighttpd server-status
file=/etc/lighttpd/external.conf
if ! grep -q "status.status-url" $file; then
	echo 'status.status-url = "/server-status"' | sudo tee -a $file
fi
file=/etc/lighttpd/lighttpd.conf
if ! grep -q "mod_status" $file; then
	sed -i '/"mod_auth",/a\\t"mod_status",' $file
fi

# check configuration
# this should echo Syntax OK
lighttpd -t -f /etc/lighttpd/lighttpd.conf

# restart lighttpd
sudo service lighttpd stop
sudo service lighttpd start
