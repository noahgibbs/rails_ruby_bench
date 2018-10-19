#!/usr/bin/env ruby

DISCOURSE_DIR = "/var/www/discourse"
APP_CONTROLLER = File.join(DISCOURSE_DIR, "app/controllers/application_controller.rb")

PATCHED_SNIPPET = "protect_from_forgery only: []"
UNPATCHED_SNIPPET = "protect_from_forgery"


contents = File.read(APP_CONTROLLER)
if contents[PATCHED_SNIPPET]
  # All is well, ignore
  print "File #{APP_CONTROLLER} is already patched, continuing.\n"
else
  # Patch the file
  print "File #{APP_CONTROLLER} is not yet patched - patching.\n"
  contents.gsub!(UNPATCHED_SNIPPET, PATCHED_SNIPPET)
  File.open(APP_CONTROLLER, "w") { |f| f.write(contents) }
end
