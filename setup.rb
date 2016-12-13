#!/usr/bin/env ruby

require "json"

CUR_DIRECTORY = File.dirname(__FILE__)

SETTINGS = JSON.parse File.read("setup.json")

def clone_or_update_repo(repo_url, work_dir)
  if File.exist?(work_dir)
    Dir.chdir(work_dir) do
      system("git pull") || raise("Couldn't 'git pull' in #{work_dir}!")
    end
  else
    system("git clone #{repo_url} #{work_dir}") || raise("Couldn't 'git clone' into #{work_dir}!")
  end

end

DISCOURSE_DIR = File.join(CUR_DIRECTORY, "work", "discourse")
RUBY_DIR = File.join(CUR_DIRECTORY, "work", "ruby")

clone_or_update_repo SETTINGS["discourse_git_url"], DISCOURSE_DIR
clone_or_update_repo SETTINGS["ruby_git_url"], RUBY_DIR

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

system "cd #{RUBY_DIR} && autoconf && ./configure && make"
