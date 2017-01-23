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

# Logout and back in to activate RVM installation

rvm install 2.3.1
rvm --default use 2.3.1 # If this error out check https://rvm.io/integration/gnome-terminal
gem install bundler mailcatcher


# Postgresql
sudo su postgres  # TODO: Make a here-doc!
createuser --createdb --superuser -Upostgres $(cat /tmp/username)
psql -c "ALTER USER $(cat /tmp/username) WITH PASSWORD 'password';"
psql -c "create database discourse_development owner $(cat /tmp/username) encoding 'UTF8' TEMPLATE template0;"
psql -c "create database discourse_test        owner $(cat /tmp/username) encoding 'UTF8' TEMPLATE template0;"
psql -d discourse_development -c "CREATE EXTENSION hstore;"
psql -d discourse_development -c "CREATE EXTENSION pg_trgm;"
exit

# Node
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.1/install.sh | bash
# exit the terminal and open it again
nvm install 6.2.0
nvm alias default 6.2.0
npm install -g svgo phantomjs-prebuilt
