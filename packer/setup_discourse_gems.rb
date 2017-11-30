#!/usr/bin/env ruby

require "fileutils"
require "json"

# Pass --local to run the setup on a local machine, or set RRB_LOCAL
LOCAL = (ARGV.delete '--local') || ENV["RRB_LOCAL"]
# Whether to build rubies with rvm
BUILD_RUBY = !LOCAL
USE_BASH = BUILD_RUBY
# Print all commands and show their full output
#VERBOSE = LOCAL
VERBOSE = true

base = LOCAL ? File.expand_path('..', __FILE__) : "/home/ubuntu"
benchmark_software = JSON.load(File.read("#{base}/benchmark_software.json"))

DISCOURSE_GIT_URL    = benchmark_software["discourse"]["git_url"]
DISCOURSE_TAG        = benchmark_software["discourse"]["git_tag"]

class SystemPackerBuildError < RuntimeError; end

print <<SETUP
=========
Running setup_discourse_gems.rb for Ruby-related software...
=========
SETUP

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  cmd = "bash -l -c \"#{cmd}\"" if USE_BASH && opts[:bash]
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

if LOCAL
  RAILS_BENCH_DIR = File.expand_path("../..", __FILE__)
else
  RAILS_BENCH_DIR = File.join(Dir.pwd, "rails_ruby_bench")
end
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")

# We can't easily match up the benchmark_software entries with Ruby names...
Dir["#{ENV["HOME"]}/.rvm/rubies/*"].each do |ruby_name|
  ruby_name = ruby_name.split("/")[-1]
  next if ["default", "ruby-2.3.1"].include?(ruby_name)  # Don't bother with the system Ruby or default

  puts "Install Discourse gems in Ruby: #{ruby_name.inspect}"
  Dir.chdir(DISCOURSE_DIR) do
    csystem "rvm use #{ruby_name} && bundle", "Couldn't install Discourse gems in #{DISCOURSE_DIR} for Ruby #{ruby_name.inspect}!", :bash => true
  end
end

FileUtils.touch "/tmp/setup_discourse_gems_ran_correctly"
