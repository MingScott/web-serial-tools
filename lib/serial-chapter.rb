#! /usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'json'
require 'gemoji'

module SerialChapter #todo: Implement author method
	#Generic chapter reading class
	class Chapter
		def initialize(url, useragent="ruby", path = Dir.getwd + "/tmp")
			@doc = 		Nokogiri::HTML URI.open(url, {'User-Agent' => useragent})
			@url = 		url
			@path = path
			@doc =		Nokogiri::HTML self.demoji(@doc.to_s)
			img_import(@doc)
			
			custom_init
		end
		def custom_init
		end

		def demoji(str)
			moji = str.split("").map do |char|
				if char.match?(/\p{Emoji_Presentation}/) && ! Emoji.find_by_unicode(char).nil?
					char = ":#{Emoji.find_by_unicode(char).name}:"
				else
					char
				end
			end
			moji.join("")
		end

		def to_s
			puts @doc.to_s
		end

		def title ;		@doc.css("h1").first.content ; end
		def text ; 		@doc.to_s; end
		def url ;		@url; end
		def author ;	""; end

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
		def cf_decode(doc) #cloudflare email obfuscation decoding
			doc.search("span.__cf_email__").each do |x|
				enc = [x["data-cfemail"]].pack("H*").bytes.to_a
				data = enc[1..enc.length]
				x.content = data.map{ |byte| (byte ^ enc[0]).chr}.join
			end
		end

		def img_sub_link(doc)
			count = 1
			doc.search("img").each do |img|
				link = img["src"]
				title = "IMAGE"
				if img.to_h.has_key?("title")
					title = img["title"]
				end
				anchor = img.add_next_sibling("<a href=\"#{link}\">#{title}</a>")
				anchor.append_class(img.classes.join(" "))
				anchor.first["id"] = "SCRAPED_IMAGE_NUMBER_#{count}_#{self.title.hash}"
				count += 1
				img.remove
			end
		end

		def img_import(doc)
			count = 1
			doc.search("img").each do |img|
				link = img["src"]
				title = "SCRAPED_IMAGE_NUMBER_#{count}_#{self.title.hash}"
				filetype = link.split(/[.]/).last.split("/").first.split(/[?]|[&]/).first
				if filetype == "gif"
					next
				end
				stub = "#{@path}/#{title}"
				newpath = "#{stub}.#{filetype}"
				img["src"] = "#{title}.jpg"
