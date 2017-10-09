---
title: "Serverless"
date: 2017-10-09T17:34:41-04:00
draft: false
title: This blog is serverless!
image: ""
meta_title: Out with servers, in with lambda
description: Running the blog on r53, s3, cloudfront, lambda, and dynamodb
slug: serverless
tags:
 - serverless
 - aws
 - lambda
 - s3
 - route 53
 - dynamodb
type: post
---

As most of you probably haven't noticed, this blog is no longer running on a
DigitalOcean dropplet, but "serverless" on AWS.  Here are all the pieces needed
to make it work.

Note that I've taken a ton of inspiration from Stephen Brennan's [blog
post](https://brennan.io/2016/09/27/hello-https/) about the same subject.

Route 53
===
This part is pretty straight forward.  I moved my dns to Route 53, copied the
old records from bentley.link, and copied the same settings to bentley.blog
(making sure to keep the right email setup).  The A and AAAA records for
bentley.link, bentley.blog, www.bentley.link, and www.bentley.blog were
directed to a CloudFront distribution (which we'll talk about in a minute).

AWS Certificate Manager
===
Again, pretty straigt forward: I used certificate manager to create a cert for
[bentley.link, bentley.blog, www.bentley.link, www.bentley.blog].  Verifying
these was really easy: they just sent an email to the admin address and I
clicked a link to verify them.  One thing to note here is that it might take a
few minutes (up to an hour maybe? I didn't keep track) before the key is ready
to use in CloudFront.

S3
===
Again: easy.  I use [hugo](https://gohugo.io/) to generate a static site, so it
wasn't much effort to use
[s3_website](https://github.com/laurilehmijoki/s3_website) to automatically
upload it to s3.  I don't yet have automation (aka travis-ci) built around
this, but that's planned for the future.  To follow best practices, I created
an AWS IAM user that only has permissions to use s3, and use the keypair from
that user.  In the future I will lock this down more to only have access to
list from and upload to the one bucket that matters.

CloudFront
===
This is the first intersting part.  I would like to have more automation around
this, but in reality I just manually created a CF Distribution and pointed the
only origin at the URL of my s3 bucket.  I set up the CNAMEs to be the domains
on the certificate I created, set the SSL cert to the one I created, and
redirected all http to https.

CloudFront allows associating AWS Lambda functions (via lambda@edge) with
different points in the lifecycle of a request.  Your options are: Viewer
Request, which triggers after the user's request hits CF; Origin Request, which
triggers before CF makes a request to your backend (in my case S3); Origin
Response, which triggers after the origin responds with content; and Viewer
Response, which triggers before returning the content to the user.  All of
these have rather strict resource limitations (listed
[here](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-requirements-limits.html)),
so it takes some creativity to do real things with it.

Initially, I use lambda@edge to add headers to outgoing requests, specifially
around security and TLS.  This function is associated with the the
"viewer-response" of my CF Distribution:

```
'use strict';

exports.handler = (event, context, callback) => {
    const response = event.Records[0].cf.response;
    const headers = response.headers;

    headers['Strict-Transport-Security'] = [{
        "key": "Strict-Transport-Security",
        "value": "max-age=31536000; includeSubdomains; preload",
    }];
    headers['X-Content-Type-Options']    = [{
        "key": "X-Content-Type-Options",
        "value": "nosniff",
    }];
    headers['X-Frame-Options']           = [{
        "key": "X-Frame-Options",
        "value": "SAMEORIGIN",
    }];
    headers['X-XSS-Protection']          = [{
        "key": "X-XSS-Protection",
        "value": "1; mode=block",
    }];

    callback(null, response);
};
```

These headers were copied directly from my old nginx config on my DigitalOcean
server.  Note that to acutally use a function you will need an IAM Role (which
lambda will offer to create for you), and to save your code as a numbered
version.

These lambda@edge functions can also access the AWS API, such as the API for
dynamodb.  As such, I thought I'd do something a bit more compilicated with
it...

Introducing Comments!
===
As you probably haven't noticed, this blog now supports comments!  But how? you
might ask.  I thought this blog was serverless?

Well it is.  But I learned Javasript to give you the ability to argue with each
other in the comment section.

Essentially, I created a dynamodb table, and set up lambda functions to read
from and write to it.

First, you need a dynamodb table.  I recomment using a partition key called
"page" of type "string", and a primary sort key called "ts" ("timestamp" is a
reserved word in dynamodb) of type "number". I called it
"bentley-link-comments".

Next, you need the actual lambda function.  This will do two things: on POST,
it will add a comment to the DB, and on GET it will get all the comments
associated with a page (I use page to refer to a blog post to avoid confusion
with an HTTP POST).

There were some difficulties here.  First, it seemed impossible to fit a query
(put or get) into the 1s time limit of a Viewer {Request,Response} function,
but they seem to fit in the 3s of Origin {Request,Reponse}.  So, the funciton
will run on Origin Request, intercept it, do its stuff, and just return the
result (without actually going to the origin).

Second, POSTs to a lambda@edge function don't seem to actually contain the POST
data, so I took the extreme step of URL encoding everything and sticking it in
headers (!).

Finally, this function will also need permissions to read from and write to the
db, so we need to create a new IAM policy that will be associated with the role
used for the function.  The contents of the policy I am using are:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:*",
                "dax:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "iam:PassRole"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "application-autoscaling.amazonaws.com",
                        "dax.amazonaws.com"
                    ]
                }
            }
        }
    ]
}
```
Create a policy with that as the contents, and then attach that to the IAM role
you will create for the function.

This is probably more that what is needed, so in the future I will try to slim
it down to only be able to read from and write to the needed db (and nothing
else).

Next: the actual function.  It's pretty simple: on POST, it calculates a
timestamp, does some validation, and then adds the comment to the DB; on GET it
just queries the DB and lets the client deal with parsing it.

(I've commented it to hopefully add some idea of what's happening)
```
'use strict';

