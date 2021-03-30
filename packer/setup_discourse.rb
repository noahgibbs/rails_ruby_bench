#!/usr/bin/env ruby

require "fileutils"
require "json"

# Print all commands and show their full output
VERBOSE = true

base = "/home/ubuntu"
benchmark_software = JSON.load(File.read("#{base}/benchmark_software.json"))

DISCOURSE_GIT_URL    = benchmark_software["discourse"]["git_url"]
DISCOURSE_TAG        = benchmark_software["discourse"]["git_tag"]
BUNDLER_VERSION      = benchmark_software["bundler"]["version"]

class SystemPackerBuildError < RuntimeError; end

print <<SETUP
=========
Running setup_discourse.rb for Ruby-related software...
=========
SETUP

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  cmd = "bash -l -c \"#{cmd}\"" if opts[:bash]
  print "Running command: #{cmd.inspect}\n" if VERBOSE || opts[:debug] || opts["debug"]
  if VERBOSE
    system(cmd, out: $stdout, err: :out)
  else
    out = `#{cmd}`
  end
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    puts "Error running command:\n#{cmd.inspect}"
    puts "Output:\n#{out}\n=====" if out
    raise SystemPackerBuildError.new(err)
  end
end

def clone_or_update_repo(repo_url, tag, work_dir)
  unless Dir.exist?(work_dir)
    csystem "git clone #{repo_url} #{work_dir}", "Couldn't 'git clone' into #{work_dir}!", :debug => true
  end

  Dir.chdir(work_dir) do
    csystem "git fetch", "Couldn't 'git fetch' in #{work_dir}!", :debug => true

    if tag && tag.strip != ""
      tag = tag.strip
      csystem "git checkout #{tag}", "Couldn't 'git checkout #{tag}' in #{work_dir}!", :debug => true
    else
      csystem "git pull", "Couldn't 'git pull' in #{work_dir}!", :debug => true
    end
  end
end

RAILS_BENCH_DIR = File.join(Dir.pwd, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")

clone_or_update_repo DISCOURSE_GIT_URL, DISCOURSE_TAG, DISCOURSE_DIR

Dir.chdir(DISCOURSE_DIR) do
  csystem "gem install bundler -v#{BUNDLER_VERSION}", "Couldn't install bundler for #{DISCOURSE_DIR} for Discourse's system Ruby!", :bash => true
  csystem "bundle _#{BUNDLER_VERSION}_", "Couldn't install Discourse gems for #{DISCOURSE_DIR} for Discourse's system Ruby!", :bash => true
end

Dir.chdir(DISCOURSE_DIR) do
  csystem "RAILS_ENV=profile bundle _#{BUNDLER_VERSION}_ exec rake db:create", "Couldn't create Rails database!", :bash => true
  csystem "RAILS_ENV=profile bundle _#{BUNDLER_VERSION}_ exec rake db:migrate", "Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!", :bash => true

  # TODO: use a better check for whether to rebuild precompiled assets
  unless File.exists? "public/assets"
    csystem "RAILS_ENV=profile bundle _#{BUNDLER_VERSION}_ exec rake assets:precompile", "Failed running 'rake assets:precompile' in #{DISCOURSE_DIR}!", :bash => true
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

puts "Add assets.rb initializer for Discourse"
# Minor bugfix for this version of Discourse. Can remove when I only use 1.8.0+ Discourse?
ASSETS_INIT = File.join(DISCOURSE_DIR, "config/initializers/assets.rb")
unless File.exists?(ASSETS_INIT)
  File.open(ASSETS_INIT, "w") do |f|
    f.write <<-INITIALIZER
      Rails.application.config.assets.precompile += %w( jquery_include.js )
    INITIALIZER
  end
end

puts "Hack to disable CSRF protection during benchmark..."
# Turn off CSRF protection for Discourse in the benchmark. I have no idea why
# user_simulator's CSRF handling stopped working between Discourse 1.7.X and
# 1.8.0.beta10, but it clearly did. This is a horrible workaround and should
# be fixed when I figure out the problem.
APP_CONTROLLER = File.join(DISCOURSE_DIR, "app/controllers/application_controller.rb")
contents = File.read(APP_CONTROLLER)
original_line = "protect_from_forgery"
patched_line = "#protect_from_forgery"
unless contents[patched_line]
  File.open(APP_CONTROLLER, "w") do |f|
    f.print contents.gsub(original_line, patched_line)
  end
end

# Oh and hey, looks like Bootsnap breaks something in the load order when
# including config/environment into start.rb. Joy.
# TODO: merge this patching into a little table of patches?
path = File.join(DISCOURSE_DIR, "config/boot.rb")
contents = File.read(path)
original_line = "if ENV['RAILS_ENV'] != 'production'"
patched_line = "if ENV['RAILS_ENV'] != 'production' && ENV['RAILS_ENV'] != 'profile'"
unless contents[patched_line]
  File.open(path, "w") do |f|
    f.print contents.gsub(original_line, patched_line)
  end
end

FileUtils.touch "/tmp/setup_discourse_ran_correctly"
