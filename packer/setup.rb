#!/usr/bin/env ruby

CUR_DIRECTORY = File.dirname(__FILE__)

RAILS_RUBY_BENCH_URL = ENV["RAILS_RUBY_BENCH_URL"]
DISCOURSE_GIT_URL    = ENV["DISCOURSE_GIT_URL"]
RUBY_GIT_URL         = ENV["RUBY_GIT_URL"]
RUBY_SYSTEM_PATH     = ENV["RUBY_SYSTEM_PATH"]

# TODO:
# * Review Postgres setup - complete?

def clone_or_update_repo(repo_url, work_dir)
  if File.exist?(work_dir)
    Dir.chdir(work_dir) do
      system("git pull") || raise("Couldn't 'git pull' in #{work_dir}!")
    end
  else
    system("git clone #{repo_url} #{work_dir}") || raise("Couldn't 'git clone' into #{work_dir}!")
  end

end

RAILS_BENCH_DIR = File.join(CUR_DIRECTORY, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")
RUBY_DIR = File.join(RAILS_BENCH_DIR, "work", "ruby")

clone_or_update_repo DISCOURSE_GIT_URL, DISCOURSE_DIR
clone_or_update_repo RUBY_GIT_URL, RUBY_DIR

system("cd #{DISCOURSE_DIR} && bundle") || raise("Failed running bundler in #{DISCOURSE_DIR}")

Dir.chdir(RUBY_DIR) do
  unless File.exists?("configure")
    system("autoconf") || raise("Couldn't run autoconf in #{RUBY_DIR}!")
  end
  unless File.exists?("Makefile")
    system("./configure") || raise("Couldn't run configure in #{RUBY_DIR}!")
  end
  system("make") || raise("Make failed in #{RUBY_DIR}!")
end

Dir.chdir(DISCOURSE_DIR) do
  system("RAILS_ENV=profile rake db:create")  # Don't check for failure
  system("RAILS_ENV=profile rake db:migrate") || raise("Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!")

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
