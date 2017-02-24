+++
date = "2016-03-25T08:00:00-04:00"
draft = false
title = "Apple vs the FBI Part I"
description = "A layperson’s explanation of the Apple vs the FBI case"
image = "/apple.png"
meta_title = "Apple vs the FBI part I: a layperson’s explanation"
slug = "apple-fbi-1"
tags = ["Apple", "FBI", "iPhone", "San Bernadino", "enryption", "privacy",
        "security"]
type = "post"

+++

Introduction and Background
===
This post is an attempt to explain the encryption dispute between Apple and the
FBI. It will provide general background on the whole so-called “security vs
privacy” debate, historical context of how the United States government has
interacted with encryption, and finally talk about the events leading up to and
the actual dispute between Apple and the FBI regarding unlocking an iPhone 5c,
used by one of the San Bernardino shooters.

Since I started writing this post, a lot of new developments have transpired in
the dispute. Most notably, the FBI has decided to drop the case against Apple,
and obtain the information they need through other means. This probably means
they realized they could not possibly win in court, and did not want to risk
losing the power of the All Writs Act of 1789.

Security vs Privacy
---
The government and the media like to set up a dichotomy between privacy and
security, often asking how much we should give up privacy for the sake of
security. They will say this when talking about encryption and other computer
security measures, as an argument for weakening encryption or adding required
back doors.

This, in fact, is a false dichotomy. Security and privacy go hand-in-hand, and
only in the edge cases is there tension between the two. For example, the same
privacy tools that protect your Facebook account also protect your bank account
info. These same privacy tools provide security equally to journalists and
politicians, who rely on encrypted communication to protect themselves and their
employer from adversaries, both foreign or domestic.

Backed doored encryption?
---
Some politicians believe it is possible to create electric security measures
that have a back door that only allows good law enforcement in. I choose to
think that this belief is due to ignorance of technology, not malicious intent
to weaken everybody’s security. Some politicians and reporters have said that we
should not listen to the people who say “good” back doors are impossible,
because if we always listened to people who said something was impossible, when
would humanity every accomplish anything?

However, in this case almost everyone who even vaguely knows what they are
talking about have said safe back doors are impossible.

A (not so) brief interlude on back doors: what some people are advocating is
either some sort of “golden key” or universal code that can decrypt all
encryption, or banning encryption that the US Government does not have the
capability of breaking. The FBI, NSA, or some other “trusted” agency would keep
hold of the key, and only use it to open the back door when it is most needed.
There are a several issues with this. First, if the government bans encryption
they cannot break, they they will have banned encryption that their enemies
cannot break, giving enemies of the United States the ability to read all
encrypted communications from the United States. Second, the idea of a “golden
key” does not work, since as soon as the key becomes widely used it will be
leaked or stolen, rendering all encryption useless.

There is also a practical problem with any restrictions on encryption: it would
be impossible to impose on open source software. There already exists software
that provides strong, unbreakable encryption. Any attempts to weaken this
strength will be immediately noticed and undone.

To conclude my discussion of encryption: back doored encryption is probably
impossible to do correctly, and even legislation could be circumvented by
existing software.

