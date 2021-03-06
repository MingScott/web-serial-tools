#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
require_relative "lib/rss-feed"
include RssFeed
require_relative "lib/kindle"
include Kindle
require "json"
require "mail"
require "optparse"
require "fileutils"
require "pdfkit"

@conf_path		= "conf/"
@data_path		= "data/"
@tmp_dir		= "tmp/"
# Setup directories
[@conf_path, @data_path, @tmp_dir].each {|d| unless Dir.exist?(d) then FileUtils.mkdir_p d end }

@feed_list		= "#{@conf_path}feeds.json"
@mail_json	= if File.exist?("#{@conf_path}mail.json")
		"#{@conf_path}mail.json"
	else
		warn "WARNING: You probably need to configure conf/rss/mail.json"
        "#{@conf_path}example_mail.json"
	end
@feed_data 		= "#{@data_path}feed_data.json"
@save_data		= @feed_data

@filetype		= "html"
@verbose		= false
@remove			= false
@single       	= false
@quiet			= false
@dryrun			= false
@log 			= false

OptionParser.new do |o|
	o.on("-f", "--format FORMAT", "Specify html, pdf, or mobi (default html)") do |opt|
		@filetype = case opt.downcase
		when "html"
			"html"
		when "mobi"
			"mobi"
		when "pdf"
			warn "NOT FUNCTIONAL YET"
			"pdf"
		else
			warn("Invalid filetype specifier!")
		end
	end
	o.on("-v", "verbose") { @verbose = true } # tells you everything it's doing
	o.on("-x", "clean up when done") { @remove = true } # removes file from data dir when done with it
    o.on("-s", "single") { @single = true } # checks rss feeds once, then exits
    o.on("-q", "quiet") { @quiet = true } # suppresses all commandline output. Will still send mail
    o.on("-d", "dryrun email") { @dryrun = true } # throws emailed file into a black hole
    o.on("-l", "log to file") { @log = true }
end.parse!

if @quiet then $stdout = StringIO.new end
if @log
	$stderr = File.open(@data_path+"rsserr.log","a")
	$stdout = File.open(@data_path+"rssout.log","a")
end

@interval		= if ARGV.empty? then 30 else ARGV[0].to_i end
@feed_url_hash 	= JSON.parse File.read @feed_list
#puts @feed_url_hash
@feed_url_hash	= Hash[@feed_url_hash.to_a.sample(@feed_url_hash.length)]
puts @feed_url_hash
@mail_conf 		= JSON.parse File.read @mail_json
#puts @mail_conf

if @dryrun
	warn "WARNING: Dryrun. Nothing will be updated or sent. Data will be loaded from dryrun_load_data.json if possible."
	@mail_conf["recipient"] = "devnull@nothing.com"
	@dryrun_load 			= "#{@data_path}dryrun_load_data.json"
	@feed_data				= if File.exist?(@dryrun_load) then @dryrun_load else @feed_data end
	@save_data				= "#{@data_path}dryrun_save_data.json"
end

def download_feeds(furlhash) #Hash of name=>feed url become hash of name=>feed
	@feedhash = {}
	if File.exist? @feed_data
		@oldfeedhash = JSON.parse File.read @feed_data
	end
	begin
		if @verbose
			puts "Downloading feeds... \t[#{Time.now.inspect}]"
		end

		threads = []
		furlhash.keys.each do |key|
			threads << Thread.new do
				if @verbose then puts "Checking " + key end
				begin
					@feedhash[key] = RssFeed::Feed.new(furlhash[key]).to_a_of_h
				rescue OpenURI::HTTPError => feed_error
					warn("Error - Accessing Cached Data - #{key} \t[#{Time.now.inspect}]")
					if @oldfeedhash.has_key?(key)
						@feedhash[key] = @oldfeedhash[key]
					else
						warn "HTTP error and no cached feed to fallback to"
					end
				end
			end
		end
		threads.map(&:join)
	rescue => outer_feed_error
		warn outer_feed_error
        warn "Unable to download feeds \t[#{Time.now.inspect}]"
        sleep 10
        unless @single
        	retry
        end
	end
	return @feedhash 
end

def resume_feeds
	puts "Loading feeds from file... \t[#{Time.now.inspect}]"
	JSON.parse File.read @feed_data
end

def save_feeds(fhash)
	if @verbose then puts "Saving... \t[#{Time.now.inspect}]" end
	File.open( @save_data, "w") do |f|
		f.write JSON.pretty_generate(fhash)
		f.close
	end
end

