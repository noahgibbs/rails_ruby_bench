#!/usr/bin/env ruby

require "fileutils"
require "json"

# Print all commands and show their full output
VERBOSE = true

base = "/home/ubuntu"
benchmark_software = JSON.load(File.read("#{base}/benchmark_software.json"))

RAILS_RUBY_BENCH_URL = ENV["RAILS_RUBY_BENCH_URL"]  # Cloned in ami.json
RAILS_RUBY_BENCH_TAG = ENV["RAILS_RUBY_BENCH_TAG"]

DISCOURSE_DIR = ENV["DISCOURSE_DIR"] || File.join(__dir__, "work", "discourse")
DISCOURSE_URL = ENV["DISCOURSE_URL"] || benchmark_software["discourse"]["git_url"]
DISCOURSE_TAG = ENV["DISCOURSE_TAG"] || benchmark_software["discourse"]["git_tag"]
BUNDLER_VERSION = benchmark_software["bundler"]["version"]

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

def clone_or_update_by_json(h, work_dir)
  clone_or_update_repo(h["git_url"], h["git_tag"], h["checkout_dir"] || work_dir)
end

def build_and_mount_ruby(source_dir, prefix_dir, mount_name, options = {})
  puts "Build and mount Ruby: Source dir: #{source_dir.inspect} Prefix dir: #{prefix_dir.inspect} Mount name: #{mount_name.inspect}"
  Dir.chdir(source_dir) do
    unless File.exists?("configure")
      csystem "autoconf", "Couldn't run autoconf in #{source_dir}!"
    end
    unless File.exists?("Makefile")
      configure_options = options["configure_options"] || ""
      csystem "./configure --prefix #{prefix_dir} #{configure_options}", "Couldn't run configure in #{source_dir}!"
    end
    csystem "make", "Make failed in #{source_dir}!"
    # This should install to the benchmark ruby dir
    csystem "make install", "Installing Ruby failed in #{source_dir}!"
  end
end

def autogen_name
  @autogen_number ||= 1
  name = "autogen-name-#{@autogen_number}"
  @autogen_number += 1
  name
end

def clone_or_update_ruby_by_json(h, work_dir)
  clone_or_update_by_json(h, work_dir)
  mount_name = h["name"] ? h["name"].gsub("/", "_") : autogen_name
  prefix_dir = h["prefix_dir"] || File.join(ENV["HOME"], ".rbenv", "versions", mount_name)

  build_and_mount_ruby(h["checkout_dir"], prefix_dir, mount_name, { "configure_options" => h["configure_options"] || "" } )
  h["mount_name"] = mount_name
end

# When you run with "rbenv shell", you wind up with a bunch of extra
# output that you usually don't want (note: CHECK THIS.)  You need to cut out just the
# last line, remove extraneous newlines, make sure .bash_profile has
# been sourced...
def last_line_with_ruby(cmd, ruby)
  output = `bash -l -c \"rbenv shell #{ruby} && #{cmd}\"`
  unless $?.success?
    puts "Something went wrong running command, returning nil... #{$?.inspect} / #{cmd.inspect}"
    return nil
  end
  output.split("\n").compact[-1]
end

RAILS_BENCH_DIR = File.join(Dir.pwd, "rails_ruby_bench")

# Cloned in ami.json, but go ahead and update anyway. This shouldn't normally do anything.
if RAILS_RUBY_BENCH_URL && RAILS_RUBY_BENCH_URL.strip != ""
  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "git remote add benchmark-url #{RAILS_RUBY_BENCH_URL} && git fetch benchmark-url", "error fetching commits from Rails Ruby Bench at #{RAILS_RUBY_BENCH_URL.inspect}"
    if RAILS_RUBY_BENCH_TAG.strip != ""
      csystem "git checkout benchmark-url/#{RAILS_RUBY_BENCH_TAG}", "Error checking out Rails Ruby Bench tag #{RAILS_RUBY_BENCH_TAG.inspect}"
    end
  end
end

# Install Rails Ruby Bench gems into system Ruby
Dir.chdir(RAILS_BENCH_DIR) do
  csystem "gem install bundler -v#{BUNDLER_VERSION}", "Couldn't install bundler for #{RAILS_BENCH_DIR} for system Ruby!", :bash => true
  csystem "rm Gemfile.lock && bundle _#{BUNDLER_VERSION}_", "Couldn't install RRB gems for #{RAILS_BENCH_DIR} for system Ruby!", :bash => true
end

benchmark_software["compare_rubies"].each do |ruby_hash|
  puts "Installing Ruby: #{ruby_hash.inspect}"
  # Clone the Ruby, then build and mount if necessary
  if ruby_hash["git_url"]
    work_dir = File.join(RAILS_BENCH_DIR, "work", ruby_hash["name"])
    ruby_hash["checkout_dir"] = work_dir
    clone_or_update_ruby_by_json(ruby_hash, work_dir)

    puts "Mount the built Ruby: #{ruby_hash.inspect}"

    ruby_name = ruby_hash["mount_name"] || ruby_hash["name"]
    Dir.chdir(RAILS_BENCH_DIR) do
      csystem "RBENV_VERSION=#{ruby_name} && gem install bundler -v#{BUNDLER_VERSION}", "Couldn't install Bundler in #{RAILS_BENCH_DIR} for Ruby #{ruby_name.inspect}!", :bash => true
    end

  elsif ruby_hash["ruby_build_name"]
    csystem "rbenv install #{ruby_hash["ruby_build_name"]}", "Couldn't use rbenv/ruby-build to install Ruby named #{ruby_hash["ruby_build_name"]}!"
    csystem "RBENV_VERSION=#{ruby_hash["ruby_build_name"]} && gem install bundler -v#{BUNDLER_VERSION}", "Couldn't install Bundler in #{RAILS_BENCH_DIR} for Ruby #{ruby_hash["ruby_build_name"].inspect}!", :bash => true
  end
end

puts "Create benchmark_ruby_versions.txt"
File.open("/home/ubuntu/benchmark_ruby_versions.txt", "w") do |f|
  rubies = benchmark_software["compare_rubies"].map { |h| h["mount_name"] || h["name"] || h["ruby_build_name"] || h["name"] }
  f.print rubies.join("\n")
end

clone_or_update_repo(DISCOURSE_URL, DISCOURSE_TAG, DISCOURSE_DIR)

Dir.chdir(RAILS_BENCH_DIR + "/work/discourse") do
  # If there are already users added, this should exit without error and not change the database
  puts "Adding seed data..."
  csystem "RAILS_ENV=profile rails runner ../../seed_db_data.rb", "Couldn't seed the database with profiling sample data!", :bash => true
end

FileUtils.touch "/tmp/setup_ran_correctly"
