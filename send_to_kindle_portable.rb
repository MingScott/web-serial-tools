#! /usr/bin/env ruby
require 'mail'
require 'optparse'

	def send_file(fname, conf, subj = '') #accepts conf hash with fields "username","password","recipient"
		puts "Sending chapters..."
		gmx_options = { :address 		=> "mail.gmx.com",
	            :port                 	=> 587,
	            :user_name            	=> conf["username"],
	            :password             	=> conf["password"],
	            :authentication       	=> 'plain',
	            :enable_starttls_auto 	=> true  }
		Mail.defaults do
			delivery_method :smtp, gmx_options
		end
		begin
			Mail.deliver do
			  to conf["recipient"]
			  from conf["username"]
			  subject subj
			  add_file fname
			end
		rescue
			puts "Failed to send mail. Retrying..."
			sleep 2
			retry
		end
	end

@mail_conf 		= {
  "username" => "",
  "password" => "",
  "recipient"=> ""
}

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
	send_file f, @mail_conf
end
