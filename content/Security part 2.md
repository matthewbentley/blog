{
    "date": "2015-02-13",
    "description": "How to set up PF and fail2ban for security on a FreeBSD server, and isolate applications with BSD Jails.",
    "draft": false,
    "id": 17,
    "image": "",
    "meta_title": "FreeBSD security with PF, fail2ban, and Jails",
    "slug": "security2",
    "tags": [
        "security",
        "guide",
        "PF",
        "Jails",
        "FreeBSD"
    ],
    "title": "Security part 2",
    "type": "post"
}


Here I describe more security measures I've taken for my new FreeBSD 10.1 server.
<!--more-->

<span style="background-color: #FFFF00">CAVEAT</span>: The below configs are somewhat aggressive, and if you make a mistake you may lock yourself out of your own server.  Be sure to have another IP address you can SSH in with in case you do so.
If you do happen to lock yourself out, run `pfctl -t childrens -T show` and `pfctl -t fail2ban -T show` to find out which table caught your IP address, and then `pfctl -t $(table) -T delete $(your_ip)` (where `$(table)` is the table that caught it and `$(your_ip)` is the IP you want to unban) to remove it from the filter.

----
# OS (FreeBSD)
This part of the guide mostly focuses on keeping potentially unwanted traffic off your server.
## PF (Packet Filter)
This is mostly based off the guide [here](http://www.bsdnow.tv/tutorials/pf).  The biggest thing to note is that the line
`match in all scrub (no-df max-mss 1440)`
should be
`scrub in all no-df max-mss 1440`
on FreeBSD.  Also, note that if there should be an error in your config, PF counts multi-line entries (separated by '\') as a single line when reporting it.

My full pf.conf (located at `/etc/pf.conf`):
```
ext_if = "vtnet0"
jail_lo = "lo1"
ghost = "10.7.0.1"
weechat = "10.7.0.2"
onion = "10.7.0.3"
broken="224.0.0.22 127.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12, \
        169.254.0.0/16, 192.0.2.0/24, \
        192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, \
        169.254.0.0/16, 0.0.0.0/8, 240.0.0.0/4, 255.255.255.255/32"
set block-policy drop
set skip on lo0
set skip on $jail_lo
scrub in all no-df max-mss 1440
nat on $ext_if from $jail_lo to any -> ($ext_if)
rdr on $ext_if proto tcp from any to any port 2222 -> $weechat port 22
rdr on $ext_if proto { tcp udp } from any to any port { 9001 9030 } \
-> $onion
block in all
pass out quick on $ext_if inet keep state
antispoof quick for ($ext_if) inet
block out quick inet6 all
block in quick inet6 all
block in quick from { $broken urpf-failed no-route } to any
block out quick on $ext_if from any to { $broken no-route }
table <childrens> persist
block in quick proto tcp from <childrens> to any
table <fail2ban> persist
block quick proto tcp from <fail2ban> to $ext_if port ssh
table <chuugoku> persist file "/etc/cn.zone"
block in quick proto tcp from <chuugoku> to any port \
{ 22 110 995 143 993 }
pass in on $ext_if proto tcp from any to any port { 80 443 } \
flags S/SA synproxy state
pass in on $ext_if proto tcp from any to any port \
{ 25 587 110 995 143 993 9001 9030  }
pass in on $ext_if proto tcp to any port ssh flags S/SA keep state \
(max-src-conn 5, max-src-conn-rate 5/5, overload <childrens> flush)
pass inet proto icmp icmp-type echoreq
```

A brief explanation of the lines that differ from the tutorial:
The `broken=` line is changed to remove `10.0.0.0/8`, since I use that subnet for OpenVPN and Jails.
The 2nd through 5th lines describe the networking configuration for Jails.  The interface `lo1` has is used to forward traffic to Jails.  The IPs `10.7.0.1` through `10.7.0.3` are used for each jail.  I'll discuss how to set up jails in a couple sections.
The line `skip on $jail_lo` tells PF to not apply blocks to or from the addresses on `lo1`.
The line `nat on $ext_if from $jail_lo to any -> ($ext_if)` tells PF to forward traffic from `lo1` to the outside world.
The next two lines, starting with `rdr`, use nat to forward the port 2222 to port 22 the `$weechat` address and ports 9001 and 9030 to the same ports on the `$onion` interface.
The lines `table <fail2ban> persist` and `block quick proto tcp from <fail2ban> to $ext_if port ssh` are related to the fail2ban configuration I'll discuss next.
The last differences only have to do with the ports that I need to specifically allow or block.

To enable PF, add `pf_enable="YES"` to `/etc/rc.conf` and run `service pf start`.

## fail2ban
This section assumes you've already set up and enabled PF similarly to what I've done above.
fail2ban is used to block traffic from IPs that continuously causes problems, such as failing to log in via SSH.  My configuration is based off the work [here](http://blog.alteroot.org/articles/2014-06-14/fail2ban-on-freebsd.html), but it seems to be a bit out of date.

First, install fail2ban, either with `pkg install py27-fail2ban` or from the port `py-fail2ban`.

Next, create the file `/usr/local/etc/fail2ban/jail.d/ssh-pf.local` and edit it so it reads:
```
[ssh-pf]
enabled  = true
filter   = sshd
action   = pf
logpath  = /var/log/auth.log
findtime  = 600
maxretry = 3
bantime  = 36000
```
You can change `bantime = ...` to the amount of time (in seconds) to ban an IP.  You can use `maxretry = ...` to change the number of failed login attempts before a ban.  You may want to make this higher if you are in the habit of mis-typing your password (although you should be using public key authentication anyways).
The lines `filter = sshd` and `action = pf` tell fail2ban to look at the sshd logs to find failed attempts, and blocks bad IPs with PF.

Third, add the following lines to your `/etc/pf.conf`, either before or after your other table blocks (see PF section above):
```
table <fail2ban> persist
block quick proto tcp from <fail2ban> to $ext_if port ssh
```
This simply blocks all traffic to your server from IPs added by fail2ban.

Finally, to enable fail2ban add `fail2ban_enable="YES"` to `/etc/rc.conf`, and start it with `service fail2ban start`.

## Jails
BSD Jails is often described as "chroot on steroids", or BSD's predecessor to Linux's lxc.  I use it both for security and convenience: security, because if one jail is compromised it is still separate from the main system, and convenience because it keeps my applications logically separate.
I have three jails: one hosting my website, one hosting a tor relay, and one to host weechat (an IRC client).

BDSNow has a [good introduction](http://www.bsdnow.tv/tutorials/jails) to Jails using ezJail.  The only difference between their configuration and mine is the network configuration.  Since I only have one IPv4 address, I cannot give a new address to each Jail.  To fix this, I have to use network address translation (NAT), as mentioned in the PF section previously.

Follow the BSDNow tutorial, but ignore the networking section.  Create a new local interface `lo1` with `ifconfig lo1 create`.  Next, give it an address with `ifconfig lo1 alias 10.7.0.1 netmask 255.255.255.0`.  Repeat this with `10.7.0.2`, `10.7.0.3`, etc for as many jails as you need.
To have this interface created on boot, add the following to `/etc/rc.conf`:
```
cloned_interfaces="lo1"
ifconfig_lo1="inet 10.7.0.254 netmask 255.255.255.0"
ifconfig_lo1_alias0="inet 10.7.0.1 netmask 255.255.255.0"
ifconfig_lo1_alias1="inet 10.7.0.2 netmask 255.255.255.0"
ifconfig_lo1_alias2="inet 10.7.0.3 netmask 255.255.255.0"
```

When creating the Jail, use `ezjail-admin create $(name) 10.7.0.1`, where `$(name)` is the name you wish to assign your jail, and using a different IP for each new Jail.

To actually use these jails from the outside, you need to forward traffic to the jails.  There are two ways to do this: first is using PF to forward specific ports, and second is using a reverse proxy, such as Nginx.

PF simply needs the `rdr ...` lines from my pf.conf above.
Nginx simply needs the `proxy_pass` configuration line for the `location /` block, as described in more detail [here](/security).

<br />

----

Everything else is coming soon.

----
# Email
## Postfix
## Dovecot
## SPF
## DKIM
## Spamd
## Clamav?

----
# Other
## TOR
## IRC
