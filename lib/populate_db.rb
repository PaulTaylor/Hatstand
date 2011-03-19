# Module for tf provided item txt file parsing code

require 'rubygems'
require 'mongoid'
require './lib/load_mongoid.rb'
require './lib/item.rb'

require 'json'
require 'open-uri'

STEAM_API_KEY = ENV['steam_api_key']
API_URL = "http://api.steampowered.com/ITFItems_440/GetSchema/v0001/?language=en&key=#{STEAM_API_KEY}"
#API_URL = 'example.json'

res = JSON.parse(open(API_URL).read, { :symbolize_names => true })
items = res[:result][:items][:item]

# Items collection - will be dropped and recreated
Mongoid.database.drop_collection 'items'

# Populate the table
items.each do |item_info|
  Item.new(item_info).save
end
puts "Item count: #{items.count}"

# Also drop the users table
Mongoid.database.drop_collection 'users'