// setup the AWS API
var AWS = require('aws-sdk');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context, callback) => {
    // Function we will call to finish; it just sets up a response and sends it
    var end = (resp) => {
        const response = {
            status: '200',
            statusDescription: 'OK',
            headers: {
                vary: [{
                    key: 'Vary',
                    value: '*',
                }],
                'last-modified': [{
                    key: 'Last-Modified',
                    value: '2017-01-13',
                }],
                'Content-Type': [{
                    key: 'Content-Type',
                    value: 'application/json',
                }],
            },
            body: JSON.stringify(resp),
        };

        callback(null, response);
    }

    const cf = event.Records[0].cf;
    console.log(cf);
    const url = cf.request.uri.split('/');
    // This will only do anything if the path is "/comment/..."
    //  otherwise, just call the callback to take the default action.
    if (url[1] != 'comment') {
        return callback(null, cf.request);
    }

    var ddb = new AWS.DynamoDB({apiVersion: '2012-10-08'});
    var time = Date.now();

    // POSTing a new comment
    if (cf.request.method == 'POST') {
        var missing = new Array();
        var name = cf.request.headers['x-comment-name'];
        if (name === undefined || name[0]['value'] === "") {
            missing.push('name');
        } else {
            name = name[0]['value'];
        }
        var website = cf.request.headers['x-comment-website'];
        if (website === undefined || website[0]['value'] === "") {
            website = 'null';
        } else {
            website = website[0]['value'];
        }
        var page = url[2];
        var comment = cf.request.headers['x-comment-comment'];
        console.log(comment);
        if (comment === undefined || comment[0]['value'] === "") {
            missing.push('comment');
        } else {
            comment = comment[0]['value'];
        }
        console.log(missing);
        // If missing the name or comment, return an error
        if (missing.length != 0) {
            end({'result': 'error', 'reason': `missing fields: ${missing}`});
        }
        // Build the putitem object for ddb
        var params = {
          TableName: 'bentley-link-comments',
          Item: {
            'ts' : {N: time.toString()},
            'name' : {S: name},
            'comment': {S: comment},
            'page': {S: page},
            'website': {S: website},
          },
          ConditionExpression: 'attribute_not_exists(ts)'
        };
        console.log(params);

        // Call DynamoDB to add the item to the table
        ddb.putItem(params, function(err, data) {
          if (err) {
            //console.log("Error", err);
            end({result: "error", reason: err});
          } else {
            //console.log("Success", data);
            end({result: "ok", reason: data});
          }
        });
    // IT'S A GET, get a comment
    } else if (cf.request.method == 'GET') {
        // The query to send to ddb
        var params = {
            ExpressionAttributeValues: {
                ":v1": {
                    S: url[2]
                }
            },
            KeyConditionExpression: `page = :v1`,
            TableName: "bentley-link-comments"
        };

        console.log(params);
        ddb.query(params, function(err, data) {
            if (err) {
                end({result: "error", reason: err});
            } else {
                end(data);
            }
        });
    }
};
```

Add that as a new fucntion, save it, add the previously mentioned policy to the
new role, and associate the function with Origin Request on your CF
Distribution.

Now that we have a backend with an API, we need to add it to the frontend.  We
will use Javascript to dynamically load and display comments, and add new
comments.

I have written about 12 lines of production JS in my life, so please excuse the
^C^V'd together mess that follows.

Since this part is tied in with my whole blog, I'll just show the relevant
parts of HTML+JS and leave out the CSS as an exercise to the reader.

```
  <section>
    <div id="comments">
    </div>
    <div id="submit-comments">
      <h2>Add a comment</h2>
      <div id="submit-error" class="submit-error"></div>
      <form id="submit-form" title="">
        Name:<br /><input id="submit-name" name="name" type="text" /><br />
        Website (optional):<br /><input id="submit-website" name="website" type="text" /><br />
        Comment:<br /><textarea id="submit-comment" name="comment"></textarea><br />

        <input type="submit" id="submit-button" />
      </form>
    </div>
    <script type="text/javascript">
      var renderComments = () => {
        const article = window.location.pathname.split('/')[1];
        var a = $.get(`/comment/${article}/`, function(data, err) {
          console.log(data, err);

          var c = $('#comments')[0];
          c.innerHTML = "";

          var comments = data.Items;
            
          if (comments.length != 0) {
              c.innerHTML += `<h1>Comments</h1>`;
          }

          for (var i in comments) {
            var com = comments[i];
            const body = $('<div/>').text(decodeURI(com.comment.S)).html().replace(/\n/g, '<br />');
            const name = $('<div/>').text(com.name.S).html();
            const date = $('<div/>').text(new Date(parseInt(com.ts.N))).html();
            var website = $('<div/>').text(com.website.S).html();
            if (!website.startsWith('http') && website !== 'null') {
              website = "http://" + website;
            }
            var toAdd = `<div class="one-comment"><div class="comment-name">`;
            if (website !== 'null') {
              toAdd += `<a href="${website}">`;
            }
            toAdd += `${name}`;
            if (website !== 'null') {
              toAdd += `</a>`;
            }
              toAdd += `</div><div class="comment-time">${date}</div><div class="comment-body"><p>${body}</p></div></div>`;
            c.innerHTML += toAdd;
          }
        });
      };
      renderComments();
      var formEnabled = true;
      var submitForm = (event) => {
        if (!formEnabled) {
          return false;
        }
        var form = $(this);
        console.log(form);
        const name = $("#submit-name")[0].value;
        const website = $("#submit-website")[0].value;
        const comment = encodeURI($("#submit-comment")[0].value);
        const article = window.location.pathname.split('/')[1];
        toggleForm();
        $("#submit-error")[0].innerHTML = "";

        var a = $.ajax({
          type: "POST",
          beforeSend: function(req) {
            req.setRequestHeader("X-Comment-Name", name);
            req.setRequestHeader("X-Comment-Website", website);
            req.setRequestHeader("X-Comment-Comment", comment);
          },
          url: `/comment/${article}`,
          success: function(msg) {
            console.log(msg);
            if (msg.result === "error") {
              $("#submit-error")[0].innerHTML = `Error: ${msg.reason}`;
            } else {
              renderComments();
              $("#submit-name")[0].value = "";
              $("#submit-website")[0].value = "";
              $("#submit-comment")[0].value = "";
            }
            toggleForm();
          },
          error: function(err) {
            console.log(err);
            $("#submit-error")[0].innerHTML = `Error: ${err}`;
            toggleForm();
          }
        });
        // We have to return false, to keep the form from POSTing to the server
        //  with a reaload
        return false;
      }
      $( "#submit-form" ).submit(submitForm);
      var toggleForm = () => {
        formEnabled = !formEnabled;
        $("#submit-name")[0].disabled = !$("#submit-name")[0].disabled;
        $("#submit-website")[0].disabled = !$("#submit-website")[0].disabled;
        $("#submit-comment")[0].disabled = !$("#submit-comment")[0].disabled;
        $("#submit-button")[0].disabled = !$("#submit-button")[0].disabled;
      };

    </script>
  </section>