def populate_document(chaps)
	#
	@title = "RSS"
	@toc = "<nav epub:type=\"toc\" id=\"toc\">\n<h1>Table of Contents</h1>\n<ol>\n"
	@output = ""
	@eachwork = []
	@authors = []
	chaps.reverse.each do |chaph| #loop through chapters and add them to the generated document
		@localtitle = chaph["title"].gsub("#{chaph["name"]} - ", "")
		puts "[#{chaph["name"]}: #{@localtitle}] #{chaph["date"]}"
		@chap_class = SerialChapter::classFinder chaph["url"]
		begin
			chap = @chap_class.new chaph["url"]
		rescue
			retry
		end

		@author = case {
			chap: !chap.author.empty?,
			feed: !chaph["creators"].empty?
		}
		when {chap: false, feed: false}
			""
		when {chap: true, feed: false}, {chap: true, feed: true}
			"#{chap.author}"
		when {chap: false, feed: true}
			"#{chaph["creators"]}"
		end
		@authorstring = if !@author.empty? then " by #{@author}" else "" end

		@chaptitle = chaph["name"] + ": " + @localtitle
		@chapid = @chaptitle.downcase.gsub(/[^A-Za-z0-9]/,"")
		@toc << "\t<li><a href=\"##{@chapid}\">#{@chaptitle}</a></li><br>\n"
		@output << "<a href=\"#{chaph["url"]}\"><h1 class=\"chapter\" id=\"#{@chapid}\">#{@chaptitle}</h1></a>\n"
		@output << "<i>" + chaph["date"] + "</i><br>\n"
		@output << "<i>#{@authorstring}</i><br>" unless @authorstring.empty?
		@output << chap.text + "\n"
		
		@cname_file = ""
		if @eachwork.include?(chaph["name"])
			if chaph["name"].split(" ").length > 1
				@cname_file = chaph["name"].split(" ").map{|w|w[0]}.join("").upcase
			else
				@cname_file = chaph["name"][0..2]
			end
		else
			@eachwork << chaph["name"]
			@cname_file = chaph["name"]
		end
		if @authors.last == @author then @authorstring = "" end
		@title << "[#{@cname_file}: #{@localtitle}#{@authorstring}]"
		@authors << @author unless @authorstring.empty?
	end
	@fullchapter = ""
	@charset = "UTF-8"
	#Bracket text with the html gravy
	@toc << "</ol></nav><nav epub:type=\"landmarks\" class=\"hidden-tag\" hidden=\"hidden\"><ol><li><a epub:type=\"toc\" href=\"#toc\">Table of Contents</a></li></ol></nav>"
	@fullchapter << "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"			\
			"<meta charset=\"#{@charset}\">\n"								\
			"<meta name=\"author\" content=\"#{@authors.join(", ")}\">\n"	\
			"<title>#{@title}</title>\n"									\
			"<link rel=\"stylesheet\" href=\"style.css\">\n"				\
			"</head>\n<body>\n<!-- page content -->\n"
	@fullchapter << @toc if chaps.length > 1
	@fullchapter << @output
	@fullchapter << "</body>\n</html>"
	@fullchapter = "\uFEFF#{@fullchapter}".encode("UTF-8")
	return {
		"text"	=> @fullchapter,
		"title"	=> @title,
		"authors" => @authors.join(", ")
	}
end

def main
	@old_flist = if File.exist?( @feed_data ) then resume_feeds else download_feeds @feed_url_hash end
	while true
		@newchaps = []
                # puts "INITIAL NEWCHAPS DEBUG"
                # puts JSON.pretty_generate @newchaps
                # puts "INITIAL OLD FLIST DEBUG"
                # puts JSON.pretty_generate @old_flist["Chrysalis"][0..1]

		@new_flist = download_feeds @feed_url_hash

                # puts "INITIAL NEW FLOST DEBUG"
                # puts JSON.pretty_generate @new_flist["Chrysalis"][0..1]

                # puts "CONPARISON TEST"
                # @new_flist.keys.each { |f| puts JSON.pretty_generate(@new_flist[f] - @old_flist[f]) }

        threads = []
		@new_flist.keys.each do |feed|
			threads << Thread.new do
				if @verbose then puts "Checking #{feed}...  \t[#{Time.now.inspect}]" end
				if @old_flist.include? feed
					@delta = @new_flist[feed] - @old_flist[feed]
					if not @delta.empty?
						@delta.each {|i| @newchaps << i}
						if @verbose
							puts "New chapter in #{feed}...  \t[#{Time.now.inspect}]"
						end
					end
				end
			end
		end
		threads.map(&:join)
                
		save_feeds @new_flist
		@old_flist = @new_flist
                # puts "DEBUG NEWCHAPS"
                # puts JSON.pretty_generate @newchaps
                # puts "NEWCHAPS EMPTY: #{@newchaps.empty?}"
		if not @newchaps.empty?
			unless @verbose then print "\n" end
			puts "New chapters detected!"
			@doc = populate_document @newchaps
			@fname = if @doc["title"].bytesize > 245
				@doc["title"][0..245]
			else
				@doc["title"]
			end
			puts @doc["title"]
			@docf = {
				body: 	@tmp_dir + @fname,
				ext: 	".html",
				subj:	""
			}
			puts @docf[:body]
			File.open "#{@docf[:body]}#{@docf[:ext]}", 'w' do |f|
				f.puts @doc["text"]
			end
			if @filetype == "mobi"
				system "ebook-convert \"#{@docf[:body]}.html\" \"#{@docf[:body]}.mobi\" --title \"#{@doc["title"]}\" --authors \"#{@doc["authors"]}\" --max-toc-link 600"
				@docf[:ext] = ".mobi"
			elsif @filetype == "pdf"
				pdfObj = PDFkit.new File.new "#{@docf[:body]}.html"
				pdfObj.to_file "#{@docf[:body]}.pdf"
				@docf[:ext] = ".pdf"
				@docf[:subj] = "Convert"
			end

			#puts JSON.pretty_generate @docf
			Kindle::send_file("#{@docf[:body]}#{@docf[:ext]}",@mail_conf,@docf[:subj])
			gmx_options = { :address 		=> "mail.gmx.com",
	            :port                 	=> 587,
	            :user_name            	=> @mail_conf["username"],
	            :password             	=> @mail_conf["password"],
	            :authentication       	=> 'plain',
	            :enable_starttls_auto 	=> true  }
			Mail.defaults do
				delivery_method :smtp, gmx_options
			end
			begin
				text = @mail_conf["text"]
				uname = @mail_conf["username"]
				title = @doc["title"]

				Mail.deliver do
					to text
					from uname
					body "#{title}"
				end
			end
		end
        if @single then puts "Done!"; break end
		if @verbose then puts "Sleeping for #{@interval} seconds... \t[#{Time.now.inspect}]" else print "*" end
		sleep @interval
	end
end

main
