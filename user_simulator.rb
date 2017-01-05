#!/usr/bin/env ruby

# Initially based on Discourse's user_simulator script

require 'optparse'
require 'gabbler'
#require 'rest-client'
#require 'json'

require File.expand_path(File.join(File.dirname(__FILE__), "work/discourse/config/environment"))

unless ["profile", "development"].include? Rails.env
  print "User simulator prefers to be run in profile or development, not #{ENV["RAILS_ENV"].inspect}.\n"
  exit -1
end

user_offset = 0
random_seed = 1234567890
delay = nil
iterations = 100
warmup_iterations = 0

OptionParser.new do |opts|
  opts.banner = "Usage: ruby user_simulator.rb [options]"
  opts.on("-o", "--user-offset NUMBER", "user offset") do |u|
    user_offset = u.to_i
  end
  opts.on("-r", "--random-seed NUMBER", "random seed") do |r|
    random_seed = r.to_i
  end
  opts.on("-d", "--delay NUMBER", "delay") do |d|
    delay = d.to_f
  end
  opts.on("-n", "--number NUMBER", "number of iterations") do |n|
    iterations = n.to_i
  end
  opts.on("-w", "--warmup NUMBER", "number of warm-up iterations") do |n|
    warmup_iterations = n.to_i
  end
end.parse!

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

user = User.offset(user_offset).first
unless user
  print "No user at offset #{user_offset.inspect}! Exiting.\n"
  exit -1
end
last_topics = Topic.order('id desc').limit(10).pluck(:id)
last_posts = Post.order('id desc').limit(10).pluck(:id)

# TODO: allow overriding host and port
host = "http://localhost:4567"

def log(s)
  print "[#{Process.pid}]: #{s}\n"
end

class DiscourseClient
  @cookies = nil
  @csrf = nil
  @prefix = "http://localhost:4567"

  def self.get_csrf_token
    resp = RestClient.get "#{@prefix}/session/csrf.json"
    @cookies = resp.cookies
    @csrf = JSON.parse(resp.body)["csrf"]
  end

  def self.request(method, url, payload = nil)
    args = { :method => method, :url => "#{@prefix}#{url}", :cookies => @cookies, :headers => { "X-CSRF-Token" => @csrf } }
    args[:payload] = payload if payload
    begin
      resp = RestClient::Request.execute args
    rescue RestClient::Found => e  # 302 redirect
      resp = e.response
    end
    @cookies = resp.cookies  # Maintain continuity of cookies
    resp
  end
end

log "Simulating activity for user id #{user.id}: #{user.name}"

log "Getting Rails CSRF token..."
DiscourseClient.get_csrf_token

log "Logging in as #{user.username.inspect}..."
DiscourseClient.request :post, "/session", { "login" => user.username, "password" => "password" }
DiscourseClient.request :post, "/login", { "login" => user.username, "password" => "password", "redirect" => "#{host}/" }

# TODO: fix number of actions
ACTIONS = [:read_topic, :post_reply, :post_topic, :get_latest]  # Not active: :save_draft, :delete_reply. See below.
ACTION_TYPES = ACTIONS.size

# Randomize which action(s) to take, and randomize topic and reply data, plus a random number for offsets.
# Since we don't randomize again after this, the random seed's effect is limited to this line and before.
actions = (1..(iterations + warmup_iterations)).map { |i| [ i, (RNG.rand() * ACTION_TYPES).to_i, sentence, RNG.rand() ] }

