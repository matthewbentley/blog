---
title: "Owning My Linksys Router"
date: 2018-01-10T00:08:31-05:00
draft: false
image: ""
description: "How I got local root access on my modern linkssy router without flashing new firmware, a proof of concept"
slug: router-hacking
tags: ["linksys", "router", "exploit", "root", "pwn"]
type: "post"
meta_title: "Local exploit of my new Linksys router"
---

(skip to after Disclaimer if you just want the technical details)

When I arived home for my month-long winter break, I realized my parents had a
problem: their two year old wireless-N router couldn't quite handle the up to 20+
devices they and my siblings would have connected in the evenings.  It was an
Asus rt-n66u, which I had been quite happy with, but it just couldn't keep up,
and anyways it only supported wireless-N and wireless-AC is the New Cool Thing™.
I decided to try a modern Linksys router, given my fond memories of the
[wrt54g](https://en.wikipedia.org/wiki/Linksys_WRT54G_series), and settled on
the [ea8300](https://www.linksys.com/us/p/P-EA8300/) for its quad core CPU and
two channels of 5ghz (and of course one of 2.4ghz).

Unfortunately, its firmware tries to be user friendly, and thus fails to be user
friendly to power users (myself) or to be simple for most other users (my
parents).  It checks all the boxes: IPv6, DLNA media streaming and FTP via an
external USB device, DDNS support, and a bit more, but my big problems are the
interface is a pain and it isn't supported by dd-wrt/openWRT/LEDE/Tomato/etc.  
At least Asus routers have [Asuswrt-merlin](http://asuswrt.lostrealm.ca/) if you
want features like Tor support or a root SSH shell.

So, I decided to see if I could "hack" it to run my own programs.

Disclaimer
===
I will be describing a method to gain local root code execution on a modern
Linksys router (well, I assume it'd work with other models, but I haven't tested
it).  I don't think it is a Real Problem™ worthy of responsible disclosure to
Linksys, since it requries physical access and admin access, with which one
could already flash malicious firmware.  And more importantly, I hope it doesn't
get fixed, so I can continue to use it (and recieve normal security updates).

Also, I take no repsonsibility if you brick your router, anger the FCC, cause
the downfall of western civilization, or anything else positive or negative
comes from reading this post.

Dead Ends
===

Flashing New Firmware
---
My first though was to simply download a firmware update, modify it, and flash
it via normal procedures.  I spent about an hour trying to reverse engineer the
file format (the `binwalk` tool, which I'll talk about later, was useful for
this), but to no success.  I'm sure given more time I could figure it out, but I
decided to move on to other options.

Also, I have too many memories of spending all night trying to fix a bricked
wrt54g, so I'd rather not mess with flashing firmware.

Code injection via the web UI
---
The web UI has `ping` and `traceroute` features.  I thought it might just do
`sh -c 'ping $server'` if you entered `$server` into the UI; unfortunately it
seems the firmware validates the input, and something like `8.8.8.8; ls` or
`8.8.8.8&&ls` doesn't work.

Results
===

Interlude: external drives and some research
---
The firmware supportes DLNA media streaming, FTP, and samba on a external drive
if plugged in to the USB port.  This will be important soon.

I decided to research vulnurabilities for the Linksys ea8300, and found the
page `http://192.168.1.1/sysinfo.cgi` (I can't find the original source, so if
you know it please let me know!).  It contains a bunch of information, some of
which will become useful.

Backup/restore
---
Next, I looked for other possible sources for script injection (having crossed
out firmware updates and ping/traceroute).  The restore half of backup/restore
looked interesting. I downloaded a backup, which came if the form of a file
called `backup.cfg`.  `file` didn't know what to think of it, so I tried
`binwalk` ("...a tool for searching a given binary image for embedded files and
executable code...", see [binwalk.org](http://binwalk.org/)).  I had much more
luck here than with the firmware image, since it found a gzip archive at byte
13.  I extracted it with `dd if=backup.cfg bs=1 count=13 of=backup.gz`, and then
extraced the gzip (which turned out to be a gzip'd tarball) with `tar xf backup.gz`.
This resulted in two files: `tmp` and `var`.  `var` looked to contain state
information about devices it has seen, while `tmp` contained `syscfg.tmp`.
The `syscfg.tmp` file seems to be a list of null terminated `key=value` pairs
(ie `key=value\0`).  I found the easiest way to look though this was
`cat syscfg.tmp | sed 's/\x00/\n/g' | sort`.

The lines that stood out were `guardian_register_sh=/etc/guardian/register.sh`
and `guardian_unregister_sh=/etc/guardian/unregister.sh`.  These seem to be
paths to scripts that the router will run.  A good start!

Next we need some way to add our own script.  Luckily, the `sysinfo.cgi` page
tells us that the external drive is mounted at `/tmp/sda1`.  Maybe I can put a
script there and point the register script at it? (Note that I still don't know
what the guardian register/unregister scripts do.)  So, I did
`sed -i 's#/register\.sh#/../../tmp/sda1/register.sh#' syscfg.tmp`, to change
`/etc/guardian/register.sh` to `/etc/guardian/../../tmp/sda1/register.sh`.
Then to re-tar-gz the files, and create a file with the first 13 bytes from the
original backup followed by the new gzip.

I tried to use the restore UI function with the new file, but got a error about
a wrong file size...hmm...if it's complaining about the size, the size must be
mentioned somewhere in the file.  So I looked at those 13 bytes (
`dd if=backup.cfg bs=1 count=13 | hexdump -C`), which was "0x0002\n11107\n"
(ASCII).  Well, it turns out the 11107 is the size of the gzip, in bytes.  So I
updated that to the new file size, and retried.  The restore worked!

The script
---
The original script that I put at `/register.sh` on the external drive looked
something like this:

```
#!/bin/sh

if [[ -f /tmp/FLAG ]]; then
    exit
else
    # Make sure this only runs once
    touch /tmp/FLAG
    # Note that this will include the contents of /tmp/sda1, so don't put too much here!
    tar cf /tmp/sda1/all.tar / --exclude proc --exclude sys --exclude dev
fi
```

I plugged in the external drive, rebooted the router, mounted the router's
external drive via samba...and found an `all.tar` file!  It worked!

I have a method to execute arbitrary scripts (as root) on the router.

Next steps
===
I didn't actually make it much further than that.  Some investigation showed the
router is running a ARM chip with uclibc.  I combiled a static dropbear binary
for arm (instructions from [here](http://wiki.beyondlogic.org/index.php?title=Cross_Compiling_BusyBox_for_ARM),
just do the `make` step as `make STATIC=1`).

Unfortunately, I ran into authentication problems (PAM maybe?) when trying to
log in via SSH, and soon ran out of time.  

Conclusion
===
Have fun runing arbitrary code on your router :).  I probably won't check the
comments very often, so feel free to email me at
[matthew@bentley.link](mailto:matthew@bentley.link) with questions/comments/snide
remarks.  Or follow me on twitter [@matteotom](https://twitter.com/matteotom).
