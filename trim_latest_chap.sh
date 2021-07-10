#!/usr/bin/env bash

ruby -r json -e "x = JSON.load File.read 'data/feed_data.json'; x.fetch(x.keys.keep_if{|k| k =~ /$1/}[0]).delete_at(0); puts JSON.pretty_generate x" > data/feed_data.json.test && mv data/feed_data.json.test data/feed_data.json
