require 'json'
require 'mail'
require 'nokogiri'
require 'open-uri'

$threads = []
POOL_SIZE = 10

jobs = Queue.new
dormant = Queue.new

checkers = 