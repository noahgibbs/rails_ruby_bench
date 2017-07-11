#!/usr/bin/env ruby

require "fileutils"
require "json"

CUR_DIRECTORY = Dir.pwd

benchmark_software = JSON.load(File.read("/home/ubuntu/benchmark_software.json"))

RAILS_RUBY_BENCH_URL = ENV["RAILS_RUBY_BENCH_URL"]  # Cloned in ami.json
RAILS_RUBY_BENCH_TAG = ENV["RAILS_RUBY_BENCH_TAG"]
DISCOURSE_GIT_URL    = benchmark_software["discourse"]["git_url"]
DISCOURSE_TAG        = benchmark_software["discourse"]["git_tag"]

class SystemPackerBuildError < RuntimeError; end

print <<SETUP
=========
Running setup.rb for Ruby-related software.
RAILS_RUBY_BENCH_URL: #{RAILS_RUBY_BENCH_URL.inspect}
RAILS_RUBY_BENCH_TAG: #{RAILS_RUBY_BENCH_TAG.inspect}

Benchmark Software:
#{JSON.pretty_generate(benchmark_software)}
=========
SETUP

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  out = `#{cmd}`
  print "Running command: #{cmd.inspect}\n" if opts[:debug] || opts["debug"]
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    print "Error running command:\n#{cmd.inspect}\nOutput:\n#{out}\n=====\n"
    raise SystemPackerBuildError.new(err)
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

def clone_or_update_by_json(h, work_dir)
  clone_or_update_repo(h["git_url"], h["git_tag"], h["checkout_dir"] || work_dir)
end

def build_and_mount_ruby(source_dir, prefix_dir, mount_name)
  puts "Build and mount Ruby: Source dir: #{source_dir.inspect} Prefix dir: #{prefix_dir.inspect} Mount name: #{mount_name.inspect}"
  Dir.chdir(source_dir) do
    unless File.exists?("configure")
      csystem "autoconf", "Couldn't run autoconf in #{source_dir}!"
    end
    unless File.exists?("Makefile")
      csystem "./configure --prefix #{prefix_dir}", "Couldn't run configure in #{source_dir}!"
    end
    csystem "make", "Make failed in #{source_dir}!"
    # This should install to the benchmark ruby dir
    csystem "make install", "Installing Ruby failed in #{source_dir}!"
  end
  csystem "bash -l -c \"rvm mount #{prefix_dir} -n #{mount_name}\"", "Couldn't mount #{source_dir.inspect} as #{mount_name}!"
  csystem "bash -l -c \"rvm use --default ext-#{mount_name}\"", "Couldn't set ext-#{mount_name} to rvm default!"
end

def autogen_name
  @autogen_number ||= 1
  name = "autogen-name-#{@autogen_number}"
  @autogen_number += 1
  name
end

def clone_or_update_ruby_by_json(h, work_dir)
  clone_or_update_by_json(h, work_dir)
  mount_name = h["name"] || autogen_name
  prefix_dir = h["prefix_dir"] || File.join(RAILS_BENCH_DIR, "work", "prefix", mount_name.gsub("/", "_"))

  build_and_mount_ruby(h["checkout_dir"], prefix_dir, mount_name)
  h["mount_name"] = "ext-" + mount_name
end

