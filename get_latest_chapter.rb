require 'nokogiri'
require 'open-uri'
require 'fileutils'
include FileUtils
require_relative 'lib/serial-chapter.rb'
include SerialChapter
include RssFeed

@title = ""
@output = ""
@toc = ""

ARGV.each do |rss|
	feed = Feed.new rss
	latest_chap = feed.urls[0]
	chap_class = classFinder latest_chap
	chap = chap_class.new latest_chap
	@output << "<h1 class=\"chapter\">" + feed.name + ": " + chap.title + "</h1>\n"
	@output << "<i>" + Time.now.inspect + "</i>\n"
	@output << chap.text + "\n"
	@title << "[#{feed.name}: #{chap.title}]"
end
temphtml = '/tmp/tmp-ebook.html'
tempmobi = '/tmp/tmp-ebook.mobi'

File.open temphtml, 'w' do |f|
	f.puts @output
end
devnull = `ebook-convert #{temphtml} #{tempmobi} --title '#{@title}' --max-toc-link 600`
mobifile = File.open tempmobi, 'rb'
@output_mobi = mobifile.read
mobifile.close
rm temphtml
rm tempmobi
puts @output_mobi