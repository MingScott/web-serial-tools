#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
include RssFeed
require "json"
require "mail"

@conf_path		= "conf/rss/"
@feed_list		= "feeds.json"
@mail_conf_path	= "rss_mail.json"
@feed_data 		= "new_feed_data.json"
@tmp_dir		= "/tmp/"
@interval		= if ARGV.empty? then 30 else ARGV[0].to_i end
@feed_url_hash 	= JSON.parse File.read @conf_path + @feed_list
@mail_conf 		= JSON.parse File.read @conf_path + @mail_conf_path

def download_feeds(furlhash) #Hash of name=>feed url become hash of name=>feed
	@feedhash = {}
	begin
		puts "Downloading feeds..."
		furlhash.keys.each do |key|
			@feedhash[key] = Feed.new(furlhash[key]).to_a
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
	puts "Saving..."
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

def main
	@old_flist = if File.exist?( @conf_path + @feed_data ) then resume_feeds else download_feeds @feed_url_hash end
	while true
		@newchaps = []
		@new_flist = download_feeds @feed_url_hash
		@new_flist.keys.each do |feed|
			puts "Checking #{feed}..."
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
			@title = ""
			@output = ""
			@newchaps.each do |chap_array|
				@url = chap_array[1]
				@chap_class = classFinder @url
				begin
					chap = @chap_class.new @url
				rescue
					retry
				end
				@output << "<h1 class=\"chapter\">" + chap_array[3] + ": " + chap_array[0] + "</h1>\n"
				@output << "<i>" + chap_array[2] + "</i>\n"
				@output << chap.text + "\n"
				@title << "[#{chap_array[3]}: #{chap_array[0]}]"
			end
			temphtml = @tmp_dir + "temp-ebook.html"
			tempmobi = @tmp_dir + "temp-ebook.mobi"
			File.open temphtml, 'w' do |f|
				f.puts @output
			end
			`ebook-convert #{temphtml} #{tempmobi} --title '#{@title}' --max-toc-link 600`
			send_file(tempmobi,@mail_conf)
		end
		puts "Sleeping at " + Time.now.inspect
		sleep @interval
	end
end

main