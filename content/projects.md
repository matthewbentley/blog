+++
date = "2017-02-19T15:19:09-05:00"
title = "A Short List of Projects"
draft = false
description = "I need a place to list my projects"
tags = ["projects"]
type = "page"

+++

[Duplicity B2 Backend](https://launchpad.net/duplicity)
---
[BackBlaze B2](https://www.backblaze.com/b2/cloud-storage.html) is a reasonably
cheap cloud hosting service. [Duplicity](http://duplicity.nongnu.org/) is
a backup program. When B2 entered beta, I signed up and wrote a backend to use
B2 with duplicity.

The source is [here](https://github.com/matthewbentley/duplicity_b2), but the
backend has been integrated upstream, so any future changes will go there.

According to an email thread with Backblaze’s CEO, it’s one of the most used
open source integrations with B2.

[CWRU ACM Hosting](https://github.com/hacsoc/case-acm-server)
---
A simple hosting service I put together with Docker, Systemd, and Bash. It takes
advantage of weird quirks in how CWRU does networking to assign case.edu
subdomains to sites.

It currently hosts websites for more than 10 student groups.

[git.case.edu](https://git.case.edu)
---
A simple [Gitlab](https://gitlab.org) server for the CWRU campus. Not much else
to see here.

[OX Dashboard](https://github.com/beta-nu-theta-chi/ox-dashboard)
---
Not actually my project, but I have contributed a number of improvements. Rather
than managing our greek life chapter via spreadsheets and email, a brother wrote
a web-app to complete common tasks.

I have contributed miscellaneous code improvements (including login integration
with CWRU Single Sign On) and a new online, email based system to track house
details (chores) and fines.

[Rust CAS](https://github.com/hacsoc/rust-cas)
---
A rust library for integration with CAS, used by CWRU Single Sign On.

[More](https://github.com/matthewbentley?tab=repositories)
---
