+++
date = "2015-03-18T13:29:09-04:00"
draft = false
title = "Ghost 2 Hugo"
description = "A Python script to help you move from Ghost to Hugo."
meta_title = "Migrate from Ghost to Hugo"
image = ""
slug = "ghost2hugo"
tags = ["ghost", "hugo", "python", "migrate"]
type = "post"

+++

As my very few readers may have noticed, I recently changed the theme of this blog.  At the same time, I also switched from [Ghost](https://ghost.org/) to [Hugo](http://gohugo.io).  Here is the Python script I developed to migrate my ghost database to Hugo:
<!--more-->

```python3
#!/usr/bin/python3

import sqlite3
import json
from datetime import datetime


conn = sqlite3.connect('ghost.db')
conn.row_factory = sqlite3.Row

c = conn.cursor()
c2 = conn.cursor()

l = []

for i in c.execute('''
SELECT id, title, meta_description as description, slug, markdown as text,
status as draft, page, meta_title, image,
DATE(published_at/1000, "unixepoch") as date,
DATE(created_at/1000, "unixepoch") as date2
FROM posts'''):
    g = {i.keys()[e]: tuple(i)[e] for e in range(len(i.keys()))}
    t = (i['id'],)
    g['tags'] = [e['name'] for e in c2.execute('''
SELECT t.name FROM posts_tags pt JOIN tags t ON pt.tag_id = t.id
WHERE pt.post_id=?''', t)]

    if g['date'] == None:
        g['date'] = g['date2']
    if g['draft'] == 'published':
        g['draft'] = False
    else:
        g['draft'] = True
    g.pop('date2')
    text = g.pop('text')
    text = text.replace("# ", "#")
    text = text.replace("#", "# ")
    text = text.replace("# # # ", "### ")
    text = text.replace("# # ", "## ")
    text = text.replace("\# ", "\#")
    if g['page'] == True:
        page = 'page'
    else:
        page = 'post'
    g['type'] = page
    g.pop('page')
    f = open("./content/%s.md" % (g['title']), "w")
    f.write(json.dumps(g, sort_keys=True, indent=4, separators=(',', ': ')))
    f.write('\n\n\n')
    f.write(text)
    f.close()
```
Note that this expects your ghost database to be a sqlite3 database called ghost.db, in the same directory as the script.

This is on [github](https://github.com/matthewbentley/ghost2hugo), in case you want to fork it and submit a pull request.

It is not perfect, and contains a hack to take into account the fact that ghost allows a header to start with just "#", while hugo expects "# " (a space after the hash).  This will only fix up to three #s.

There are also a number of other differences between ghost and hugo that you may have to account for manually.  You can also check out my [fork of the Vienna theme](https://github.com/matthewbentley/vienna).  Finally, you may want to use your web server to redirect /rss and /feed to /index.xml.