#this logic just pries apart the different ways a source can be referred to,
# is incomplete and just based on examples I could find
				begin 
					if link.match? /^https[:][\/][\/].*$/
						File.open(newpath,"w") do |file|
							file.write URI.open(link).read
						end
					elsif link.match?(/^[\/]{1}[^\/].*/)
						uri = URI.parse(@url)
						newlink = "#{uri.scheme}://#{uri.host}#{link}"
						File.open(newpath,"w") do |file|
							file.write URI.open(newlink).read
						end
					elsif link.match? /^[\/][\/].*$/
						newlink = "https:#{link}"
						File.open(newpath, "w") do |f|
							f.write URI.open(newlink).read
						end
					else
						newlink = "#{@url.split("/").reverse.drop(1).reverse.join("/")}/#{link}"
						File.open(newpath, "w") do |f|
							f.write URI.open(newlink).read
						end
					end
					
					if filetype != "jpg" #there were some problems with libpng in calibre convert, so jpg it
						`magick "#{stub}.#{filetype}" "#{stub}.jpg"`
					end
					`magick "#{stub}.jpg" -quality 60 "#{stub}.jpg"` #reduce quality to save on filesize
				rescue
					next
				end
				count += 1
			end
		end
	end 

	#Custom chapter reading classes
	###############
	class RRChapter < Chapter #Royalroad
		def text
			doc = @doc.css("div.chapter div.portlet-body")
			doc.xpath("./*").each do |n| #remove everything except the authors notes and the chapter
				if n.to_h.has_key? "class"
					classes = n["class"].split(" ")
					if (classes & ["author-note-portlet", "chapter-content"]).empty? #detects author note and chapter content with element-wise AND
						n.remove
					end
					if n["class"].include? "author-note-portlet"
						n["style"] = "font-family: courier; color: gray;"
					end
				else
					n.remove if ([n.name] & ["p","div"]).empty?
				end
			end
			doc.css("portlet")
			cf_decode(doc)
			return doc.first.to_s
		end 
		def author
			@doc.css("meta[name*=creator]").first["content"]
		end
	end

	class PaleChapter < Chapter
		def text
			content = @doc.search("div.entry-content").first
			content.search("div.sharedaddy").remove
			content.search("a, p").each do |link|
				unless ([link.content] & ["Previous Chapter", "Next Chapter"]).empty?
					link.remove
				end
			end
			# unless ([content.search("p").first.content] & ["Avery","Verona","Lucy"]).empty?
			# 	content.search("#SCRAPED_IMAGE_NUMBER_1_#{self.title.hash}").remove
			# end
			return content.to_s
		end
		def title
			@doc.css("h1.entry-title").first.content
		end
		def nextch
			begin
				return @doc.search("span.nav-next a").first["href"]
			rescue
				return false
			end
		end
		def prevch
			begin
				return @doc.search("span.nav-previous a").first["href"]
			rescue
				return false
			end
		end
	end

	class QntmChapter < Chapter
		def text
			content = @doc.search("div.page__outer--content").first
			return content.to_s
		end
		def title
			@doc.search("h2.page__h2").first.content.gsub("\t","").gsub("\n","").gsub("[ ]$","").to_s
		end
		def nextch
			false
		end
		def prevch
			false
		end
	end


	class WardChapter < Chapter #Ward/other wildbow works
		def text
			t = @doc.css("div.entry-content").first.css("p")
			return t[0..t.length-1].to_s
		end
	end

	class PGTEChapter < Chapter #Practical Guide to Evil
		def title
			return @doc.css("h1.entry-title").first.content
		end
		def text
			@content = @doc.css("div.entry-content")
			@content.css("div.sharedaddy").remove
			return @content.to_s
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

	class AO3Chapter < Chapter
		def text
			return @doc.css("div.module").to_s
		end
		def title
			return @doc.css("h3.title").first.content.gsub(/.*[ ](?=C)/,"").gsub(/\n/,"")
		end
		def author
			return @doc.css("a[rel*=author]").last.content
		end
		def nextch;		self.linksearch "→"
		end
		def prevch;		self.linksearch "←" 
		end
	end

	class ZombieKnightPage < Chapter
		def text
			return @doc.css("div.entry-content").to_s.gsub("font-family: courier", "font-family: sans-serif")
		end
		def title
			return @doc.css("h3.entry-title").first.content
		end
		def author
			return @doc.css("a[title=\"author profile\"] span").first.content
		end
		def nextch
			begin
				return @doc.css("a.blog-pager-newer-link").first["href"]
			rescue
				return false
			end
		end
		def prevch
			begin
				return @doc.css("a.blog-pager-older-link").first["href"]
			rescue
				return false
			end
		end
	end

	class SVChapter < Chapter
		def custom_init
			postid = @url.split("/").last
			@doc = @doc.search("article.message.hasThreadmark[data-content=#{postid}]")
		end


		def title
			@doc.search("span.threadmarkLabel").first.content
		end

		def author
			return @doc.first["data-author"]
		end

		def threadmark_nav(css_selector)
			find = ""
			begin
				find = @doc.css(css_selector).first["href"]
			rescue
				return false
			end
			unless find[0..3] == "http"
				domain_index = @url.index("/",8)
				find = @url[0..domain_index-1] + find
			end
                        out = find.split("/")
                        out[out.length-1] = out[out.length-1].gsub(/page-.*#/,"").gsub(/[#]/,"")
                        out = out.join("/")
                        return out
		end

		def nextch
			out = threadmark_nav("a.threadmark-control--next")
                        puts out
                        return out
		end
		def prevch
			threadmark_nav("a.threadmark-control--previous")
		end

		def text
			return @doc.search("article.message-body div.bbWrapper").to_s
		end
	end


	#Class chooser
	def classFinder(url)
		patterns = {
			"royalroad" 			=>	RRChapter,
			"parahumans" 			=>	WardChapter,
			"practicalguidetoevil"	=>	PGTEChapter,
			"archiveofourown"		=>	AO3Chapter,
			"thezombieknight"		=>	ZombieKnightPage,
			"palewebserial"			=>	PaleChapter,
			"sufficientvelocity"	=>	SVChapter,
			"qntm"					=>	QntmChapter

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
