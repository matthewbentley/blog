+++
date = "2015-03-18T13:02:22-04:00"
draft = false
title = "USB Armory LED Control"
description = "How to control the USB Armory LED in Linux."
slug = "armory-led"
meta_title = "Control the USB Armory LED"
tags = ["armory", "USB", "LED", "control"]
type = "post"
image = ""

+++

The USB Armory comes with a nice little LED on board.  In the default Debian image, it is set up to blink based on CPU usage.  To control it manually, take the following steps:
<!--more-->

Unload the `ledtrig_heartbeat` kernel module:
```
#> modprobe -r ledtrig_heartbeat
```

Turn it off:
```
#> echo 1 > /sys/class/leds/LED/brightness
```

Turn it on:
```
#> echo 0 > /sys/class/leds/LED/brightness
```

If you want to set it to half brightness (this is apparently a bit of a hack):
```
#> modprobe -r leds_gpio
#> echo 123 > /sys/class/gpio/export
#> echo in > /sys/class/gpio/gpio123/direction
```

Once you've unloaded `leds_gpio`, to control the LED:
```
#> echo out > /sys/class/gpio/gpio123/direction
```
to turn it to full brightness, and
```
#> echo 1 > /sys/class/gpio/gpio123/value
```
to turn it off, and finally
```
#> echo 0 > /sys/class/gpio/gpio123/value
```
to turn it on.

And last off, to blink it really quickly:
```
#> while [[ 1 ]]; do
    echo 0 > /sys/class/gpio/gpio123/value
    echo 1 > /sys/class/gpio/gpio123/value
    sleep 0.05
done
```
I take no responsibility if doing that damages your LED.