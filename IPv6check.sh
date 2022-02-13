#!/bin/bash

# get current IPv6 address
CURRENT_IPV6_ADDRESS=$(ip -6 a | grep '2a02' | awk -F " " '{gsub("/[0-9]*",""); print $2}')

# read configured IPv6 address from /etc/pihole/setupVars.conf
file=/etc/pihole/setupVars.conf
OLD_IPV6_ADDRESS=$(grep 'IPV6_ADDRESS=' "$file" |sed 's/^IPV6_ADDRESS=//')

# read/compare previous IPv6 address from file
if ! grep -q "$CURRENT_IPV6_ADDRESS" $file; then
	sed -i.bak  "s/$OLD_IPV6_ADDRESS\b/$CURRENT_IPV6_ADDRESS/g" "$file"
	{
		echo from: root 
		echo subject: pihole IPv6 address change
		echo
		cat /etc/pihole/setupVars.conf | grep 'ADDRESS'
	} | sudo sendmail -d -t pi
	/usr/local/bin/pihole updateGravity
fi
