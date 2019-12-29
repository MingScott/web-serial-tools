# web-serial-tools

TODO: Update this, rss_checker is better now

A collection of my WIP web serial reading tools, merged into a single repository. Merge in progress

# serial-scrape-ruby

A project for scraping arbitrary webnovels, with easy extension for specific cases by adding custom classes.

Will generate an html and a mobi with a table of contents.

When scraping formats not specified, will probably work but may contain artifacts (e.g links, incorrectly formatted boxes). If you expand the functionality, please submit a pull request :)

## Dependencies

    sudo apt install ruby calibre
    sudo gem install nokogiri
    sudo gem install mail

* ruby
* calibre

gems
* nokogiri
* mail

## Examples

### Scrape a serial into a mobi at a directory 
ruby serial_scrape.rb -n NAME -s FIRST_CHAPTER_URL -d ~/Downloads

### Scrape a serial into a mobi and send it as an attachment to an email address (default setup is gmx email through smtp as recommended by calibre)
ruby serial_scrape.rb -n NAME -s FIRST_CHAPTER_URL -t EMAIL_TO
-f EMAIL_FROM -p PASSWORD# rss-kindle-ruby

Personal project for parsing web serial content and sending to kindle.

## Dependencies:
### gems
* nokogiri
* open-uri
* mail

### external programs
* calibre

# Using this script

* Edit feeds.tsv for your preferred feeds. Note that the name you add in the field to the tsv is cosmetic only - feed will reference its name as assigned by feed creator for most things.
* You may need to write custom classes in rss_checker.rb for parsing webpage content - will default to loading entire page
* run rss_checker.rb
