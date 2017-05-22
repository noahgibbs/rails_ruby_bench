#!/usr/bin/env ruby

require "json"
require "erubis"

RICKSHAW_TEMPLATE_PATH = File.join(__dir__, "rickshaw_template.html.erb")
RICKSHAW_TEMPLATE = File.read RICKSHAW_TEMPLATE_PATH

OUTPUT_FILE = "rickshaw_graph.html"

raise "Wrong number of arguments!" if ARGV.size != 1
input_data = JSON.load File.read(ARGV[0])

er = Erubis::Eruby.new(RICKSHAW_TEMPLATE)

output = er.result :data => input_data

File.open(OUTPUT_FILE, "w") do |f|
  f.print output
end

print "Opening #{OUTPUT_FILE.inspect} in Chrome..."
system "open -a \"Google Chrome.app\" #{OUTPUT_FILE}"
if $?.success?
  print " (Succeeded!)\n"
else
  print " (Failed! #{$?.to_i})\n"
end
