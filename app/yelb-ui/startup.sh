#!/bin/bash
NGINX_CONF=/etc/nginx/conf.d/default.conf
cd clarity-seed
 
if [ -z "$YELB_APPSERVER_ENDPOINT" ]; then YELB_APPSERVER_ENDPOINT="http://yelb-appserver:4567"; fi
 
# when the variable is populated a search domain entry is added to resolv.conf at startup
# this is needed for the ECS service discovery given the app works by calling host names and not FQDNs
# a search domain can't be added to the container when using the awsvpc mode
# and the awsvpc mode is needed for A records (bridge only supports SRV records)
if [ $SEARCH_DOMAIN ]; then echo "search ${SEARCH_DOMAIN}" >> /etc/resolv.conf; fi
 
sed -i -- 's#/usr/share/nginx/html#/clarity-seed/'$UI_ENV'/dist#g' $NGINX_CONF
 
# DNS server used by this container (the VPC resolver on AWS, Docker's embedded DNS locally).
# nginx needs it explicitly to re-resolve the appserver name at request time.
RESOLVER=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
 
# this adds the reverse proxy configuration to nginx
# everything that hits /api is proxied to the app server.
# The upstream is set through a variable so nginx resolves the name on each request
# (cached for 10s) instead of once at startup. This keeps working when the appserver
# task is replaced and gets a new IP in Cloud Map.
if ! grep -q "location /api" "$NGINX_CONF"; then
    eval "cat <<EOF
    location /api {
        resolver $RESOLVER valid=10s;
        set \\\$appserver \"$YELB_APPSERVER_ENDPOINT\";
        proxy_pass \\\$appserver\\\$uri\\\$is_args\\\$args;
        proxy_http_version 1.1;
    }
    gzip on;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gunzip on;
EOF
" > /proxycfg.txt
    # echo "        proxy_set_header Host $host;" >> /proxycfg.txt
    sed --in-place '/server_name  localhost;/ r /proxycfg.txt' $NGINX_CONF
fi
 
nginx -g "daemon off;"
 
