# Load nvm
export NVM_DIR="/home/ubuntu/.nvm"
. "$NVM_DIR/nvm.sh"

set -e

nvm install 6.2.0
nvm alias default 6.2.0
npm install -g svgo phantomjs-prebuilt
