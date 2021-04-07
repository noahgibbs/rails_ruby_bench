# This script should be run with "rails runner seed_db_data.rb"

# Based on Discourse's profile_db_generator

require 'optparse'
require 'gabbler'

random_seed = 2546769937
do_drop = false

STDERR.puts "ARGS: #{ARGV.inspect}"

OptionParser.new do |opts|
  opts.banner = "Usage: RAILS_ENV=profile ruby seed_db_data.rb [options]"
  opts.on("-r", "--random-seed NUMBER", "random seed") do |r|
    random_seed = r
  end
  opts.on("-d", "--drop", "drop existing database and re-migrate first") do
    do_drop = true
  end
end.parse!

# Set the constant
RANDOM_SEED = random_seed

# we want our script to generate a consistent output, to do so
#  we monkey patch array sample so it always uses the same rng.
# All randomization in this script uses .sample.
class Array
  RNG = Random.new(RANDOM_SEED)

  def sample
    self[RNG.rand(size)]
  end
end

def sentence
  @gabbler ||= Gabbler.new.tap do |gabbler|
    story = File.read(File.dirname(__FILE__) + "/alice.txt")
    gabbler.learn(story)
  end

  sentence = ""
  until sentence.length > 800 do
    sentence << @gabbler.sentence
    sentence << "\n"
  end
  sentence
end

def create_admin(seq)
  User.new.tap { |admin|
    admin.email = "admin@fake#{seq}.appfolio.com"
    admin.username = "admin#{seq}"
    admin.password = "longpassword"
    admin.save!
    admin.grant_admin!
    admin.change_trust_level!(TrustLevel[4])
    admin.email_tokens.update_all(confirmed: true)
    admin.activate  # Added after activation seemed not to work
    admin.approved = true
    admin.active = true
    admin.save!
  }
end

unless Rails.env == "profile"
  puts "This script should only be used in the profile environment"
  exit
end

if do_drop
  system "cd #{Rails.root} && RAILS_ENV=profile rake db:drop db:create db:migrate"
end

SiteSetting.queue_jobs = false

# by default, Discourse has a "system" account
if User.count > 1
  puts "Only run this script against an empty DB (and in RAILS_ENV=profile)"
  exit
end

puts "Creating 100 users"
users = 100.times.map do |i|
  putc "."
  create_admin(i)
end

puts
puts "Creating 10 categories"
categories = 10.times.map do |i|
  putc "."
  Category.create(name: "category#{i}", text_color: "ffffff", color: "000000", user: users.first)
end

puts
puts "Creating 100 topics"

topic_ids = 100.times.map do
  post = PostCreator.create(users.sample, raw: sentence, title: sentence[0..50].strip, category:  categories.sample.name, skip_validations: true)

  putc "."
  post.topic_id
end

puts
puts "creating 200 replies"  # PostCreator is just crazy slow. Why?
200.times do
  putc "."
  PostCreator.create(users.sample, raw: sentence, topic_id: topic_ids.sample, skip_validations: true)
end

# no sidekiq so update some stuff
Category.update_stats
Jobs::PeriodicalUpdates.new.execute(nil)

