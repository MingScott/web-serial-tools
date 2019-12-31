#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
include RssFeed
require "json"
require "mail"
require "optparse"
require "fileutils"

@conf_path		= "conf/rss/"
@data_path		= "data/"
@tmp_dir		= "tmp/"
[@conf_path, @data_path, @tmp_dir].each {|d| unless Dir.exist?(d) then FileUtils.mkdir_p d end }

@feed_list		= "#{@conf_path}feeds.json"
@mail_json	= if File.exist?("#{@conf_path}mail.json")
		"#{@conf_path}mail.json"
	else
		warn "WARNING: You probably need to configure conf/rss/mail.json"
                "#{@conf_path}example_mail.json"
	end
@feed_data 		= "#{@data_path}feed_data.json"
@mobi			= false
@verbose		= false
@remove			= false
@single                 = false
@quiet                  = false
@dryrun                 = false

OptionParser.new do |o|
	o.on("-m") { @mobi = true }
	o.on("-v") { @verbose = true }
	o.on("-x") { @remove = true }
        o.on("-s") { @single = true }
        o.on("-q") { @quiet = true }
        o.on("-d") { @dryrun = true }
end.parse!

if @quiet then $stdout = StringIO.new end

@interval		= if ARGV.empty? then 30 else ARGV[0].to_i end
@feed_url_hash 	= JSON.parse File.read @feed_list
@mail_conf 		= JSON.parse File.read @mail_json

if @dryrun then @mail_conf["recipient"] = "devnull@nothing.com" end

def download_feeds(furlhash) #Hash of name=>feed url become hash of name=>feed
	@feedhash = {}
	begin
		if @verbose then puts "Downloading feeds..." end
		furlhash.keys.each do |key|
			@feedhash[key] = Feed.new(furlhash[key]).to_a_of_h
		end
	rescue
                warn "Unable to download feeds"
		retry
	end
	return @feedhash 
end

def resume_feeds
	puts "Loading feeds from file..."
	JSON.parse File.read @feed_data
end

def save_feeds(fhash)
	if @verbose then puts "Saving..." end
	File.open( @feed_data, "w") do |f|
		f.write JSON.pretty_generate(fhash)
		f.close
	end
end

def send_file(fname, conf) 
	puts "Sending chapters..."
	gmx_options = { :address 		=> "mail.gmx.com",
            :port                 	=> 587,
            :user_name            	=> conf["username"],
            :password             	=> conf["password"],
            :authentication       	=> 'plain',
            :enable_starttls_auto 	=> true  }
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
	chaps.each do |chaph| #loop through chapters and add them to the generated document
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
                @authorstring = if chaph["creators"].empty? then "" else " by #{chaph["creators"]}" end
		@title << "[#{chaph["name"]}: #{chaph["title"]}#{@authorstring}]"
	end
	@charset = if @mobi then "UTF-8" else "ISO-8859-1" end
	#Bracket text with the html gravy
	@top = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"				\
			"<meta charset=\"#{@charset}\">\n"							\
			"<title>#{@title}</title>\n"								\
			"<link rel=\"stylesheet\" href=\"style.css\">\n"			\
			"</head>\n<body>\n<!-- page content -->\n"
	@output = "#{@top}#{@output}"
	@output << "</body>\n</html>"
	if not @mobi #encode text to play nice with kindle's html
		[@output,@title].each do |text|
			text.gsub!(	/\u2026/,			"..."	)
			text.gsub!(	/[\u2018\u2019]/,	"\'"	)
		        text.encode!( Encoding::ISO_8859_1,invalid: :replace, undef: :replace )
		end
	end
	return {
		"text"	=> @output,
		"title"		=> @title
	}
end

def main
	@old_flist = if File.exist?( @feed_data ) then resume_feeds else download_feeds @feed_url_hash end
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
			unless @verbose then print "\n" end
			puts "New chapters detected!"
			@doc = populate_document @newchaps
			@docf = {
				body: 	@tmp_dir + @doc["title"],
				ext: 	".html"
			}
			File.open "#{@docf[:body]}#{@docf[:ext]}", 'w' do |f|
				f.puts @doc["text"]
			end
			if @mobi
				`ebook-convert #{@docf}.html #{@docf}.mobi --title '#{@title}' --max-toc-link 600`
				@docf[:ext] = ".mobi"
			end
			send_file("#{@docf[:body]}#{@docf[:ext]}",@mail_conf)
		end
                if @single then puts "Done!"; break end
		if @verbose then puts "Sleeping at " + Time.now.inspect else print "*" end
		sleep @interval
	end
end

main