The Clipper Chip
---
Unknown to many, we had this same debate in the 1990s, dubbed the “[Crypto
Wars](https://en.wikipedia.org/wiki/Crypto_Wars)”. An important part of this was
the [Clipper Chip](https://en.wikipedia.org/wiki/Clipper_chip), a chip developed
by the NSA to provide a back door for the US government to cell phone
communications. The idea was that the cell phone encryption would go through the
Clipper Chip, which had a built in back door code that only the NSA knew.
Unfortunately (or fortunately, for many), researchers quickly found multiple
flaws in the design and implementation of the chip (read the Wikipedia page for
more information on those), which was essentially the end of the crypto wars (in
favor of technologists, against the government).

Apple vs the FBI
===
And finally, on to the main show: Apple vs the FBI.

This whole issue started with the [San Bernardino
attack](https://en.wikipedia.org/wiki/2015_San_Bernardino_attack) in December
2015. After the attack, law enforcement found the work phone of one of the
attackers, an iPhone 5c.

The county made a rather large mistake by reseting the iCloud password for the
account associated with this phone, preventing any future iCloud backups until
the phone is unlocked. If they had not done this, law enforcement would only
have to connect the phone to a trusted wifi network (by bringing it within range
of the network), and it would have uploaded all its data to iCloud, where law
enforcement could have accessed the information via a warrant sent to Apple.

However, this was not possible, so the FBI had to find a way to unlock the
phone. Unfortunately for the FBI, the phone was set up to wipe itself if 10
incorrect passcodes are attempted, preventing attempts to brute force the
passcode (that is, trying all of them until one works). They decided to use the
[All Writs Act](https://en.wikipedia.org/wiki/All_Writs_Act) of 1789, which
authorizes US Federal Courts to "issue all writs necessary or appropriate in aid
of their respective jurisdictions and agreeable to the usages and principles of
law”, to obtain a court order to compel Apple to create software that would both
disable the 10 passcode limit and allow the FBI to try passcodes via a USB
connection.

Rather than rolling over and complying, as many companies do, Apple decided to
fight the order in court. This generated quite a bit of publicity, until the FBI
decided to back down, withdraw their case, and claim they found an easier way to
get into the phone.

Easier ways had been suggested since the case first went public, as compelling
Apple to write new software is very heavy handed, and likely illegal. What the
FBI most likely will do is copy the contents of the flash chip, and then either
break the filesystem encryption, or try codes on the phone until it wipes the
data, copy the data back, and then try again. This would take a while, but since
there are only 10,000 4 digit codes, it would only take 1000
attempt-wipe-reload-try again cycles.

The FBI probably could have done that in the beginning (or paid another company
to do so), but they wanted to set a precedent that the government can compel
companies to write code under the All Writs Act.

Why this is bad, in brief
---
While it seems clear to me why the FBI’s request was bad, I should explain for
anyone who has not yet decided. The main arguments are that it sets a precedent,
both domestically and internationally, that tech companies and Apple
specifically can be forced to circumvent their own security measures; it forces
Apple to create software that cannot be uncreated, and will be dangerous in the
future; and that compelling a company to write code violates the first amendment
in the Bill of Rights.

The first two are rather self explanatory. If the US government compels Apple to
write software to disable security features on their phones, however good the
reason, other countries can do the same for less noble purposes. Additionally,
once Apple writes this software, it is out there, and could be leaked to bad
actors.

In 1996, The Ninth Circuit Court of the United States ruled that [code is
speech](https://www.eff.org/deeplinks/2015/04/remembering-case-established-code-speech),
and should be protected under the first amendment. By issuing an order forcing
Apple to write an update for their operating system, the court is in direct
violation of this. This is probably the most damning piece for the government’s
case, considering the importance of the first amendment in American law.

Even ignoring the legal and practical problems with the FBI’s request, there are
also moral difficulties to contend with. These are obvious to anyone who already
has issue with pervasive government surveillance. To anyone else, this is
exactly the kind of precedent the government needs to later unlock the private
data of citizens, journalists, and other politicians. Even in the United States,
the Land of the Free, the government has a habit of spying on
[foreign](http://www.spiegel.de/international/germany/cover-story-how-nsa-spied-on-merkel-cell-phone-from-berlin-embassy-a-930205.html)
and
[domestic](http://www.nytimes.com/2014/08/01/world/senate-intelligence-commitee-cia-interrogation-report.html)
politicians,
[activists](http://www.nytimes.com/2014/11/16/magazine/what-an-uncensored-letter-to-mlk-reveals.html?_r=0),
[and](https://www.eff.org/nsa-spying)
[normal](http://www.huffingtonpost.com/2013/09/27/nsa-spying-exes_n_4002834.html)
[citizens](http://www.vice.com/read/a-brief-history-of-the-united-states-governments-warrentless-spying).
The last thing the government needs is the ability to access sensitive data that
those people specifically worked to keep private.

Responses
---
In response to Apple’s refusal to follow the initial court order, many
politicians have come down on either side. Notably, Senator (and previous
presidential candidate) Lindsey Graham has [switched
sides](https://www.techdirt.com/articles/20160314/09144433899/senator-lindsey-graham-finally-talks-to-tech-experts-switches-side-fbi-v-apple-fight.shtml)
after actually talking to technology experts about the technical details of the
case. Some lawmakers, rather disturbingly, have used this as a reason to call
for limits on encryption and laws requiring back doors.

Conclusion
---
I hope this was a helpful overview of the issues at hand with encryption,
privacy and security, and the encryption dispute between Apple and the FBI.

These questions, which were previously explored in th 1990s, have been thrust
back into public view, and debates are re-igniting over to what extent the
government should regulate technology. After reading this, I hope you are able
to make a more informed opinion on these issues, and see why government
regulation of encryption may be ineffective or even dangerous.

This post was mostly aimed at non-technical users of technology. My next blog
post will likely be a call to arms for technologists to fight against government
limits on encryption and government surveillance.
