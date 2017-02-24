+++
date = "2015-03-17T20:24:28-04:00"
draft = false
title = "USB Armory USB mass storage and ethernet"
description = "How to use the USB Armory as both an ethernet device and a USB mass storage device."
meta_title = "USB Armory as both USB mass storage and Ethernet devices."
slug = "armory-mass-storage"
tags = ["toy", "armory", "USB", "storage", "ethernet"]
type = "post"
image = ""

+++

The default image for the USB Armory defaults to using the g_ether driver to provide an ethernet device to the host.  However, that does not give you a USB mass storage device.  The alternative is to `modrpobe -r g_ether` and `modprobe g_mass_storage file=/path/to/block/device`, but that leaves you without ethernet, and thus without a method of communicating with the armory.
<!--more-->

Luckily, Linux also has the g_multi driver, wich does both (as well as an emulated usb serial port, which I'll talk about in a later post).

The g_ether driver gets loaded because of a line in /etc/modules:  
```
# /etc/modules: kernel modules to load at boot time.
#
# This file contains the names of kernel modules that should be loaded
# at boot time, one per line. Lines beginning with "#" are ignored.
# Parameters can be specified after the module name.

ledtrig_heartbeat
ci_hdrc_imx
g_ether use_eem=0 dev_addr=1a:55:89:a2:69:41 host_addr=1a:55:89:a2:69:42
```

We're looking at the last line, which creates the fake ethernet with the device address and host address specified by dev_addr and host_addr.

To use the g_multi driver, change the last time to:  
```
g_multi use_eem=0 dev_addr=1a:55:89:a2:69:41 host_addr=1a:55:89:a2:69:42 file=/root/disk.img
```  
where /root/disk.img is a block device.  You can either use a fake one (just a file on disk) or a real partition (such as /dev/mmcblk0p2).  You can also specify multiple devices separated by a comma (and no space).  You need to reboot to make the change show up.

Have fun with your new ethernet/usb drive computer.  I will update in a while if/when I figure out how to implement some sort of access control on the device you mount.