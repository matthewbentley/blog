{
    "date": "2015-01-05",
    "description": "This site is made with ghost, running in the ghost docker image behind nginx on an Ubuntu Digital Ocean droplet.",
    "draft": false,
    "id": 8,
    "image": "",
    "meta_title": "About this blog - how the site works",
    "slug": "about-this-blog",
    "tags": [
        "about",
        "Javascript",
        "code"
    ],
    "title": "About this blog",
    "type": "post"
}


Since this will partially be a technical blog, I want to spend some time talking about this blog.  I wrote an overview for the [about](/# about) page, so go there if you want a really quick overview.
<!--more-->

This site is made with [ghost](https://ghost.org/), ~~running in the [ghost docker image](https://registry.hub.docker.com/u/dockerfile/ghost/) behind nginx on an Ubuntu [DigitalOcean](https://www.digitalocean.com/?refcode=1f1c0bb1c4c6) droplet.~~  Actually, now it's runnnig on FreeBSD on a [DigitalOcean](https://www.digitalocean.com/?refcode=1f1c0bb1c4c6) droplet, where I am slowly moving all of my services.

~~The first thing you might notice is that the pages are reload-free.  This is built into the theme I'm using, [Pixeltraveller](https://github.com/Skepton/Pixeltraveller).  Naturally, I [forked](https://github.com/matthewbentley/Pixeltraveller-Plus) the theme to modify it, and completely re-wrote parts of it.  The biggest change is that I re-wrote the no-reload code, so that it now uses [History.js](https://github.com/browserstate/history.js) rather than `onHashChange()`.  It also works well without javascript, unlike the original, and is more SEO friendly.~~  

This blog now uses [Hugo](https://github.com/spf13/hugo), a static site generator.  It is still hosted on DigitalOcean with FreeBSD.  The Hugo theme is [here](https://github.com/matthewbentley/vienna).

-----
The top image is from the Seattle-Bainbridge ferry, taken some time in the Spring of 2014.

As I state in the about page, unless otherwise stated, all images and writing are copyrighted under the [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/), and all code (including ghost and this theme) is under the [MIT license](http://matthew.mit-license.org/).