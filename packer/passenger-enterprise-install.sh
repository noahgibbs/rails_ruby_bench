# This install script is closely based on https://www.phusionpassenger.com/docs/advanced_guides/install_and_upgrade/nginx/install/enterprise/bionic.html

set -e
set -x

sudo mv /tmp/passenger-enterprise-license /etc/passenger-enterprise-license
chmod 644 /etc/passenger-enterprise-license

# Install Phusion's PGP key and add HTTPS support for APT
sudo apt-get install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo apt-get install -y apt-transport-https ca-certificates

# Add Phusion's APT repository
unset HISTFILE
sudo sh -c 'echo machine www.phusionpassenger.com/enterprise_apt login download password `cat /tmp/passenger-download-token` >> /etc/apt/auth.conf'
sudo sh -c 'echo deb https://www.phusionpassenger.com/enterprise_apt xenial main > /etc/apt/sources.list.d/passenger.list'
sudo chown root: /etc/apt/sources.list.d/passenger.list
sudo chmod 644 /etc/apt/sources.list.d/passenger.list
sudo chown root: /etc/apt/auth.conf
sudo chmod 600 /etc/apt/auth.conf
sudo apt-get update

# Install Passenger Enterprise + Nginx module
#sudo apt-get install -y libnginx-mod-http-passenger-enterprise
sudo apt-get install -y nginx-extras passenger-enterprise

#if [ ! -f /etc/nginx/modules-enabled/50-mod-http-passenger.conf ]
#then sudo ln -s /usr/share/nginx/modules-available/mod-http-passenger.load /etc/nginx/modules-enabled/50-mod-http-passenger.conf
#fi
#sudo ls /etc/nginx/conf.d/mod-http-passenger.conf

sudo service nginx restart

# sudo /usr/bin/passenger-config validate-install
