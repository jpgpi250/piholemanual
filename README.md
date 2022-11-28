# piholemanual
This repository contains the files, referred to in my pi-hole installation [manual](https://jpgpi250.github.io/piholemanual/doc/Block%20Ads%20Network-wide%20with%20A%20Raspberry%20Pi-hole.pdf).
- The googleads script is explained [here](https://jpgpi250.github.io/piholemanual/doc/Whitelist%20Google%20Ads%20with%20Pi-hole%20v5.pdf).
- If you want to clone your SD card successfully, using [Win32DiskImager](https://win32diskimager.org/), you need to read [this](https://jpgpi250.github.io/piholemanual/doc/Manually%20resize%20partition%20for%20Backup.pdf) document.
- Find out who tries to bypass pihole, read [here](https://jpgpi250.github.io/piholemanual/doc/Catching%20Firewall%20redirected%20DNS%20requests.pdf).

Some scripts may contain IP addresses, which need to be edited, to allow correct processing!

The official pihole documentation can be found [here](https://docs.pi-hole.net/).

# DoH
- The usage of the DOH related files is explained in [this](https://jpgpi250.github.io/piholemanual/doc/Block%20DOH%20with%20pfsense.pdf) document.
- Additional DoH protection can be achieved by implementing
    response policy zones (RPZ), explained [here](https://jpgpi250.github.io/piholemanual/doc/Unbound%20response%20policy%20zones.pdf).
    suricata rules, explained in the [pfsense](https://jpgpi250.github.io/piholemanual/doc/Block%20DOH%20with%20pfsense.pdf) document (section 10).

NOTICE (08/2022): The DoHexception lists are deprecated, read the DoH manual to find out how to create local exception aliases.
- The deprecated lists will remain available, to allow users to implement the new policy.
