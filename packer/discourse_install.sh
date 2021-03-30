# To be run as "ubuntu" user with sudo access.

set -e

sudo apt-get update -y

bash <(wget -qO- https://raw.githubusercontent.com/techAPJ/install-rails/master/linux)

# It's used by Discourse asset build, but not installed by the script above
sudo apt-get install brotli -y
