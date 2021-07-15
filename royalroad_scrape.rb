#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'optparse'
require 'mail'

require_relative 'lib/serial-chapter.rb'
include SerialChapter

#Option parser
@book_title = ""
start = ""
author = ""
kindle = ""
email = ""
password = ""
path = "tmp/"
cover = ""
OptionParser.new do |o|
	o.banner = ""
	o.on("-t", "--to EMAIL", "email address to send to") do |k|
		kindle = k
	end
	o.on("-f", "--from EMAIL", "email address to send from") do |f|
		email = f
	end
	o.on("-p", "--password PASSWORD", "Password for the email address to send from") do |p|
		password = p
	end
	o.on("-d","--directory PATH", "Directory to write files to") do |d|
		path = d
		path = path + '/' unless path[-1] == '/' || path.empty?
	end
	o.on("-n", "--name NAME", "Name of the work") do |n|
		root = "https://www.royalroad.com"
		searchTemplate = root+"/fictions/search?title="
		searchTerms = n

		searchUrl = searchTemplate+searchTerms
		doc = Nokogiri::HTML URI.open(searchUrl)
		item = root+doc.css("div.fiction-list div.fiction-list-item").css("a").first["href"]
		cover = Nokogiri::HTML URI.open(item)
	end
end.parse!

class Book
	def initialize(chap, title="Beginning", author="Unknown")
		@next_url = chap.nextch
		@title = title
		@author = author
		@chap = chap
		@body = ""
		@toc = "<h1>Table of Contents</h1>"
		@ind = 1
		until @next_url == false
			$stdout.puts @chap.title
			@next_url = @chap.nextch
			@body << "<h1 id=\"chapter#{@ind.to_s}\" class=\"chapter\">#{@chap.title}</h1>\n"
			@body << @chap.text + "\n"
			@toc  << "<a href=\"#chapter#{@ind}\">#{@chap.title}</a><br>\n"
			@ind  += 1
			if @next_url
				@chap = @chap.class.new @next_url
			end
		end
	end

	def full_text
		title = "<h1>#{@title}</h1 class=\"chap-title\">\n<i>#{Time.now.inspect}</i><br>\n"
		return title + @toc + @body
	end

        def write_to_file(fname="#{@title}.html")
                puts fname
		File.open fname, 'w' do |f| ; f.puts self.full_text;
		end
		@fname = fname
	end

	def convert_to_mobi
		puts @fname
		@mobi = if @fname.include? "."
			@fname.gsub @fname.split(".").last, "mobi"
		else
			@fname + ".mobi"
		end
		puts @mobi
		system "ebook-convert #{@fname} #{@mobi} --title \"#{@title}\" --authors \"#{@author}\" --max-toc-link 600"
	end

	def html; @fname;
	end

	def mobi; @mobi;
	end
end

def publish(book, email, password, kindle)
	gmx_options = { :address              => "mail.gmx.com",
                :port                 => 587,
                :user_name            => email,
                :password             => password,
                :authentication       => 'plain',
                :enable_starttls_auto => true  }
	Mail.defaults do
		delivery_method :smtp, gmx_options
	end

	Mail.deliver do
	  to kindle
	  from email
	  subject ' '
	  add_file book.mobi
	end
end
if cover == ""
	cover = Nokogiri::HTML URI.open(ARGV[0])
end
url = "https://www.royalroad.com" + cover.css("a.btn-primary.btn-lg").attribute("href")
title = cover.css("h1[property=name]").inner_text
author = cover.css("h4[property=author] a").inner_text

ch1 = classFinder(url)
ch1 = ch1.new url
book = Book.new ch1, title, author
filename = title.gsub(/[^a-zA-Z0-9]/,"_")
book.write_to_file path + filename + ".html"
book.convert_to_mobi
publish book, email, password, kindle unless kindle.empty?
