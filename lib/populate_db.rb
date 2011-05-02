# Module for tf provided item txt file parsing code

require 'rubygems'
require 'mongoid'
require './lib/load_mongoid.rb'
require './lib/item.rb'

require 'json'
require 'open-uri'

STEAM_API_KEY = ENV['steam_api_key']

# Items collection - will be dropped and recreated
Mongoid.database.drop_collection TF_Item.collection_name
Mongoid.database.drop_collection Portal_Item.collection_name

{440 => TF_Item, 620 => Portal_Item}.each do |app, type|

  api_url = "http://api.steampowered.com/IEconItems_#{app}/GetSchema/v0001/?language=en&key=#{STEAM_API_KEY}"
  res = JSON.parse(open(api_url).read, { :symbolize_names => true })
  items = res[:result][:items]

  # Populate the table
  items.each do |item_info|
    type.new(item_info).save
  end
  puts "#{app} Item count: #{items.count}"

end

# Also drop the users table
Mongoid.database.drop_collection 'users'

