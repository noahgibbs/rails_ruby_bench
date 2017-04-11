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

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  out = `#{cmd}`
  print "Running command: #{cmd.inspect}" if opts[:debug] || opts["debug"]
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    print "Error running command:\n#{cmd.inspect}\nOutput:\n#{out}\n=====\n"
    raise err
  end
  print "Command output:\n#{out}\n=====\n" if opts[:debug] || opts["debug"]
  out
end

def clone_or_update_repo(repo_url, tag, work_dir)
  tag = tag.strip
  if File.exist?(work_dir)
    Dir.chdir(work_dir) do
      csystem "git pull", "Couldn't 'git pull' in #{work_dir}!"
    end
  elsif tag && tag != ""
    cmd = "git clone #{repo_url} -b #{tag} #{work_dir}"
    puts "Command: #{cmd.inspect}"
    csystem cmd, "Couldn't 'git clone' at tag/branch #{tag.inspect} into #{work_dir}!"
  else
    cmd = "git clone #{repo_url} #{work_dir}"
    puts "Command: #{cmd.inspect}"
    csystem cmd, "Couldn't 'git clone' into #{work_dir}!"
  end

end

RAILS_BENCH_DIR = File.join(CUR_DIRECTORY, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")
RUBY_DIR = File.join(RAILS_BENCH_DIR, "work", "ruby")

clone_or_update_repo DISCOURSE_GIT_URL, DISCOURSE_TAG, DISCOURSE_DIR
clone_or_update_repo RUBY_GIT_URL, RUBY_TAG, RUBY_DIR

# Give a spot to install ruby to
csystem "sudo mkdir -p #{RUBY_INSTALL_DIR} && sudo chown -R ubuntu #{RUBY_INSTALL_DIR}",
  "Couldn't create dir #{RUBY_INSTALL_DIR.inspect} to install Ruby to!"

Dir.chdir(RUBY_DIR) do
  unless File.exists?("configure")
    csystem "autoconf", "Couldn't run autoconf in #{RUBY_DIR}!"
  end
  unless File.exists?("Makefile")
    csystem "./configure --prefix #{RUBY_INSTALL_DIR}", "Couldn't run configure in #{RUBY_DIR}!"
  end
  csystem "make", "Make failed in #{RUBY_DIR}!"
  # This should install to the benchmark ruby dir
  csystem "make install", "Installing Ruby failed in #{RUBY_DIR}!"
end
csystem "bash -l -c \"rvm mount #{RUBY_INSTALL_DIR} -n ruby-benchmark\"", "Couldn't mount #{RUBY_DIR.inspect} as ruby-benchmark!"
csystem "bash -l -c \"rvm use --default ext-ruby-benchmark\"", "Couldn't set ext-ruby-benchmark to rvm default!"
Dir.chdir(RAILS_BENCH_DIR) { csystem("bash -l -c \"rvm use ext-ruby-benchmark && gem install bundle && bundle\"", "Couldn't install bundler and gems", debug: true) }
Dir.chdir(DISCOURSE_DIR) { csystem("bash -l -c \"rvm use ext-ruby-benchmark && bundle\"", "Couldn't install bundler and gems", debug: true) }

# If OTHER_RUBIES contains anything, install them via RVM. Useful for benchmarking multiple Rubies.
OTHER_RUBIES.split(",").compact.each do |other_ruby_version|
  csystem "bash -l -c \"rvm install #{other_ruby_version}\"", "Couldn't use RVM to install #{other_ruby_version.inspect}!"
  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "bash -l -c \"rvm use #{other_ruby_version} && gem install bundler && bundle\"", "Couldn't install bundler or gems for #{RAILS_BENCH_DIR}!"
  end
  Dir.chdir(DISCOURSE_DIR) do
    csystem "bash -l -c \"rvm use #{other_ruby_version} && bundle\"", "Couldn't install bundler or gems for #{DISCOURSE_DIR}!"
  end
end

Dir.chdir(DISCOURSE_DIR) do
  csystem "bash -l -c \"rvm use ext-ruby-benchmark && RAILS_ENV=profile bundle exec rake db:create\"", "Couldn't create Rails database!"
  csystem "bash -l -c \"rvm use ext-ruby-benchmark && RAILS_ENV=profile bundle exec rake db:migrate\"", "Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!"

  # TODO: use a better check for whether to rebuild precompiled assets
  unless File.exists? "public/assets"
    csystem "bash -l -c \"rvm use ext-ruby-benchmark && RAILS_ENV=profile rake assets:precompile\"", "Failed running 'rake assets:precompile' in #{DISCOURSE_DIR}!"
  end
  unless File.exists? "public/uploads"
    FileUtils.mkdir "public/uploads"
  end
  conf_db = File.read "config/database.yml"
  new_contents = conf_db.gsub("pool: 5", "pool: 30")  # Increase database.yml thread pool, including for profile environment
  if new_contents != conf_db
    File.open("config/database.yml", "w") do |f|
      f.print new_contents
    end
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

Dir.chdir("rails_ruby_bench") do
  csystem "bash -l -c \"rvm use ext-ruby-benchmark && RAILS_ENV=profile ruby seed_db_data.rb\"", "Couldn't seed the database with profiling sample data!"
end
