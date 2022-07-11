#!/bin/bash

# You should run this script once (manually) to verify all settings are correct.
# Use (cron) this script to verify the IPv6 address hasn't changed.
#
# Change the hextet value (2a02) on line 29 to match the first hextet of your IPv6 address.
#
# Script was written to detect changes in GUA addresses.
# Changes are required when using ULA addresses.
#

# eye candy / color
RED='\033[0;91m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color
NOK=" [${RED}!${NC}] "
INFO=" [${BLUE}i${NC}] "

file=/etc/pihole/pihole-FTL.conf

if [ ! -f ${file} ]; then
	echo -e "${NOK}The configuration file ${GREEN}${file}${NC} does NOT exist."
	echo -e "${INFO}See https://docs.pi-hole.net/ftldns/configfile/"
	exit 1
fi

# get current IPv6 address
hextet="2a02"
CURRENT_IPV6_ADDRESS=$(ip -6 a | grep "${hextet}" | grep 'mngtmpaddr' | awk -F " " '{gsub("/[0-9]*",""); print $2}')

if grep -q "LOCAL_IPV6=" ${file}; then
	OLD_IPV6_ADDRESS=$(grep 'LOCAL_IPV6=' "$file" |sed 's/^LOCAL_IPV6=//')
	# read/compare previous IPv6 address from file
	if ! grep -q "$CURRENT_IPV6_ADDRESS" ${file}; then
		match=$(grep "${hextet}:" ${file} | grep "LOCAL_IPV6=")
		sudo sed -i.bak "s/${match}/LOCAL_IPV6=${CURRENT_IPV6_ADDRESS}/g" "${file}"
		{
			echo from: root 
			echo subject: pihole IPv6 address change
			echo
			echo "Restart pihole-FTL to activate the change"
			echo
			cat "${file}" | grep 'LOCAL_IPV'
		} | sudo sendmail -d -t pi
	fi
else
	echo -e "${NOK}The configuration setting in ${GREEN}${file}${NC} does NOT exist."
	echo -e "${INFO}See https://docs.pi-hole.net/ftldns/configfile/#local_ipv6"
	exit 1
fi
