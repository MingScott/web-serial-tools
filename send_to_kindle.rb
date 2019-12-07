#!/usr/bin/env ruby
require 'mail'
require 'optparse'

@uname = ""
@password = ""
@kindle = ""
OptionParser.new do |o|
	o.banner = ""
	o.on("-u", "--username STRING") do |uname_string|
		@uname = uname_string
	end
	o.on("-p", "--password STRING") do |password_string|
		@password = password_string
	end
	o.on("-k", "--kindle EMAIL") do |email_string|
		@kindle = email_string
	end
end.parse!

def send_file(fname, uname, password, kindle)
	gmx_options = { :address              => "mail.gmx.com",
            :port                 => 587,
            :user_name            => uname,
            :password             => password,
            :authentication       => 'plain',
            :enable_starttls_auto => true  }
	Mail.defaults do
		delivery_method :smtp, gmx_options
	end

	Mail.deliver do
	  to kindle
	  from uname
	  subject ' '
	  add_file fname
	end
end

ARGV.each do |f|
	send_file f, @uname, @password, @kindle
end