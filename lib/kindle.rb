#! /usr/bin/env ruby
require 'mail'

module Kindle
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
end