```
(Now that I think of it, you will also need jQuery for this to work.)

Basically this is two parts: javascript to dynamically GET the comments, and
a form + javascript to POST a new comment.  It will also disable the form while
the comment is submitting, and show errors (if they occur).

Go ahead and try it!  I'm particularly pleased that it will reload the comments
after you make one, so it shows up instantly (although it does not yet
automatically load other comments when posted after loading the page).

Future work
===
Astute readers will have noticed a problem: there is no moderation, rate
limiting, spam detection, etc.  I will trust that readers will not abuse this
for now (or I'll just turn it off), but I would like to create a better system
around this.

My current plan is to write new comments with an "unverified" tag, and then use
another lambda function (hooked up to the dynamodb stream) to moderate
comments.  The easiest way to do this will probably be to require an email
address to post a comment, and then send an email with a confirmation link that
will mark the comment "OK".  This should be coupled with some rate limiting and
manual blacklists.

Also, I'd like to build better automation around the whole thing.  This will
include tightening up the IAM roles/policies and setting up travis-ci.  My goal
is to have a "staging" site that will contain the most recent branch, that when
merging to master will be updated to the real site.


Thanks
===
Like, share, comment, subscribe, and feel free to send questions to
[matthew@bentley.link](mailto:matthew@bentley.link) (I probably won't check the
comments often enough to respond there -_-).
