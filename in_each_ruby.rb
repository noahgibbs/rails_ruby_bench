#!/usr/bin/env ruby

# Run start.rb with the specified arguments in all the marked-as-installed Rubies in the Rails Ruby Bench installation.

RUBIES = File.read("/home/ubuntu/benchmark_ruby_versions.txt").split("\n")

RUBIES.each do |ruby|
  system("bash -l -c \"rvm use #{ruby} && #{ARGV.join(" ")}\"")
end
