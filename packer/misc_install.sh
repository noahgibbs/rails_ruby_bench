#!/bin/bash

set -e

# To be run as "ubuntu" user w/ sudo access

# Install OpenJDK-headless for Java 7 to run JMeter

sudo apt-get -yqq install apache2-utils libjemalloc-dev libtcmalloc-minimal4 openjdk-7-jre-headless
