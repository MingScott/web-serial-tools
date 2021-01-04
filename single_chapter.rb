#!/usr/bin/env ruby
require_relative "lib/serial-chapter"
include SerialChapter
require "fileutils"
@url = ARGV[0]
# @url = "https://palewebserial.wordpress.com/2021/01/02/gone-ahead-7-9/"
@chap_class = SerialChapter::classFinder @url
begin
	@chap = @chap_class.new @url
rescue
	retry
end

File.open("tmp/#{@chap.title}.html","w") do |f|
	output = <<-EOF
<!DOCTYPE html>
<html>
<head>
	<title></title>
</head>
<body>

EOF
	output << "<h1>#{@chap.title}</h1>"
	output << @chap.text
	output << "</body></html>"
	f.print output
end

`ebook-convert "tmp/#{@chap.title}.html" "tmp/#{@chap.title}.mobi"`