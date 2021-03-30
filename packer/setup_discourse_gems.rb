#!/usr/bin/env ruby

require "fileutils"
require "json"

# Print all commands and show their full output
VERBOSE = true

base = "/home/ubuntu"
benchmark_software = JSON.load(File.read("#{base}/benchmark_software.json"))

class SystemPackerBuildError < RuntimeError; end

print <<SETUP
=========
Running setup_discourse_gems.rb for Ruby-related software...
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

RAILS_BENCH_DIR = File.join(Dir.pwd, "rails_ruby_bench")
DISCOURSE_DIR = File.join(RAILS_BENCH_DIR, "work", "discourse")

BUNDLER_VERSION = benchmark_software["bundler"]["version"]

# Installing the Discourse gems takes awhile. Like, a *long*
# while. And Packer turns out to have a bug where a step that takes
# over five minutes can quietly fail without raising an error. So not
# only do we touch the file (to make sure this worked), we also split
# out installing Discourse's gems into its own step.

benchmark_software["compare_rubies"].each do |ruby_hash|
  ruby_hash["found_name"] = ruby_hash["ruby_build_name"] || ruby_hash["name"]
end

first_ruby = nil

benchmark_software["compare_rubies"].each do |hash|
  next unless hash["found_name"]
  next if hash.has_key("discourse") && !hash["discourse"]

  ruby_name = hash["found_name"]
  first_ruby ||= ruby_name
  puts "Install Discourse gems in Ruby: #{ruby_name.inspect}"
  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "rbenv shell #{ruby_name} && gem install bundler -v#{BUNDLER_VERSION} && bundle _#{BUNDLER_VERSION}_", "Couldn't install Discourse gems in #{DISCOURSE_DIR} for Ruby #{ruby_name.inspect}!", :bash => true
  end
end

# TODO: Uncomment this section once it becomes possible to run the benchmark

#if !first_ruby
#  raise "Couldn't find any Discourse-capable Ruby to run the benchmark..."
#end

# And check to make sure the benchmark actually runs... But just do a few iterations.
#Dir.chdir(RAILS_BENCH_DIR) do
#  begin
#    csystem "rbenv shell #{first_ruby} && bundle exec ./start.rb -s 1 -n 1 -i 10 -w 0 -o /tmp/ -c 1", "Couldn't successfully run the benchmark!", :bash => true
#  rescue SystemPackerBuildError
#    # Before dying, let's look at that Rails logfile... Redirect stdout to stderr.
#    print "Error running test iterations of the benchmark, printing Rails log to console!\n==========\n"
#    print `tail -60 work/discourse/log/profile.log`   # If we echo too many lines they just get cut off by Packer
#    print "=============\n"
#    raise # Re-raise the error, we still want to die.
#  end
#end

FileUtils.touch "/tmp/setup_discourse_gems_ran_correctly"
