#!/bin/bash

set -e
#set -x

cd work/discourse
git pull
bundle

RAILS_ENV=profile rake db:drop db:create db:migrate
RAILS_ENV=profile rake assets:precompile

mkdir public/uploads || echo "Fine that public/uploads already exists."

cd ../..

# Needed after the drop-and-recreate in Discourse
RAILS_ENV=profile ruby seed_db_data.rb
