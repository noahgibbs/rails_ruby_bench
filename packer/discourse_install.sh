# To be run as "ubuntu" user with sudo access.

set -e

#sleep 30 # Time for OS to boot properly during AMI build

# No ~/.bash_profile? Make one that sources ~/.bashrc. Otherwise you won't like what happens
# if rvm creates it for you.
if [ ! -f ~/.bash_profile ]; then
   cat >~/.bash_profile <<EOF
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
EOF
fi

sudo apt-get update

# Basics
whoami > /tmp/username
sudo add-apt-repository ppa:chris-lea/redis-server
sudo apt-get -yqq update
sudo apt-get -yqq --allow-unauthenticated install vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev imagemagick redis-server advancecomp gifsicle jhead jpegoptim libjpeg-turbo-progs optipng pngcrush pngquant gnupg2
#sudo apt-get -yqq --allow-unauthenticated install python-software-properties vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev imagemagick postgresql-server postgresql-contrib libpq-dev redis-server advancecomp gifsicle jhead jpegoptim libjpeg-turbo-progs optipng pngcrush pngquant gnupg2

# Ruby
curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
curl -sSL https://get.rvm.io | bash -s stable
echo 'gem: --no-document' >> ~/.gemrc

# Postgres prep
sudo adduser postgres  # Needed on Ubuntu Bionic where no 'postgres' user is created

# Node
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.1/install.sh | bash