RAILS_BENCH_DIR = File.join(CUR_DIRECTORY, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")
RUBY_DIR = File.join(RAILS_BENCH_DIR, "work", "ruby")

# Cloned in ami.json, but go ahead and update anyway. This shouldn't normally do anything.
if RAILS_RUBY_BENCH_URL.strip != ""
  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "git remote add benchmark-url #{RAILS_RUBY_BENCH_URL} && git fetch benchmark-url", "error fetching commits from Rails Ruby Bench at #{RAILS_RUBY_BENCH_URL.inspect}"
    if RAILS_RUBY_BENCH_TAG.strip != ""
      csystem "git checkout benchmark-url/#{RAILS_RUBY_BENCH_TAG}", "Error checking out Rails Ruby Bench tag #{RAILS_RUBY_BENCH_TAG.inspect}"
    end
  end
end

clone_or_update_repo DISCOURSE_GIT_URL, DISCOURSE_TAG, DISCOURSE_DIR

# Install Discourse and Rails Ruby Bench gems into RVM-standard Ruby 2.3.1 installed for Discourse
Dir.chdir(RAILS_BENCH_DIR) do
  csystem "bash -l -c \"gem install bundler && bundle\"", "Couldn't install bundler or RRB gems for #{RAILS_BENCH_DIR} for Discourse's Ruby 2.3.1!"
end
Dir.chdir(DISCOURSE_DIR) do
  csystem "bash -l -c \"bundle\"", "Couldn't install bundler or Discourse gems for #{DISCOURSE_DIR} for Discourse's Ruby 2.3.1!"
end

Dir.chdir(DISCOURSE_DIR) do
  csystem "bash -l -c \"RAILS_ENV=profile bundle exec rake db:create\"", "Couldn't create Rails database!"
  csystem "bash -l -c \"RAILS_ENV=profile bundle exec rake db:migrate\"", "Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!"

  # TODO: use a better check for whether to rebuild precompiled assets
  unless File.exists? "public/assets"
    csystem "bash -l -c \"RAILS_ENV=profile rake assets:precompile\"", "Failed running 'rake assets:precompile' in #{DISCOURSE_DIR}!"
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

benchmark_software["compare_rubies"].each do |ruby_hash|
  csystem "rvm list", "Error running rvm list!", :debug => true
  puts "Installing Ruby: #{ruby_hash.inspect}"
  # Clone the Ruby, then build and mount if necessary
  if ruby_hash["git_url"]
    work_dir = File.join(RAILS_BENCH_DIR, "work", ruby_hash["name"])
    ruby_hash["checkout_dir"] = work_dir
    clone_or_update_ruby_by_json(ruby_hash, work_dir)
  end

  csystem "rvm list", "Error running rvm list!", :debug => true

  rvm_ruby_name = ruby_hash["mount_name"] || ruby_hash["name"]
  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "bash -l -c \"rvm use #{rvm_ruby_name} && gem install bundler && bundle\"", "Couldn't install bundler or RRB gems for #{RAILS_BENCH_DIR} for Ruby #{rvm_ruby_name.inspect}!"
  end
  Dir.chdir(DISCOURSE_DIR) do
    csystem "bash -l -c \"rvm use #{rvm_ruby_name} && bundle\"", "Couldn't install bundler or Discourse gems for #{DISCOURSE_DIR} for Ruby #{rvm_ruby_name.inspect}!"
  end

end

File.open("/home/ubuntu/benchmark_ruby_versions.txt", "w") do |f|
  rubies = benchmark_software["compare_rubies"].map { |h| h["mount_name"] || h["name"] }
  f.print rubies.join("\n")
end

# Minor bugfix for this version of Discourse. Can remove when I only use 1.8.0+ Discourse?
ASSETS_INIT = File.join(DISCOURSE_DIR, "config/initializers/assets.rb")
unless File.exists?(ASSETS_INIT)
  File.open(ASSETS_INIT, "w") do |f|
    f.write <<-INITIALIZER
      Rails.application.config.assets.precompile += %w( jquery_include.js )
    INITIALIZER
  end
end

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

Dir.chdir("rails_ruby_bench") do
  csystem "bash -l -c \"RAILS_ENV=profile ruby seed_db_data.rb\"", "Couldn't seed the database with profiling sample data!"
end

# And check to make sure the benchmark actually runs... But just do a few iterations.
Dir.chdir("rails_ruby_bench") do
  begin
    csystem "bash -l -c \"./start.rb -s 1 -n 1 -i 10 -w 0 -o /tmp/ -c 1\"", "Couldn't successfully run the benchmark!"
  rescue SystemPackerBuildError
    # Before dying, let's look at that Rails logfile... Redirect stdout to stderr.
    print "Error running test iterations of the benchmark, printing Rails log to console!\n==========\n"
    print `tail -80 work/discourse/log/profile.log`   # If we echo too many lines they just get cut off by Packer
    print "=============\n"
    raise # Re-raise the error, we still want to die.
  end
end
