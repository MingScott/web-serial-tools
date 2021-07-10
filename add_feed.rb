#!/usr/bin/env ruby
require "json"
feed_name = ARGV[0]
feed_url = ARGV[1]
feeds = JSON.load(
	File.read(
		"conf/feeds.json"
		)
	)

feeds[feed_name] = feed_url
json_feeds = JSON.pretty_generate(feeds)
File.write("conf/feeds.json",json_feeds)