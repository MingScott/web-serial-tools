#!/usr/bin/env ruby
require "json"
require "nokogiri"
require "open-uri"

url = ARGV[0]
id = url.split("/")[4]
rss = "https://www.royalroad.com/fiction/syndication/"+id
cover = Nokogiri::HTML URI.open(url)
title = cover.css("h1[property=name]").inner_text

feeds = JSON.load(
	File.read(
		"conf/feeds.json"
		)
	)

feeds[title] = rss
json_feeds = JSON.pretty_generate(feeds)
File.write("conf/feeds.json",json_feeds)