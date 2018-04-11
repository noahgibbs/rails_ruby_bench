#!/usr/bin/env ruby

require "json"
require "optparse"

cohorts_by = "RUBY_VERSION,warmup_iterations,discourse_revision,random_seed"
input_glob = "rails_ruby_bench_*.json"

OptionParser.new do |opts|
  opts.banner = "Usage: ruby process.rb [options]"
  opts.on("-c", "--cohorts-by COHORTS", "Variables to partition data by, incl. RUBY_VERSION,warmup_iterations,etc.") do |c|
    cohorts_by = c  #.to_i
  end
  opts.on("-i", "--input-glob GLOB", "File pattern to match on (default *.json)") do |s|
    input_glob = s
  end
end.parse!

OUTPUT_FILE = "process_output.json"

cohort_indices = cohorts_by.strip.split(",")

req_time_by_cohort = {}
run_by_cohort = {}
throughput_by_cohort = {}
startup_by_cohort = {}

INPUT_FILES = Dir[input_glob]

process_output = {
  cohort_indices: cohort_indices,
  input_files: INPUT_FILES,
  req_time_by_cohort: req_time_by_cohort,
  run_by_cohort: run_by_cohort,
  throughput_by_cohort: throughput_by_cohort,
  startup_by_cohort: startup_by_cohort,
  processed: {
    :cohort => {},
  },
}

INPUT_FILES.each do |f|
  d = JSON.load File.read(f)

  # Assign a cohort to these samples
  cohort_parts = cohort_indices.map do |cohort_elt|
    raise "Unexpected file format for file #{f.inspect}!" unless d && d["settings"] && d["environment"]
    item = nil
    if d["settings"].has_key?(cohort_elt)
      item = d["settings"][cohort_elt]
    elsif d["environment"].has_key?(cohort_elt)
      item = d["environment"][cohort_elt]
    else
      raise "Can't find setting or environment object #{cohort_elt}!"
    end
    item
  end
  cohort = cohort_parts.join(",")

  # Update data format to latest version
  if d["version"].nil?
    times = d["requests"]["times"].flat_map do |items|
      out_items = []
      cur_time = 0.0
      items.each do |i|
        out_items.push(i - cur_time)
        cur_time = i
      end
      out_items
    end
    runs = d["requests"]["times"].map { |thread_times| thread_times[-1] }
    raise "Error with request times! #{d["requests"]["times"].inspect}" if runs.nil? || runs.any?(:nil?)
  elsif [2,3].include?(d["version"])
    times = d["requests"]["times"].flatten(1)
    runs = d["requests"]["times"].map { |thread_times| thread_times.inject(0.0, &:+) }
  else
    raise "Unrecognized data version #{d["version"].inspect} in JSON file #{f.inspect}!"
  end

  startup_by_cohort[cohort] ||= []
  startup_by_cohort[cohort].concat d["startup"]["times"]

  req_time_by_cohort[cohort] ||= []
  req_time_by_cohort[cohort].concat times

  run_by_cohort[cohort] ||= []
  run_by_cohort[cohort].push runs

  throughput_by_cohort[cohort] ||= []
  throughput_by_cohort[cohort].push (d["requests"]["times"].flatten.size / runs.max) unless runs.empty?
end

def percentile(list, pct)
  len = list.length
  how_far = pct * 0.01 * (len - 1)
  prev_item = how_far.to_i
  return list[prev_item] if prev_item >= len - 1
  return list[0] if prev_item < 0

  linear_combination = how_far - prev_item
  list[prev_item] + (list[prev_item + 1] - list[prev_item]) * linear_combination
end

def array_mean(arr)
  return nil if arr.empty?
  arr.inject(0.0, &:+) / arr.size
end

# Calculate variance based on the Wikipedia article of algorithms for variance.
# https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
# Includes Bessel's correction.
def array_variance(arr)
  n = arr.size
  return nil if arr.empty? || n < 2

  ex = ex2 = 0
  arr.each do |x|
    diff = x - arr[0]
    ex += diff
    ex2 += diff * diff
  end

  (ex2 - (ex * ex) / arr.size) / (arr.size - 1)
end

req_time_by_cohort.keys.sort.each do |cohort|
  data = req_time_by_cohort[cohort]
  data.sort! # Sort request times lowest-to-highest for use with percentile()
  runs = run_by_cohort[cohort]
  flat_runs = runs.flatten.sort
  run_longest = runs.map { |worker_times| worker_times.max }
  throughputs = throughput_by_cohort[cohort].sort
  startup_times = startup_by_cohort[cohort].sort

  cohort_printable = cohort_indices.zip(cohort.split(",")).map { |a, b| "#{a}: #{b}" }.join(", ")
  print "=====\nCohort: #{cohort_printable}, # of data points: #{data.size} http / #{startup_times.size} startup, full runs: #{runs.size}\n"
  process_output[:processed][:cohort][cohort] = {
    data_points: data.size,
    full_runs: runs.size,
    request_percentiles: {},
    run_percentiles: {},
    throughputs: throughputs,
  }
  [0, 1, 5, 10, 50, 90, 95, 99, 100].each do |p|
    process_output[:processed][:cohort][cohort][:request_percentiles][p.to_s] = percentile(data, p)
    print "  #{"%2d" % p}%ile: #{percentile(data, p)}\n"
  end

  print "--\n  Overall thread completion times:\n"
  [0, 10, 50, 90, 100].each do |p|
    process_output[:processed][:cohort][cohort][:run_percentiles][p.to_s] = percentile(flat_runs, p)
    print "  #{"%2d" % p}%ile: #{percentile(flat_runs, p)}\n"
  end

  print "--\n  Throughput in reqs/sec for each full run:\n"
  print "  Mean: #{array_mean(throughputs).inspect} Median: #{percentile(throughputs, 50).inspect} Variance: #{array_variance(throughputs).inspect}\n"
  process_output[:processed][:cohort][cohort][:throughput_mean] = array_mean(throughputs)
  process_output[:processed][:cohort][cohort][:throughput_median] = percentile(throughputs, 50)
  process_output[:processed][:cohort][cohort][:throughput_variance] = array_variance(throughputs)
  print "  #{throughputs.inspect}\n\n"

  process_output[:processed][:cohort][cohort][:startup_mean] = array_mean(startup_times)
  process_output[:processed][:cohort][cohort][:startup_median] = percentile(startup_times, 50)
  process_output[:processed][:cohort][cohort][:startup_variance] = array_variance(startup_times)
  print "--\n  Startup times for this cohort:\n"
  print "  Mean: #{array_mean(startup_times).inspect} Median: #{percentile(startup_times, 50).inspect} Variance: #{array_variance(startup_times).inspect}\n"
end

print "******************\n"

File.open(OUTPUT_FILE, "w") do |f|
  f.print JSON.pretty_generate(process_output)
end
