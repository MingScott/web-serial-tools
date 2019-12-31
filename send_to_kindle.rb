#!/usr/bin/env ruby
require_relative 'lib/kindle'
include Kindle
require 'optparse'
require 'json'

@mail_json 		= 'conf/mail.json'
@mail_conf 		= JSON.parse File.read @mail_json

OptionParser.new do |o|
	o.banner = ""
	o.on("-u", "--username STRING") do |uname_string|
		@mail_conf["username"] = uname_string
	end
	o.on("-p", "--password STRING") do |password_string|
		@mail_conf["password"] = password_string
	end
	o.on("-k", "--kindle EMAIL") do |email_string|
		@mail_conf["recipient"] = email_string
	end
end.parse!

ARGV.each do |f|
	Kindle::send_file f, @mail_conf
end