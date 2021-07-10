require 'json'
require 'mail'
require 'nokogiri'
require 'open-uri'
require 'concurrent'
require_relative 'lib/rss-feed'
include RssFeed

threads = []
feeds = []
File.read("conf/feeds.json").yield_self do |text|
	JSON.parse(text).yield_self do |feedhash|
		feedhash.map(&:last).each do |feed|
			threads << Thread.new do
				feeds << RssFeed::Feed.new(feed).to_a_of_h
			end
		end
	end
end
threads.map(&:join)
puts feeds[0]