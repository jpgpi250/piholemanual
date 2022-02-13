#!/bin/bash

# https://codepre.com/%F0%9F%90%A7-how-to-determine-which-services-to-restart-on-a-linux-system.html

IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')

if ! [[ -d "/lib/modules/$(uname -r)" ]]; then
	{
		echo from: root
		echo subject: Kernel update detected on "${IP}".
		echo
		echo "Reboot recommended."
	} | sudo sendmail -d -t pi
	exit 0
fi

SVCarray=()
while read line; do
	if echo "${line}" | grep -q 'SVC'; then
		IFS=" " read svc service <<< "${line}"
		SVCarray+=($(echo "${service%%.*}"))
	fi
done < <(sudo needrestart -b)

if (( ${#SVCarray[@]} )); then
	{
		echo from: root
		echo subject: Some services on "${IP}" need a restart.
		echo
		echo "Services:"
		for (( i=0; i<${#SVCarray[@]}; i++ )); do
			echo "- ${SVCarray[i]}"
		done
		echo
		echo "Run 'sudo needrestart' to restart services."
	} | sudo sendmail -d -t pi
fi
