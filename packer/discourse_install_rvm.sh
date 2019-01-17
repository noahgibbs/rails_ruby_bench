set -e

rvm install 2.4.1
rvm --default use 2.4.1 # If this error out check https://rvm.io/integration/gnome-terminal
gem install bundler -v1.17.3
gem install mailcatcher
