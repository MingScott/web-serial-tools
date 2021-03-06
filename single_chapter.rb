#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
require "fileutils"
require 'emoji'

@url = ARGV[0]
# @url = "https://palewebserial.wordpress.com/2021/01/02/gone-ahead-7-9/"
@chap_class = SerialChapter::classFinder @url
begin
	@chap = @chap_class.new @url
rescue => error
	puts error
end

puts @chap.title

File.open("tmp/#{@chap.title}.html","w") do |f|
	output = <<-EOF
<!DOCTYPE html>
<html>
<head>
	<title>
EOF
	output << @chap.title
	output << <<-EOF
</title>
</head>
<body>

EOF
	output << "<a href=\"#{@chap.url}\">"
	output << "<h1>#{@chap.title}</h1></a>"
	output << @chap.text
	output << "</body></html>"
	f.print output
end

`ebook-convert "tmp/#{@chap.title}.html" "tmp/#{@chap.title}.mobi" --authors "#{@chap.author}"`