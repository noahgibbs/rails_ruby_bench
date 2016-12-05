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

clone_or_update_repo SETTINGS["discourse_git_url"], File.join(CUR_DIRECTORY, "work", "discourse")
clone_or_update_repo SETTINGS["ruby_git_url"], File.join(CUR_DIRECTORY, "work", "ruby")

