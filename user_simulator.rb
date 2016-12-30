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

# TODO: allow overriding host and port
host = "http://localhost:4567"

def log(s)
  print "[#{Process.pid}]: #{s}\n"
end

class HttpClient
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
    resp = RestClient::Request.execute args
    @cookies = resp.cookies  # Maintain continuity of cookies
    resp
  end
end

log "Simulating activity for user id #{user.id}: #{user.name}"

log "Getting Rails CSRF token..."
HttpClient.get_csrf_token

log "Logging in as #{user.username.inspect}..."
HttpClient.request :post, "/session", { "login" => user.username, "password" => "password" }
HttpClient.request :post, "/login", { "login" => user.username, "password" => "password", "redirect" => "#{host}/" }

#resp = RestClient.execute :method => post, :url => "#{host}/session", :payload => { "login" => user.username, "password" => "password" }, :cookies => cookies, :headers => #{ "X-CSRF-Token" => csrf }
#cookies = resp.cookies


#resp = RestClient.post "#{host}/login", { "login" => user.username, "password" => "password", "redirect" => "#{host}/" }, { :cookies => cookies, "X-CSRF-Token" => csrf }
#cookies = resp.cookies

=begin
Login example:

Started GET "/session/csrf?_=1482880567812" for ::1 at 2016-12-27 15:16:18 -0800
Processing by SessionController#csrf as */*
  Parameters: {"_"=>"1482880567812"}
Completed 200 OK in 1ms (Views: 0.1ms | ActiveRecord: 0.0ms)
Started POST "/session" for ::1 at 2016-12-27 15:16:19 -0800
Processing by SessionController#create as */*
  Parameters: {"login"=>"admin0", "password"=>"[FILTERED]"}
Completed 200 OK in 317ms (Views: 0.1ms | ActiveRecord: 25.9ms)
Started POST "/login" for ::1 at 2016-12-27 15:16:19 -0800
Processing by StaticController#enter as HTML
  Parameters: {"username"=>"admin0", "password"=>"[FILTERED]", "redirect"=>"http://localhost:4567/"}
Redirected to http://localhost:4567/
Completed 302 Found in 5ms (ActiveRecord: 0.5ms)
Started GET "/" for ::1 at 2016-12-27 15:16:19 -0800
Processing by ListController#latest as HTML
  Rendered list/list.erb within layouts/application (3.6ms)
  Rendered layouts/_head.html.erb (0.2ms)
  Rendered common/_special_font_face.html.erb (0.1ms)
  Rendered common/_discourse_stylesheet.html.erb (0.1ms)
  Rendered application/_header.html.erb (0.1ms)
  Rendered common/_discourse_javascript.html.erb (0.3ms)
Completed 200 OK in 77ms (Views: 6.7ms | ActiveRecord: 11.2ms)
Started GET "/extra-locales/admin" for ::1 at 2016-12-27 15:16:19 -0800
Processing by ExtraLocalesController#show as */*
  Parameters: {"bundle"=>"admin"}
  Rendered text template (0.0ms)
Completed 200 OK in 10ms (Views: 0.3ms | ActiveRecord: 0.5ms)

=end


# TODO: fix number of actions
ACTION_TYPES = 4

# Randomize which action(s) to take, and randomize topic and reply data, plus a random number for offsets.
actions = (1..(iterations + warmup_iterations)).map { |i| [ i, (RNG.rand() * ACTION_TYPES).to_i + 1, sentence, RNG.rand() ] }


=begin
Started GET "/posts/151?_=1482866738618" for ::1 at 2016-12-27 13:51:17 -0800
Processing by PostsController#show as JSON
  Parameters: {"_"=>"1482866738618", "id"=>"151"}
Completed 200 OK in 93ms (Views: 0.2ms | ActiveRecord: 21.5ms)

Started GET "/composer_messages?composer_action=edit&topic_id=31&post_id=151&_=1482866738619" for ::1 at 2016-12-27 13:51:17 -0800
Processing by ComposerMessagesController#index as JSON
  Parameters: {"composer_action"=>"edit", "topic_id"=>"31", "post_id"=>"151", "_"=>"1482866738619"}
Completed 200 OK in 1507ms (Views: 0.2ms | ActiveRecord: 13.4ms)