(iterations + warmup_iterations).times do |i|
  case ACTIONS[actions[i][1]]
  when :read_topic
    # Read Topic
    topic_id = last_topics[-1]
    DiscourseClient.request(:get, "/t/#{topic_id}.json?track_visit=true&forceLoad=true")
  when :save_draft
    # Save draft - currently not active, need to fix 403. Wrong topic ID?
    topic_id = last_topics[-1]
    post_id = last_posts[-1]  # Not fully correct
    draft_hash = { "reply" => "foo" * 50, "action" => "edit", "title" => "Title of draft reply", "categoryId" => 11, "postId" => post_id, "archetypeId" => "regular", "metaData" => nil, "sequence" => 0 }
    DiscourseClient.request(:post, "/draft.json", "draft_key" => "topic_#{topic_id}", "data" => draft_hash.to_json)
  when :post_reply
    # Post reply
    DiscourseClient.request(:post, "/posts", "raw" => "", "unlist_topic" => "false", "category" => "9", "topic_id" => topic_id, "is_warning" => "false", "archetype" => "regular", "typing_during_msecs" => "2900", "composer_open_duration_msecs" => "12114", "featured_link" => "", "nested_post" => "true")
    # TODO: DiscourseClient.request(:delete, "/draft.json", "draft_key" => "topic_XX", "sequence" => "0")
  when :post_topic
    # Post new topic
    DiscourseClient.request(:post, "/posts", "raw" => "", "title" => "", "unlist_topic" => "false", "category" => "", "is_warning" => "false", "archetype" => "regular", "typing_duration_msecs" => "6300", "composer_open_duration_msecs" => "31885", "nested_post" => "true")
    # TODO: DiscourseClient.request(:delete, "/draft.json", "topic_id" => "topic_XX")
    # TODO: DiscourseClient.request(:get, "/t/#{topic_id}.json?track_visit=true&forceLoad=true")
=begin
Started GET "/composer_messages?composer_action=createTopic&_=1483481672874" for ::1 at 2017-01-03 14:39:19 -0800
lProcessing by ComposerMessagesController#index as JSON
  Parameters: {"composer_action"=>"createTopic", "_"=>"1483481672874"}
Completed 200 OK in 27ms (Views: 0.1ms | ActiveRecord: 1.6ms)
Started GET "/similar_topics?title=This%20is%20a%20new%20topic.%20Totally.&raw=And%20this%20is%20the%20body.%20Yup!%20It%27s%20awesome.%0A&_=1483481672875" for ::1 at 2017-01-03 14:39:32 -0800
Processing by SimilarTopicsController#index as JSON
  Parameters: {"title"=>"This is a new topic. Totally.", "raw"=>"And this is the body. Yup! It's awesome.\n", "_"=>"1483481672875"}
Completed 200 OK in 35ms (Views: 0.1ms | ActiveRecord: 16.0ms)
Started POST "/draft.json" for ::1 at 2017-01-03 14:39:34 -0800
Processing by DraftController#update as JSON
  Parameters: {"draft_key"=>"new_topic", "data"=>"{\"reply\":\"And this is the body. Yup! It's awesome.\\n\",\"action\":\"createTopic\",\"title\":\"This is a new topic. Totally.\",\"categoryId\":null,\"postId\":null,\"archetypeId\":\"regular\",\"metaData\":null,\"composerTime\":14745,\"typingTime\":5000}", "sequence"=>"2"}
Completed 200 OK in 14ms (Views: 0.3ms | ActiveRecord: 5.1ms)
Started GET "/similar_topics?title=This%20is%20a%20new%20topic.%20Totally.&raw=And%20this%20is%20the%20body.%20Yup!%20It%27s%20awesome.%20Totally%20awesome.%0A&_=1483481672876" for ::1 at 2017-01-03 14:39:42 -0800
Processing by SimilarTopicsController#index as JSON
  Parameters: {"title"=>"This is a new topic. Totally.", "raw"=>"And this is the body. Yup! It's awesome. Totally awesome.\n", "_"=>"1483481672876"}
Completed 200 OK in 23ms (Views: 0.1ms | ActiveRecord: 8.9ms)
Started POST "/draft.json" for ::1 at 2017-01-03 14:39:42 -0800
Processing by DraftController#update as JSON
  Parameters: {"draft_key"=>"new_topic", "data"=>"{\"reply\":\"And this is the body. Yup! It's awesome. Totally awesome.\\n\",\"action\":\"createTopic\",\"title\":\"This is a new topic. Totally.\",\"categoryId\":null,\"postId\":null,\"archetypeId\":\"regular\",\"metaData\":null,\"composerTime\":23385,\"typingTime\":6300}", "sequence"=>"2"}
Completed 200 OK in 8ms (Views: 0.2ms | ActiveRecord: 1.4ms)
=end
  when :delete_reply
    # Delete reply, currently not active, need to get correct Post ID
    #DiscourseClient.request(:delete, "/posts/#{post_num}")
    #DiscourseClient.request(:get, "/posts/#{post_num - 1}")
    sleep 0.1
  when :get_latest
    # Get latest
    DiscourseClient.request(:get, "/latest.json?order=default")
  else
    raise "Something is wrong! Illegal value: #{actions[i][1]}"
  end
end
