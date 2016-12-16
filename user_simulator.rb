#!/usr/bin/env ruby

# Closely based on Discourse's user_simulator script

require 'optparse'
require 'gabbler'

unless ["profile", "development"].include? Rails.env
  puts "Bad idea to run a script that inserts random posts in any non development environment"
  exit
end

user_id = nil
random_seed = nil
delay = nil
iterations = 100
warmup_iterations = 50

OptionParser.new do |opts|
  opts.banner = "Usage: ruby user_simulator.rb [options]"
  opts.on("-u", "--user NUMBER", "user id") do |u|
    user_id = u.to_i
  end
  opts.on("-r", "--random-seed NUMBER", "random seed") do |r|
    random_seed = r
  end
  opts.on("-d", "--delay NUMBER", "delay") do |d|
    delay = d
  end
  opts.on("-n", "--number NUMBER", "number of iterations") do |n|
    iterations = n
  end
  opts.on("-w", "--warmup NUMBER", "number of warm-up iterations") do |n|
    warmup_iterations = n
  end
end.parse!

unless user_id
  puts "user must be specified"
  exit
end

# We want our script to generate a consistent output, so
# we monkeypatch Array#sample to use our RNG.
RNG = Random.new(random_seed)
class Array
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

user = User.find(user_id)
last_topics = Topic.order('id desc').limit(10).pluck(:id)

puts "Simulating activity for user id #{user.id}: #{user.name}"

# We want four actions - read, write, update and reply
ACTION_TYPES = 4

# Randomize which action(s) to take, and randomize topic and reply data, plus a random number for offsets.
actions = (1..(iterations + warmup_iterations)).map { |i| [ i, RNG.rand() * ACTION_TYPES + 1, sentence, RNG.rand() ] }

(iterations + warmup_iterations).times do |i|
  case actions[i][1]
  when 1
    # Read
  when 2
    # Write
  when 3
    # Update
  when 4
    # Reply
  else
    raise "Something is wrong!"
  end
end

=begin
while true
  puts "Creating a random topic"
  category = Category.where(read_restricted: false).order('random()').first
  PostCreator.create(user, raw: sentence, title: sentence[0..50].strip, category:  category.name)

  puts "creating random reply"
  PostCreator.create(user, raw: sentence, topic_id: last_topics.sample)

  sleep 2
end
=end