Started GET "/composer_messages?composer_action=edit&topic_id=31&post_id=151&_=1482866738620" for ::1 at 2016-12-27 13:51:19 -0800
Processing by ComposerMessagesController#index as JSON
  Parameters: {"composer_action"=>"edit", "topic_id"=>"31", "post_id"=>"151", "_"=>"1482866738620"}
Completed 200 OK in 14ms (Views: 0.1ms | ActiveRecord: 4.7ms)

Started POST "/draft.json" for ::1 at 2016-12-27 13:51:19 -0800
Processing by DraftController#update as JSON
  Parameters: {"draft_key"=>"topic_31", "data"=>"{\"reply\":\"'Dinah'll miss me very much to-night, I should think!\\n' For, you see, so many out-of-the-way things had happened lately, that Alice had not a bit hurt, and she jumped up on to her very earnestly, 'Now, Dinah, tell me the truth did you ever saw.\\n'I hope they'll remember her saucer of milk at tea-time.\\ndown she came upon a low curtain she had peeped into the loveliest garden you ever eat a bat?\\n' So she was walking hand in hand with Dinah, and saying to her great disappointment it was good practice to say it over afterwards, it occurred to her feet in a moment to think about stopping herself before she found herself falling down a jar from one of the cupboards as she passed it was too small, but at the time it all seemed quite natural but when the Rabbit was no longer to be seen she found herself in a dreamy sort of way, 'Do cats eat bats?\",\"action\":\"edit\",\"title\":\"Down she came upon a low curtain she had peeped int\",\"categoryId\":11,\"postId\":151,\"archetypeId\":\"regular\",\"metaData\":null,\"composerTime\":2194}", "sequence"=>"0"}
Completed 200 OK in 13ms (Views: 0.2ms | ActiveRecord: 4.5ms)

Started PUT "/posts/151" for ::1 at 2016-12-27 14:06:19 -0800
Processing by PostsController#update as JSON
  Parameters: {"post"=>{"raw"=>"'Dinah'll miss me very much to-night, I should think!\n' For, you see, so many out-of-the-way things had happened lately, that Alice had not a bit hurt, and she jumped up on to her very earnestly, 'Now, Dinah, tell me the truth did you ever saw.\n'I hope they'll remember her saucer of milk at tea-time. And\ndown she came upon a low curtain she had peeped into the loveliest garden you ever eat a bat?\n' So she was walking hand in hand with Dinah, and saying to her great disappointment it was good practice to say it over afterwards, it occurred to her feet in a moment to think about stopping herself before she found herself falling down a jar from one of the cupboards as she passed it was too small, but at the time it all seemed quite natural but when the Rabbit was no longer to be seen she found herself in a dreamy sort of way, 'Do cats eat bats?", "edit_reason"=>"", "cooked"=>"\n      <p>'Dinah'll miss me very much to-night, I should think!<br>' For, you see, so many out-of-the-way things had happened lately, that Alice had not a bit hurt, and she jumped up on to her very earnestly, 'Now, Dinah, tell me the truth did you ever saw.<br>'I hope they'll remember her saucer of milk at tea-time. And<br>down she came upon a low curtain she had peeped into the loveliest garden you ever eat a bat?<br>' So she was walking hand in hand with Dinah, and saying to her great disappointment it was good practice to say it over afterwards, it occurred to her feet in a moment to think about stopping herself before she found herself falling down a jar from one of the cupboards as she passed it was too small, but at the time it all seemed quite natural but when the Rabbit was no longer to be seen she found herself in a dreamy sort of way, 'Do cats eat bats?</p>\n    "}, "id"=>"151"}
Completed 200 OK in 304ms (Views: 0.2ms | ActiveRecord: 68.3ms)
Started GET "/posts/151?_=1482866738621" for ::1 at 2016-12-27 14:06:20 -0800
Processing by PostsController#show as JSON
  Parameters: {"_"=>"1482866738621", "id"=>"151"}
Completed 200 OK in 11ms (Views: 0.1ms | ActiveRecord: 2.9ms)

Started DELETE "/posts/151" for ::1 at 2016-12-27 14:07:03 -0800
Processing by PostsController#destroy as */*
  Parameters: {"context"=>"/t/down-she-came-upon-a-low-curtain-she-had-peeped-int/31", "id"=>"151"}
  Rendered text template (0.0ms)
