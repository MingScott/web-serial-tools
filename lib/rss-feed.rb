#! /usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'json'

module RssFeed
	class Feed
		def initialize(url)
			URI.open(url, 'User-Agent' => 'ruby') do |f|
				@doc = Nokogiri::XML(f).css("channel").first
			end
		end

		def name
			@doc.css("title").first.content
		end

		def item
			@doc.css("item")
		end

		def titles
			titles = Array.new
			self.item.css("title").each { |title| titles << title.content }
			titles
		end

		def urls
			links = Array.new
			self.item.css("link").each { |link| links << link.content }
			links
		end

		def dates
			dates = Array.new
			self.item.css("pubDate").each { |date| dates << date.content }
			dates
		end

		def creators
			creators = Array.new
                        if self.to_s.include?("dc:creator") then @c = true end
			self.item.each do |i|
                          creators << if @c then i.css("dc|creator").first.content else "" end
			end
			creators
		end

		def to_a #This thing produces a rotated array where each entry in the feed is a spot on the array
			namearr = Array.new
			for ii in 0..self.titles.length-1
				namearr[ii] = self.name
			end
			arr = [self.titles, self.urls, self.dates, namearr, self.creators ]
			newarr = Array.new(self.titles.length) { Array.new(arr.length,0) }
			for x in 0..newarr.length-1
				for y in 0..arr.length-1
					newarr[x][y] = arr[y][x]
				end
			end
			newarr
		end

		def to_a_of_h
			@array = self.to_a
			@aofh = []
			@array.each do |a|
				@aofh << {
					"title"		=> a[0],
					"url"		=> a[1],
					"date"		=> a[2],
					"name"		=> a[3],
					"creators" 	=> a[4]
				}
			end
			return @aofh
		end

		def store(path)
			File.open(path,"w") do |f|
				f.write JSON.pretty_generate(self.to_a)
				f.close
			end
		end

		def to_s
			@doc.to_s
		end

		def to_nokogiri
			@doc
		end
	end
end
