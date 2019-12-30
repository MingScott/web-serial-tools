#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
include RssFeed
require "json"
require "mail"
require "optparse"

@conf_path		= "conf/rss/"
@feed_list		= "feeds.json"
@mail_conf_path	= "rss_mail.json"
@feed_data 		= "feed_data.json"
@tmp_dir		= "data/"
@mobi			= false
@verbose		= false

OptionParser.new do |o|
	o.on("-m") do
		@mobi = true
	end
	o.on("-v") do
		@verbose = true
	end
end.parse!

@interval		= if ARGV.empty? then 30 else ARGV[0].to_i end
@feed_url_hash 	= JSON.parse File.read @conf_path + @feed_list
@mail_conf 		= JSON.parse File.read @conf_path + @mail_conf_path


def download_feeds(furlhash) #Hash of name=>feed url become hash of name=>feed
	@feedhash = {}
	begin
		if @verbose then puts "Downloading feeds..." end
		furlhash.keys.each do |key|
			@feedhash[key] = Feed.new(furlhash[key]).to_a_of_h
		end
	rescue
		retry
	end
	return @feedhash 
end

def resume_feeds
	puts "Loading feeds from file..."
	JSON.parse File.read @conf_path + @feed_data
end

def save_feeds(fhash)
	if @verbose then puts "Saving..." end
	File.open( @conf_path + @feed_data, "w") do |f|
		f.write JSON.pretty_generate(fhash)
		f.close
	end
end

def send_file(fname, conf)
	puts "Sending chapters..."
	gmx_options = { :address              => "mail.gmx.com",
            :port                 => 587,
            :user_name            => conf["username"],
            :password             => conf["password"],
            :authentication       => 'plain',
            :enable_starttls_auto => true  }
	Mail.defaults do
		delivery_method :smtp, gmx_options
	end
	begin
		Mail.deliver do
		  to conf["recipient"]
		  from conf["username"]
		  subject ' '
		  add_file fname
		end
	rescue
		puts "Failed to send mail. Retrying..."
		sleep 2
		retry
	end
end

def populate_document(chaps)
	#
	@title = ""
	@output = ""
	chaps.each do |chaph|
		puts "[#{chaph["name"]}: #{chaph["title"]}]\n\t#{chaph["date"]}"
		@chap_class = classFinder chaph["url"]
		begin
			chap = @chap_class.new chaph["url"]
		rescue
			retry
		end
		@output << "<h1 class=\"chapter\">" + chaph["name"] + ": " + chaph["title"] + "</h1>\n"
		@output << "<i>" + chaph["date"] + "</i>\n"
		@output << chap.text + "\n"
		@title << "[#{chaph["name"]}: #{chaph["title"]}]"
	end
	@output << "</body>\n</html>"
	@charset = if @mobi then "UTF-8" else "ISO-8859-1" end
	@top = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"#{@charset}\">\n<title>#{@title}</title>\n<link rel=\"stylesheet\" href=\"style.css\">\n</head>\n<body>\n<!-- page content -->"
	@output = "#{@top}#{@output}"
	if not @mobi #encode text to play nice with kindle's html
		[@output,@title].each do |text|
			text.gsub!("\u2026","...")
				.gsub!(/[\u2018\u2019]/,"\'")
			    .encode!(
			    	Encoding::ISO_8859_1,
			    	invalid: :replace, undef: :replace
			    	)
		end
	end
	return {
		"text"	=> @output,
		"title"		=> @title
	}
end

def main
	@old_flist = if File.exist?( @conf_path + @feed_data ) then resume_feeds else download_feeds @feed_url_hash end
	while true
		@newchaps = []
		@new_flist = download_feeds @feed_url_hash
		@new_flist.keys.each do |feed|
			if @verbose then puts "Checking #{feed}..." end
			if @old_flist.include? feed
				@delta = @new_flist[feed] - @old_flist[feed]
				if not @delta.empty?
					@delta.each {|i| @newchaps << i}
				end
			end
		end
		save_feeds @new_flist
		@old_flist = @new_flist
		if not @newchaps.empty?
			puts "New chapters detected!"
			@doc = populate_document @newchaps
			@tempfile = @tmp_dir + @doc["title"]
			@ext = ".html"
			File.open @tempfile+@ext, 'w' do |f|
				f.puts @doc["text"]
			end
			if @mobi
				`ebook-convert #{@tempfile}.html #{@tempfile}.mobi --title '#{@title}' --max-toc-link 600`
				@ext = ".mobi"
			end
			send_file(@tempfile+@ext,@mail_conf)
		end
		if @verbose then puts "Sleeping at " + Time.now.inspect end
		sleep @interval
	end
end

main