Completed 200 OK in 63ms (Views: 3.5ms | ActiveRecord: 16.7ms)
Started GET "/posts/151?_=1482866738622" for ::1 at 2016-12-27 14:07:03 -0800
Processing by PostsController#show as JSON
  Parameters: {"_"=>"1482866738622", "id"=>"151"}
Completed 200 OK in 13ms (Views: 0.1ms | ActiveRecord: 4.0ms)



Topic deletion example:

Started GET "/t/down-she-came-upon-a-low-curtain-she-had-peeped-int/31" for ::1 at 2016-12-27 15:02:36 -0800
Processing by TopicsController#show as HTML
  Parameters: {"slug"=>"down-she-came-upon-a-low-curtain-she-had-peeped-int", "topic_id"=>"31"}
  Rendered topics/show.html.erb within layouts/application (2.2ms)
  Rendered layouts/_head.html.erb (0.2ms)
  Rendered common/_special_font_face.html.erb (0.1ms)
  Rendered common/_discourse_stylesheet.html.erb (0.2ms)
  Rendered application/_header.html.erb (0.1ms)
  Rendered common/_discourse_javascript.html.erb (0.2ms)
Completed 200 OK in 78ms (Views: 5.2ms | ActiveRecord: 13.4ms)
Started GET "/extra-locales/admin" for ::1 at 2016-12-27 15:02:36 -0800
Processing by ExtraLocalesController#show as */*
  Parameters: {"bundle"=>"admin"}
  Rendered text template (0.0ms)
Completed 200 OK in 10ms (Views: 0.3ms | ActiveRecord: 0.5ms)
Started GET "/t/31/posts.json?post_ids%5B%5D=256&post_ids%5B%5D=325&_=1482879756392" for ::1 at 2016-12-27 15:02:41 -0800
Processing by TopicsController#posts as JSON
  Parameters: {"post_ids"=>["256", "325"], "_"=>"1482879756392", "topic_id"=>"31"}
Completed 200 OK in 32ms (Views: 0.1ms | ActiveRecord: 11.7ms)
Started GET "/notifications?recent=true&limit=13&_=1482879756393" for ::1 at 2016-12-27 15:03:09 -0800
Processing by NotificationsController#index as JSON
  Parameters: {"recent"=>"true", "limit"=>"13", "_"=>"1482879756393"}
Completed 200 OK in 20ms (Views: 0.1ms | ActiveRecord: 6.7ms)
Started GET "/t/41/2.json?track_visit=true&forceLoad=true&_=1482879756394" for ::1 at 2016-12-27 15:03:14 -0800
Processing by TopicsController#show as JSON
  Parameters: {"track_visit"=>"true", "forceLoad"=>"true", "_"=>"1482879756394", "topic_id"=>"41", "post_number"=>"2"}
Completed 200 OK in 49ms (Views: 0.1ms | ActiveRecord: 10.8ms)
Started DELETE "/t/41" for ::1 at 2016-12-27 15:03:26 -0800
Processing by TopicsController#destroy as */*
  Parameters: {"context"=>"/t/and-what-an-ignorant-little-girl-shell-think-me-f/41", "id"=>"41"}
  Rendered text template (0.0ms)
Completed 200 OK in 55ms (Views: 0.3ms | ActiveRecord: 14.8ms)
Started GET "/posts/44?_=1482879756395" for ::1 at 2016-12-27 15:03:26 -0800
Processing by PostsController#show as JSON
  Parameters: {"_"=>"1482879756395", "id"=>"44"}
Completed 200 OK in 10ms (Views: 0.1ms | ActiveRecord: 1.8ms)

=end


(iterations + warmup_iterations).times do |i|
  case actions[i][1]
  when 1
    # Read Topic
    # Example URL: http://localhost:4567/t/down-she-came-upon-a-low-curtain-she-had-peeped-int/31
    sleep 0.1
  when 2
    # Write draft
    # Example URL: POST http://localhost:4567/draft.json
    sleep 0.1
  when 3
    # Update
    sleep 0.1
  when 4
    # Reply
    sleep 0.1
  else
    raise "Something is wrong! Illegal value: #{actions[i][1]}"
  end
end

=begin
while true
  print "Creating a random topic\n"
  category = Category.where(read_restricted: false).order('random()').first
  PostCreator.create(user, raw: sentence, title: sentence[0..50].strip, category:  category.name)

  print "creating random reply\n"
  PostCreator.create(user, raw: sentence, topic_id: last_topics.sample)

  sleep 2
end
=end
