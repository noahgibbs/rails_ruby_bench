#!/usr/bin/env bash

# Install Rails

trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e
log_info() {
  printf "\n\e[0;35m $1\e[0m\n\n"
}

if [ ! -f "$HOME/.bashrc" ]; then
  touch $HOME/.bashrc
fi

log_info "Updating Packages ..."
  sudo apt-get update

log_info "Installing Git ..."
  sudo apt-get -y install git

log_info "Installing build essentials ..."
  sudo apt-get -y install build-essential

log_info "Installing libraries for common gem dependencies ..."
  sudo apt-get -y install libxslt1-dev libcurl4-openssl-dev libksba8 libksba-dev libreadline-dev libssl-dev zlib1g-dev libsnappy-dev

log_info "Installing sqlite3 ..."
 sudo apt-get -y install libsqlite3-dev sqlite3

log_info "Installing Postgres ..."
  sudo apt-get -y install postgresql postgresql-server-dev-all postgresql-contrib libpq-dev

log_info "Installing Redis ..."
  sudo apt-get -y install redis-server

log_info "Installing curl ..."
  sudo apt-get -y install curl

log_info "Installing ImageMagick ..."
  sudo apt-get -y install libtool
  wget https://raw.githubusercontent.com/discourse/discourse_docker/master/image/base/install-imagemagick
  chmod +x install-imagemagick
  sudo ./install-imagemagick

log_info "Installing image utilities ..."
  sudo apt-get -y install advancecomp gifsicle jpegoptim libjpeg-progs optipng pngcrush pngquant
  sudo apt-get -y install jhead

if [[ ! -d "$HOME/.rbenv" ]]; then
  log_info "Installing rbenv ..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv

    if ! grep -qs "rbenv init" ~/.bashrc; then
      printf 'export PATH="$HOME/.rbenv/bin:$PATH"\n' >> ~/.bashrc
      printf 'eval "$(rbenv init - --no-rehash)"\n' >> ~/.bashrc
    fi

    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

if [[ ! -d "$HOME/.rbenv/plugins/ruby-build" ]]; then
  log_info "Installing ruby-build, to install Rubies ..."
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

ruby_version="2.7.1"

log_info "Installing Ruby $ruby_version ..."
  rbenv install "$ruby_version"

log_info "Setting $ruby_version as global default Ruby ..."
  rbenv global $ruby_version
  rbenv rehash

log_info "Updating to latest Rubygems version ..."
  gem update --system

log_info "Installing Rails ..."
  gem install rails

log_info "Installing Bundler ..."
  gem install bundler

log_info "Installing Mailcatcher ..."
  gem install mailcatcher

log_info "Installing Node.js 10 ..."
  curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
  sudo apt-get install -y nodejs
  sudo npm install -g svgo
  sudo npm install -g yarn
