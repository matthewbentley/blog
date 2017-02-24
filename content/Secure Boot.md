+++
date = "2016-05-12T11:50:00-04:00"
draft = false
title = "Secure Boot on Arch Linux"
image = ""
description = "How I set up Arch Linux to use UEFI and Secure Boot with my own keys on a Thinkpad"
meta_title = "Arch Linux, Secure Boot, Thinkpad"
slug = "secureboot"
tags = ["secure boot", "arch", "linux", "uefi", "thinkpad"]
type = "post"

+++

[Secure
boot](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface#Secure_boot)
is a part of the relatively new Unified Extensible Firmware Interface
([uefi](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface))
specification that allows verifying the legitimacy of early boot code using
a public key infrastructure. [It has been widely
criticised](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface#Secure_boot_criticism)
due to the fact that it could prevent non-Microsoft-blessed software from
booting if a user cannot change the keys or disable the feature.

I am going to ignore the political issues, and focus on how to use secure boot
to protect the boot process of an Arch Linux system running on a Thinkpad x240.
These instructions will likely work on other hardware with other distributions,
but there will be subtle differences that you have to find (and I take no
responsibility if you don’t and [this](https://xkcd.com/349/) happens).

This will require a few steps:

1. First, get your computer booting with UEFI. I used systemd-boot (formerly
Gummiboot) as a loader, but you can directly boot a signed Linux kernel if you
wish (I am also ignoring the political discussion around systemd for now)
2. Then, create the necessary keys, and install them into the firmware
3. Combine your kernel, initramfs, and kernel boot options into one file
4. Sign the bootloader and kernel(s), and enable secure boot :)
5. Automate everything

UEFI
===
I’m going to gloss over this a bit, since it’s not my main topic today. [The
Arch Linux wiki](https://wiki.archlinux.org/index.php/UEFI) has some good
information to start.

Before starting, you should probably be using GPT. This might work with MBR, but
I can’t promise anything.

First, you will need to install systemd-boot as your default boot loader:
`bootctl install`. I have my ESP mounted at /boot, so if you have it mounted
elsewhere (say, `/boot/efi`), you will need to do `bootctl --path=/boot/efi/
install`.

The configuration format for systemd-boot is described
[here](https://wiki.archlinux.org/index.php/Systemd-boot#Configuration).
Generally, you will want:

`/boot/loader/loader.conf`:
```
default  arch
timeout  4
editor   0
```
and `/boot/loader/entries/arch.conf`:
```
title          Arch Linux
linux          /vmlinuz-linux
initrd         /initramfs-linux.img
options        root=PARTUUID=14420948-2cea-4de7-b042-40f67c618660 rw
```

Adjust the paths as needed (ie, you might need `/boot/efi/loader/loader.conf`
and `/boot/efi/loader/entries/arch.conf`). You will need the kernel and
initramfs to be in the root of your esp, however, so you can either just mount
your ESP at /boot, or you will need to set up some sort of script to copy the
kernel and initramfs after install (look into systemd `.path` files).

Keys
===
I’m going to skip the theory, and move right to the process. If you are
interested in how secure boot works, start
[here](http://www.rodsbooks.com/efi-bootloaders/index.html) and especially look
[here](http://www.rodsbooks.com/efi-bootloaders/controlling-sb.html).

Generate the keys
---
I recommend doing this in a secure location on your main filesystem, such as
`/root/keys`.

At this point, you will need to install `sbsigntools` and `efitools` from the
AUR.

Use this script to generate the keys:
`mkkeys.sh`:
```
#!/bin/bash

echo -n "Enter a Common Name to embed in the keys: "
read NAME

openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME PK/" -keyout PK.key \
        -out PK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME KEK/" -keyout KEK.key \
        -out KEK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME DB/" -keyout DB.key \
        -out DB.crt -days 3650 -nodes -sha256
openssl x509 -in PK.crt -out PK.cer -outform DER
openssl x509 -in KEK.crt -out KEK.cer -outform DER
openssl x509 -in DB.crt -out DB.cer -outform DER

GUID=`python2 -c 'import uuid; print str(uuid.uuid1())'`
echo $GUID > myGUID.txt

cert-to-efi-sig-list -g $GUID PK.crt PK.esl
cert-to-efi-sig-list -g $GUID KEK.crt KEK.esl
cert-to-efi-sig-list -g $GUID DB.crt DB.esl
rm -f noPK.esl
touch noPK.esl

sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK noPK.esl noPK.auth

chmod 0600 *.key

echo ""
echo ""
echo "For use with KeyTool, copy the *.auth and *.esl files to a FAT USB"
echo "flash drive or to your EFI System Partition (ESP)."
echo "For use with most UEFIs' built-in key managers, copy the *.cer files."
echo ""
```
(Source
[here](http://www.rodsbooks.com/efi-bootloaders/controlling-sb.html#creatingkeys)).

Copy the `.cer`, `.esl`, and `.auth` files to a FAT32 filesystem that will be
accessible to the bootloader (I justed used my ESP, aka `/boot`).

Install the keys
---
Next, you will need to put your motherboard into secure boot setup mode. To do
this on a Thinkpad x240, boot into setup (press F1 at the splash screen), toggle
over to “Security” (right arrow key), toggle down to “Secure Boot” (down arrow
key), select it (enter), go down to “Reset to Setup Mode”, and hit enter. Now,
hit escape to go back, scroll over to “Reboot”, select “Exit Saving Changes”,
and hit “Yes”.

You are now ready to use `KeyTool` to install the keys. Copy
`/usr/share/efitools/efi/KeyTool.efi` to your ESP (ie, into `/boot`), and boot
from it. The easiest way to do this is create the following loader entry:

`/boot/loader/entries/keytool.conf`:
```
title  KeyTool
efi    /KeyTool.efi
```

Now you can boot into the KeyTool entry, and you’re ready to replace the keys!

On the KeyTool main menu, you have the option to save the existing keys.
I didn’t do this, but it’s probably a good idea to do.

After you do or don’t do that, select “Edit Keys” and hit enter, which will
bring you to the edit keys page.

Next, delete the db and KEK keys. Start by selecting the “db” entry, selecting
the first key, and hitting “delete”. Repeat this for each db and KEK key.

You can also do this for dbx keys (which act as a blacklist), but that’s not as
important. If you have any Mok keys, you should probably also delete those.

Now, you need to add your keys, in the order db, KEK, and then PK.

To add a db key, select the db entry, hit “Add New Key”, select the device with
your `cer`, `esl`, and `auth` files, navigate to the files, and select the
`DB.esl` file. Repeat this for the KEK with `KEK.esl`.

Finally, add your platform key. Select “The Platform Key (PK)”, select “Replace
Key(s)”, navigate to `PK.auth`, and select it. You can now exit the KeyTool
menus.

Combine the kernel, initramfs, and boot options
===
This part took me the longest to figure out. For secure boot to be effective, we
will need to combine the kernel, initramfs, and boot options into a single file,
sign that file, and then use it to boot.

If we didn’t do this, and only signed the kernel, an attacker could modify the
initramfs or kernel command line options, making secure boot useless.

To do this, we need the initramfs to be an uncompressed cpio archive. You can
just `gunzip` an initramfs file in `/boot`, but I would recommend editing
`/etc/mkinitcpio.conf` so that `COMPRESSION=”cat”` is present at the end (and
other `COMPRESSION=` options are commented out). This is to help automate
everything later.

Now, take your kernel (`/boot/vmlinuz-linux`), your initramfs
(`/boot/initramfs-linux.img`), and a text file containing your boot command line
(`cat /proc/cmdline > cmdline.txt`), and put them in one folder (eg
`/tmp/boot`).

You will use `objcopy` to put these files into one image:
```
objcopy \
    --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="cmdline.txt" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="vmlinuz-linux" --change-section-vma .linux=0x40000 \
    --add-section .initrd="initramfs-linux.img" --change-section-vma .initrd=0x3000000 \
    /usr/lib/systemd/boot/efi/linuxx64.efi.stub kernel.efi
```

You will now have a `kernel.efi` file! This will boot as an efi application.

You can test this by copying it to `/boot` (or your ESP), and adding the
following loader entry:

`/boot/loader/entries/test.conf`:
```
title  Linux EFI Test
efi    /kernel.efi
```

If it works, great! We’re ready to sign it and enable secure boot!

Signing things
===
Signing an efi application is really easy, you just need the `DB.key` and
`DB.crt` files created earlier.

```
cd /boot
sbsign --key /root/keys/DB.key --cert /root/keys/DB.crt --output kernel.efi kernel.efi
```

That’s it. It signs `kernel.efi` and outputs the signed file to `kernel.efi`.

You will also need to sign the systemd-boot bootloader, with
```
cd /boot/EFI/systemd/
sudo sbsign --key /root/keys/DB.key --cert /root/keys/DB.crt --output systemd-bootx64.efi systemd-bootx64.efi
```

Note that systemd-boot will check the signatures on any efi application it tries
to load and run, so you will need to sign systemd-bootx64.efi and every kernel
you try to boot.

You’re now ready to enable secure boot and test it.

Enable secure boot
---
Boot into setup (F1 on the splash screen), go over to “Security”, down to
“Secure Boot”, select it, select “Secure Boot”, scroll to “[Enabled]”, and hit
enter. This may prompt you to automatically update some other settings, such as
disabling legacy mode boot. Then, hit escape to go back, scroll right to
“Reboot”, select “Exit Saving Changes”, and hit “Yes”.

Secure boot is now enabled, and you’ll get a nasty error if you try to boot an
non-signed kernel or bootloader. Note that this includes things like live CDs,
so you’ll need to either sign those or turn off secure boot to boot those.
(Note: in theory, you could install Canonical’s db key, which would allow you to
boot recent Ubuntu releases, or Microsoft’s db key, which would allow you to
boot anything signed with that. Doing so is left as an exercise to the reader.)

Automate it
===
(Note: from here on out, this is very Arch Linux specific. But have fun if you
want to try with another distro!)

This is all fine and good, except when you need to update your kernel. If you
forget to combine everything and sign it after the upgrade, you’ll be stuck with
an old version of the kernel booting from `kernel.efi`. To fix this, I wrote
a script and a pacman hook to automatically rebuild and re-sign kernel
updates.

The script supports multiple kernels. It doesn’t create loader entries, so you
will need to do that yourself.

I placed this script in `/root/secure-boot`, but feel free to change that (just
be careful going forward).

`/root/secure-boot/make-sign-image.sh`:
```
#!/bin/bash

FILE=$(echo $1 | sed 's/boot\///')
BOOTDIR=/boot
CERTDIR=/root/keys
KERNEL=$1
INITRAMFS="/boot/intel-ucode.img /boot/initramfs-$(echo $FILE | sed 's/vmlinuz-//').img"
EFISTUB=/usr/lib/systemd/boot/efi/linuxx64.efi.stub
BUILDDIR=_build
OUTIMG=/boot/$(echo $FILE | sed 's/vmlinuz-//').img
CMDLINE=/etc/cmdline

mkdir -p $BUILDDIR

cat ${INITRAMFS} > ${BUILDDIR}/initramfs.img

/usr/bin/objcopy \
    --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
    --add-section .cmdline=${CMDLINE} --change-section-vma .cmdline=0x30000 \
    --add-section .linux=${KERNEL} --change-section-vma .linux=0x40000 \
    --add-section .initrd=${BUILDDIR}/initramfs.img --change-section-vma .initrd=0x3000000 \
    ${EFISTUB} ${BUILDDIR}/combined-boot.efi

/usr/bin/sbsign --key ${CERTDIR}/DB.key --cert ${CERTDIR}/DB.crt --output ${BUILDDIR}/combined-boot-signed.efi ${BUILDDIR}/combined-boot.efi

cp ${BUILDDIR}/combined-boot-signed.efi ${OUTIMG}
```

This also adds the `intel-ucode.img` image, for Intel microcode updates. You may
want to change the `INITRAMFS=` line if you don’t have a `/boot/intel-ucode.img`
file.

You will need to create the file `/etc/cmdline`, which contains your command
line options. For reference, mine looks like this:

`/etc/cmdline`:
```
root=/dev/mapper/root md=0,/dev/sda2,/dev/sdb2 cryptdevice=/dev/md0:root:allow-discards rw i915.semaphores=1 pcie_aspm=force i915.i915_enable_rc6=7 i915.i915_enable_fbc=1 i915.lvds_downclock=1 quiet
```

To run this script, change to `/`, and then run it as root with
`boot/vmlinuz-linux` as the first (and only) parameter:
```
cd /
/root/secure-boot/make-sign-image.sh boot/vmlinuz-linux
```
It feels like you’re jumping through hoops to run it manually, but it’s
necessary to make it work with pacman.

And finally, create `/etc/pacman.d/hooks/` if it doesn’t already exist, and
create the following hook:

`/etc/pacman.d/hooks/secure-boot.hook`:
```
[Trigger]
Operation = Install
Operation = Upgrade
Type = File
Target = boot/vmlinuz-*

[Action]
When = PostTransaction
Exec = /bin/sh -c 'while read -r f; do /root/secure-boot/make-sign-image.sh "$f"; done'
NeedsTargets
```
TL;DR: when a package updates a file matching `boot/vmlinuz-*`, run the
`make-sign-image.sh` script with that file name as the parameter (the `while
read` stuff is in case you install or upgrade multiple kernels at once).

(Hooks are described [here](https://www.archlinux.org/pacman/alpm-hooks.5.html)
or in `man 5 alpm-hooks`)

For each kernel that you install or upgrade, you will now get
a `/boot/linux-something.img` file!

You can test this by reinstalling linux: `pacman -S linux`. It should
automagically create a file named `/boot/linux.img`.

You can add this to your bootloader by creating the following loader conf file:

`/boot/loader/entries/linux.conf`:
```
title  Linux
efi    /linux.img
```

Rinse and repeat for any kernel you install (I currently have `grsec.conf`,
`linux.conf`, `lts.conf`, and `mainline.conf`, which should be pretty self
explanatory).

That is the end, there is no more
===
I might write more in the future about other secure boot considerations (ie,
detecting if it’s enabled), but for now that’s it.  Have fun with your new sense
of security in your boot process!

As always, if you have questions feel free to email me at
[matthew@bentley.link](mailto:matthew@bentley.link).
