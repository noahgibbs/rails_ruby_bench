#!/bin/bash

# To be run as "ubuntu" user w/ sudo access

sudo apt-get -yqq nginx

# Set up directory for benchmark to write into, served by NGinX
mkdir -p /var/www/html/benchmark-results
chown -R ubuntu /var/www/html/benchmark-results
