#!/usr/bin/env ruby

require "fileutils"
require "json"

# Print all commands and show their full output
VERBOSE = true

Dir.mkdir "/var/rubies"
benchmark_software = JSON.load(File.read("/tmp/benchmark_software.json"))

DISCOURSE_DIR = "/var/www/discourse"
RAILS_BENCH_DIR = "/var/rails_ruby_bench"

class SystemPackerBuildError < RuntimeError; end

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
  csystem "ln -s #{source_dir} ~/.rbenv/versions/#{mount_name}", "Couldn't mount #{source_dir.inspect} as #{mount_name}!", :bash => true
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
  prefix_dir = h["prefix_dir"] || "/home/discourse/.rbenv/versions/#{mount_name.gsub("/", "_")}"

  build_and_mount_ruby(h["checkout_dir"], prefix_dir, mount_name, { "configure_options" => h["configure_options"] || "" } )
  h["mount_name"] = mount_name
end

# Build and mount each Ruby and install all gems
benchmark_software["compare_rubies"].each do |ruby_hash|
  puts "Installing Ruby: #{ruby_hash.inspect}"
  # Clone the Ruby, then build and mount if necessary
  if ruby_hash["git_url"]
    work_dir = File.join("/var/rubies", ruby_hash["name"])
    ruby_hash["checkout_dir"] = work_dir
    clone_or_update_ruby_by_json(ruby_hash, work_dir)
  end

  puts "Mounted the built Ruby: #{ruby_hash.inspect}"

  mount_ruby_name = ruby_hash["mount_name"] || ruby_hash["name"]
  csystem "rbenv shell #{mount_ruby_name} && gem install bundler mailcatcher", "Couldn't install bundler and/or mailcatcher for Ruby #{mount_ruby_name.inspect}!", :bash => true

  Dir.chdir(RAILS_BENCH_DIR) do
    csystem "rbenv shell #{mount_ruby_name} && bundle", "Couldn't install RRB gems in #{RAILS_BENCH_DIR} for Ruby #{mount_ruby_name.inspect}!", :bash => true
  end

  Dir.chdir(DISCOURSE_DIR) do
    csystem "rbenv shell #{mount_ruby_name} && bundle", "Couldn't install Discourse gems in #{DISCOURSE_DIR} for Ruby #{mount_ruby_name.inspect}!", :bash => true
  end
end

puts "Create benchmark_ruby_versions.txt"
File.open("/var/benchmark_ruby_versions.txt", "w") do |f|
  rubies = benchmark_software["compare_rubies"].map { |h| h["mount_name"] || h["name"] }
  f.print rubies.join("\n")
end

Dir.chdir(DISCOURSE_DIR) do
  csystem("RAILS_ENV=profile bundle exec rake db:create db:migrate", "Couldn't create Discourse database!", :bash => true)
  unless File.exists?("public/assets")
    csystem("RAILS_ENV=profile bundle exec rake assets:precompile", "Failed to precompile Discourse assets!", :bash => true)
  end
end
