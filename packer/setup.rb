#!/usr/bin/env ruby

require "fileutils"

CUR_DIRECTORY = Dir.pwd

RUBY_INSTALL_DIR     = "/usr/local/benchmark/ruby" # Make configurable?
RAILS_RUBY_BENCH_URL = ENV["RAILS_RUBY_BENCH_URL"]  # Cloned in ami.json
DISCOURSE_GIT_URL    = ENV["DISCOURSE_GIT_URL"]
DISCOURSE_TAG        = ENV["DISCOURSE_TAG"]
RUBY_GIT_URL         = ENV["RUBY_GIT_URL"]
RUBY_TAG             = ENV["RUBY_TAG"]
RUBY_SYSTEM_PATH     = ENV["RUBY_SYSTEM_PATH"]
OTHER_RUBIES         = ENV["OTHER_RUBIES"]

# TODO:
# * Review Postgres setup - complete?

def clone_or_update_repo(repo_url, tag, work_dir)
  tag = tag.strip
  if File.exist?(work_dir)
    Dir.chdir(work_dir) do
      system("git pull") || raise("Couldn't 'git pull' in #{work_dir}!")
    end
  elsif tag && tag != ""
    cmd = "git clone #{repo_url} -b #{tag} #{work_dir}"
    puts "Command: #{cmd.inspect}"
    system(cmd) || raise("Couldn't 'git clone' at tag/branch #{tag.inspect} into #{work_dir}!")
  else
    cmd = "git clone #{repo_url} #{work_dir}"
    puts "Command: #{cmd.inspect}"
    system(cmd) || raise("Couldn't 'git clone' into #{work_dir}!")
  end

end

RAILS_BENCH_DIR = File.join(CUR_DIRECTORY, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")
RUBY_DIR = File.join(RAILS_BENCH_DIR, "work", "ruby")

clone_or_update_repo DISCOURSE_GIT_URL, DISCOURSE_TAG, DISCOURSE_DIR
clone_or_update_repo RUBY_GIT_URL, RUBY_TAG, RUBY_DIR

system("sudo mkdir -p #{RUBY_INSTALL_DIR} && sudo chown -R ubuntu #{RUBY_INSTALL_DIR}") # Give a spot to install ruby to

Dir.chdir(RUBY_DIR) do
  unless File.exists?("configure")
    system("autoconf") || raise("Couldn't run autoconf in #{RUBY_DIR}!")
  end
  unless File.exists?("Makefile")
    system("./configure --prefix #{RUBY_INSTALL_DIR}") || raise("Couldn't run configure in #{RUBY_DIR}!")
  end
  system("make") || raise("Make failed in #{RUBY_DIR}!")
  system("make install") || raise("Installing Ruby failed in #{RUBY_DIR}!") # This should install to the benchmark ruby dir
end
system("rvm mount #{RUBY_INSTALL_DIR} -n benchmark-ruby") || raise("Couldn't mount #{RUBY_DIR.inspect} as benchmark-ruby!")
system("rvm use --default ext-benchmark-ruby") || raise("Couldn't set ext-benchmark-ruby to rvm default!")
system("cd #{RAILS_BENCH_DIR} && bundle") || raise("Failed running bundler in #{RAILS_BENCH_DIR.inspect}")
system("cd #{DISCOURSE_DIR} && bundle") || raise("Failed running bundler in #{DISCOURSE_DIR.inspect}")

# If OTHER_RUBIES contains anything, install them via RVM. Useful for benchmarking multiple Rubies.
OTHER_RUBIES.split(",").compact.each do |other_ruby_version|
  system("bash -l -c \"rvm install #{other_ruby_version}\"") || raise("Couldn't use RVM to install #{other_ruby_version.inspect}!")
  system("cd #{RAILS_BENCH_DIR} && rvm use #{other_ruby_version} && bundle") || raise("Failed running bundler under ruby #{other_ruby_version} in #{RAILS_BENCH_DIR.inspect}")
  system("cd #{DISCOURSE_DIR} && rvm use #{other_ruby_version} && bundle") || raise("Failed running bundler under ruby #{other_ruby_version} in #{DISCOURSE_DIR.inspect}")
end

Dir.chdir(DISCOURSE_DIR) do
  system("RAILS_ENV=profile bundle exec rake db:create")  # Don't check for failure
  system("RAILS_ENV=profile bundle exec rake db:migrate") || raise("Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!")
  #system("RAILS_ENV=profile bundle exec rake admin:create")  # This needs user input
  #system("RAILS_ENV=profile bundle exec rake db:seed_fu")

  # TODO: use a better check for whether to rebuild precompiled assets
  unless File.exists? "public/assets"
    system("RAILS_ENV=profile rake assets:precompile") || raise("Failed running 'rake assets:precompile' in #{DISCOURSE_DIR}!")
  end
  unless File.exists? "public/uploads"
    FileUtils.mkdir "public/uploads"
  end
end

# Minor bugfix for this version of Discourse. Can remove later?
ASSETS_INIT = File.join(DISCOURSE_DIR, "config/initializers/assets.rb")
unless File.exists?(ASSETS_INIT)
  File.open(ASSETS_INIT, "w") do |f|
    f.write <<-INITIALIZER
      Rails.application.config.assets.precompile += %w( jquery_include.js )
    INITIALIZER
  end
end

system("cd rails_ruby_bench && RAILS_ENV=profile ruby seed_db_data.rb") || raise("Couldn't seed the database with profiling sample data!")
