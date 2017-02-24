{
    "date": "2015-02-07",
    "description": "How to set up a FreeBSD server with an Nginx revers proxy, SSL, and other best practice security measures.  Email, Jails, and more coming soon.",
    "draft": false,
    "id": 15,
    "image": "",
    "meta_title": "FreeBSD with Nginx reverse proxy, SSL, SPDY, and more",
    "slug": "security",
    "tags": [
        "security",
        "guide",
        "ssl",
        "nginx"
    ],
    "title": "Security",
    "type": "post"
}


This is a brief guide to securing your web/mail server, with a focus on FreeBSD.  Some of this is simply links to other blogs, and the rest is my own setup.
<!--more-->

# HTTP(S)
The first thing you should do is get a SSL certificate (it's less than $10 per year).  I bought [Comodo PositiveSSL](https://www.namecheap.com/security/ssl-certificates/comodo/positivessl.aspx) from Namecheap, so this guide will assume you did the same, although it will work without much difference with any SSL certificate.

## SSL (TLS) with Nginx

### Keys
Your SSL key and certificate should be names something like `mtbentley.us.key` and `mtbentley.us.crt`, and go in `/usr/local/etc/nginx/keys/`.  This directory should only be readable by root, as nginx will read the keys before dropping privileges.
The other file is `ssl-bundle.crt`.  This is simply the combination of your website's certificate (`mtbentley.us.crt`), the intermediate certificates, and finally the root certificate, in that order from the beginning of the file to the end.

### Nginx config
FreeBSD's Nginx config is in `/usr/local/etc/nginx/`.  My config is based on my previous Debian system.

Here in my `nginx.conf`, commented as necessary:
```
user www; ### Make sure the user 'www' exists ### 
worker_processes auto;
events {
        worker_connections 768;
}

http {
        ### Cache. This assumes your content won't change too often.     ### 
        ### /var/nginx/cache should exist, and should be writable by www ### 
        proxy_cache_path /var/nginx/cache keys_zone=one:10m
                loader_threshold=300 loader_files=200
                max_size=200m;
        ### Make ssl a bit faster ### 
        ssl_session_cache   shared:SSL:10m;
        ssl_session_timeout 10m;
        
        ## 
        # Basic Settings
        ## 
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        include /usr/local/etc/nginx/mime.types;
        default_type application/octet-stream;
        
        ## 
        # Logging Settings
        ## 
        ### /var/log/nginx should be writable by www ### 
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        
        ## 
        # Gzip Settings
        ## 
        gzip on;
        gzip_disable "msie6";
        gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

        ## 
        # Virtual Host Configs
        ## 
        ### Includes. Extra conf in conf.d and sites in sites-enabled. ### 
        include /usr/local/etc/nginx/conf.d/*.conf;
        include /usr/local/etc/nginx/sites-enabled/*;
}

```  

I have two sites enables: default, and default-ssl.  default simply 302 redirects to the https site.  
  
`sites-enabled/default`:  
```
server {
    listen 80;
    server_name mtbentley.us; ### Replace with your domain name ### 

    rewrite ^ https://$server_name$request_uri? permanent;
}

```  

default-ssl is where most of the magic takes place.  
`sites-enabled/default-ssl`:  
```
server {
    ### SSL and SPDY.  More on this later ### 
    listen              443 ssl spdy; 
    server_name         mtbentley.us; ### Again, replace w/ your domain ### 
    
    ### STS. Tells the browser to require all future connections to ### 
    ### this site to be over HTTPS                                  ### 
    add_header Strict-Transport-Security "max-age=31536000";
    
    ### Public key pinning. More on this later ### 
    add_header Public-Key-Pins 'pin-sha256="3OoyaaPUGXSUVoyFRpnE9K/LfG7UVt2g0cz9sEWE5zA="; max-age=15768000';
    
    ### The location of the ssl certificate and key. ### 
    ### Change as necessary for your key names.      ### 
    ssl_certificate     keys/ssl-bundle.crt;
    ssl_certificate_key keys/mtbentley.us.key;
    
    ### Don't use old protocols (SSLv3).                ### 
    ### This breaks some compatibility with Windows XP. ### 
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    
    ### Only use good ciphers.  Also breaks some XP support ### 
    ssl_ciphers         'AES128+EECDH:AES128+EDH';
    ssl_prefer_server_ciphers on;
    
    ### Prevent putting your site in an iframe ### 
    add_header X-Frame-Options "SAMEORIGIN";
    
    ### Proxy headers, for the server you are proxying to ### 
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    
    keepalive_timeout   70;
    
    ### Allow uploads up to 1G. You may not want it this large. ### 
    client_max_body_size 1G;
    
    ### Enable cache #### 
    proxy_cache one;
    
    ### Everything to /cv comes from /var/www                      ### 
    ### If you run a static site, this should be / rather that /cv ### 
    ### /var/www is the location of the content, and should be     ### 
    ### readable by the user www                                   ### 
    location /cv {
        root /var/www/;
    }
    
    ### For my website, I reverse-proxy to another server, running ### 
    ### on 10.7.0.1. Caching is enabled for this server.           ### 
    location / {
        proxy_cache_valid any   10m;
        proxy_cache_bypass $cookie_nocache $arg_nocache$arg_comment;
        proxy_pass http://10.7.0.1:2368;
    }
}

```  

## HSTS
HTTP Strict Transport Security, or HSTS, tells the browser to only allow connections to your site over HTTPS.  This might pose a problem if you need to switch away from HTTPS at some point in the future, but it can prevent MITM protocol downgrade attacks.

## HPKP
More info on HPKP (Public Key Pinning) [here](https://timtaubert.de/blog/2014/10/deploying-tls-the-hard-way/).  You should think twice before doing this, because your website can become un-reachable if you lose or have to revoke your SSL private key.

## SPDY
SPDY is what will eventually become HTTP/2.  It's a bit faster than HTTP/1.1, but requires you to specifically enable it when compiling.  The easiest way to do this with FreeBSD is to compile Nginx from ports, selecting SPDY when configuring.
How to do this:  
\#`portsnap fetch extract` to get the ports tree.  
\#`cd /usr/ports/www/nginx`  
\#`make rmconfig` (if you have compiled nginx previously)  
\#`make install clean`  
When the configure menu comes up, be sure to select 'SPDY', along with any modules you may want.

Now just make sure you enable nginx by adding `nginx_enable="YES"` to `/etc/rc.conf`, and run `service nginx start` to start it up.


