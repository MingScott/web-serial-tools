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
path = ""
OptionParser.new do |o|
	o.banner = ""
	o.on("-n", "--name NAME", "Provide book name") do |serial|
		@book_title << serial
	end
	o.on("-s", "--start LINK" , "Provide 1st chapter link") do |link|
		start << link
	end
	o.on("-a", "--author NAME", "Provide name of author") do |a|
		author << a
	end
	o.on("-t", "--to EMAIL", "email address to send to") do |k|
		kindle << k
	end
	o.on("-f", "--from EMAIL", "email address to send from") do |f|
		email << f
	end
	o.on("-p", "--password PASSWORD", "Password for the email address to send from") do |p|
		password << p
	end
	o.on("-d","--directory PATH", "Directory to write files to") do |d|
		path << d
		path = path + '/' unless path[-1] == '/' || path.empty?
	end
end.parse!

def classFinder(url)
	patterns = {
		"royalroad" => 				RRChapter,
		"wordpress" => 				WPChapter,
		"parahumans" => 			WardChapter,
		"practicalguidetoevil" => 	PGTEChapter,
		"wanderinginn" =>			WanderingInn
	}
	@chapclass = ""
	patterns.keys.each do |k|
		@chapclass = if url.include? k
			patterns[k]
		else
			@chapclass
		end
	end
	if @chapclass == ""
		@chapclass = Chapter
	end
	return @chapclass
end

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
		File.open fname, 'w' do |f| ; f.puts self.full_text;
		end
		@fname = fname
	end

	def convert_to_mobi
		@mobi = if @fname.include? "."
			@fname.gsub @fname.split(".").last, "mobi"
		else
			@fname + ".mobi"
		end
		system "ebook-convert #{@fname} #{@mobi} --title #{@title} --authors \"#{@author}\" --max-toc-link 600"
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

url = start
ch1 = classFinder(url)
ch1 = ch1.new url
book = Book.new ch1, @book_title, author
book.write_to_file path + @book_title + ".html"
book.convert_to_mobi
publish book, email, password, kindle unless kindle.empty?