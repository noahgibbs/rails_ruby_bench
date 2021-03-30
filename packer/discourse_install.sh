# To be run as "ubuntu" user with sudo access.

set -e

sudo apt-get update

bash <(wget -qO- https://raw.githubusercontent.com/techAPJ/install-rails/master/linux)


