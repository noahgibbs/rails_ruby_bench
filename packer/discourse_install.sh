# To be run as "ubuntu" user with sudo access.

sleep 30 # Time for OS to boot properly during AMI build
sudo apt-get update

# Basics
whoami > /tmp/username
sudo add-apt-repository ppa:chris-lea/redis-server
sudo apt-get -yqq update
sudo apt-get -yqq install python-software-properties vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev imagemagick postgresql postgresql-contrib-9.5 libpq-dev postgresql-server-dev-9.5 redis-server advancecomp gifsicle jhead jpegoptim libjpeg-turbo-progs optipng pngcrush pngquant gnupg2

# Ruby
curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
curl -sSL https://get.rvm.io | bash -s stable
echo 'gem: --no-document' >> ~/.gemrc

# Node
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.1/install.sh | bash
