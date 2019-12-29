#! /usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'json'

module SerialChapter
	#Generic chapter reading class
	class Chapter
		def initialize(url)
			@doc = 		Nokogiri::HTML open url
			@url = 		url
		end
		def to_s
			puts @doc.to_s
		end

		def title ;		@doc.css("h1").first.content ; end
		def text ; 		@doc.css("p").to_s; end
		def url ;		@url; end

		def linksearch(pattern)
			find = false
			links = @doc.css "a"
			links.each do |l|
				if l.content.upcase.include?(pattern)
					find = l["href"]
				end
			end
			if find
				unless find[0..3] == "http"
					domain_index = @url.index("/",8)
					find = @url[0..domain_index-1] + find
				end
			end
			return find
		end

		def nextch;		self.linksearch "NEXT"
		end
		def prevch;		self.linksearch "PREV" 
		end
	end 

	#Custom chapter reading classes
	###############
	class RRChapter < Chapter #Royalroad
		def text
			foreword = @doc.css "div.author-note"
			doc = @doc.css("div.chapter-inner.chapter-content").first.children
			return "<div align=\"right\"><i>#{foreword.to_s}</i></div>\n#{doc.to_s}\n"
		end 
	end

	class WPChapter < Chapter #Wordpress
		def text
			text = @doc.css("div.entry-content").first
			links = text.css("a")
			divs = text.css("div")

			to_remove = []
			links.each do |l|
				to_remove << l.to_s if l.content.upcase.include? "NEXT" or l.content.upcase.include? "PREV"
			end
			divs.each do |d|
				to_remove << d.to_s if d["class"].include? "shar" or d["class"].include? "wpa" if d.keys.join(" ").include? "class"
			end
			stext = text.to_s
			to_remove.each do |r|
				stext = stext.gsub r, ""
			end
			return stext
		end
                def nextch
                  return self.linksearch("NEXT CHAPTER")
                end
		def title
			@doc.css("h1.entry-title").first.content
		end
	end

	class WardChapter < Chapter #Ward/other wildbow works
		def text
			t = @doc.css("div.entry-content").first.css("p")
			return t[1..t.length-2].to_s
		end
	end

	class PGTEChapter < Chapter #Practical Guide to Evil
		def title
			return @doc.css("h1.entry-title").first.content
		end
		def text
			return @doc.css("div.entry-content p").to_s
		end
		def linksearch(pattern)
			find = false
			links = @doc.css "div.nav-links a" 
			links.each do |l|
				if l.content.upcase.include?(pattern)
					find = l["href"]
				end
			end
			if find
				unless find[0..3] == "http"
					domain_index = @url.index("/",8)
					find = @url[0..domain_index-1] + find
				end
			end
			return find
		end
	end

	class WanderingInn < WPChapter #The Wandering Inn
		def initialize(url)
			url = url.gsub ".wordpress", ""
			@doc = 		Nokogiri::HTML open url
			@url = 		url
		end
		def nextch
			nc = self.linksearch "NEXT"
			nc.gsub ".wordpress", "" if nc
			nc
		end
	end

	class A03Chapter < Chapter
		def text
			return @doc.css("div.module").to_s
		end
		def title
			return @doc.css("h3.title").first.content.gsub(/.*[ ](?=C)/,"").gsub(/\n/,"")
		end
		def nextch;		self.linksearch "→"
		end
		def prevch;		self.linksearch "←" 
		end
	end

	#Class chooser
	def classFinder(url)
		patterns = {
			"royalroad" 			=>	RRChapter,
			"wordpress" 			=>	WPChapter,
			"parahumans" 			=>	WardChapter,
			"practicalguidetoevil"	=>	PGTEChapter,
			"wanderinginn" 			=>	WanderingInn,
			"archiveofourown"		=>	A03Chapter,
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
end

module RssFeed
	class Feed
		def initialize(url)
			@doc = Nokogiri::XML(open(url)).css("channel").first
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

		def to_a #This thing produces a rotated array where each entry in the feed is a spot on the array
			namearr = Array.new
			for ii in 0..self.titles.length-1
				namearr[ii] = self.name
			end
			arr = [self.titles, self.urls, self.dates, namearr]
			newarr = Array.new(self.titles.length) { Array.new(arr.length,0) }
			for x in 0..newarr.length-1
				for y in 0..arr.length-1
					newarr[x][y] = arr[y][x]
				end
			end
			newarr
		end

		def store(path)
			File.open(path,"w") do |f|
				f.write JSON.pretty_generate(self.to_a)
				f.close
			end
		end
	end
end