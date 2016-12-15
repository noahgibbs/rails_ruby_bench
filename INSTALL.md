# UPDATE FOR: https://github.com/discourse/discourse/blob/master/docs/DEVELOPMENT-OSX-NATIVE.md

# WHEN LINUXIFYING: https://github.com/discourse/discourse/blob/master/docs/DEVELOPER-ADVANCED.md

brew install postgres
brew install redis
brew services start postgresql
brew services start redis

brew install git
#brew install phantomjs
brew install gifsicle jpegoptim optipng

brew install npm
npm install -g svgo
