#!/usr/bin/env ruby

DISCOURSE_DIR = "/var/www/discourse"

Dir.chdir(DISCOURSE_DIR) do
  conf_db = File.read "config/database.yml"
  new_contents = conf_db.gsub("pool: 5", "pool: 30") # Increase connection pool size
  if new_contents != conf_db
    File.open("config/database.yml", "w") do |f|
      f.print new_contents
    end
  end
end

puts "Add assets.rb initializer for Discourse"
# Minor bugfix for this version of Discourse. Can remove when I only use 1.8.0+ Discourse?
# TODO: test removing
assets_init_path = File.join(DISCOURSE_DIR, "config/initializers/assets.rb")
unless File.exists?(assets_init_path)
  File.open(assets_init_path, "w") do |f|
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
app_controller_path = File.join(DISCOURSE_DIR, "app/controllers/application_controller.rb")
contents = File.read(app_controller_path)
original_line = "protect_from_forgery"
patched_line = "#protect_from_forgery"
unless contents[patched_line]
  File.open(app_controller_path, "w") do |f|
    f.print contents.gsub(original_line, patched_line)
  end
end
