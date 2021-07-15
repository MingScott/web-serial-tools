#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

root = "https://www.royalroad.com"
searchTemplate = root+"/fictions/search?title="
searchTerms = ARGV.join(" ")

searchUrl = searchTemplate+searchTerms
doc = Nokogiri::HTML URI.open(searchUrl)
item = root+doc.css("div.fiction-list div.fiction-list-item").css("a").first["href"]
print item