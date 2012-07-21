# Module for tf provided item txt file parsing code

require 'rubygems'
require 'mongoid'
require './lib/item.rb'

require 'json'
require 'open-uri'

STEAM_API_KEY = ENV['steam_api_key']

# Items collection - will be dropped and recreated
Mongoid.load!("config/mongoid.yml")
Mongoid.default_session[TFItem.collection_name].drop()
Mongoid.default_session[PortalItem.collection_name].drop()

{440 => TFItem, 620 => PortalItem}.each do |app, type|

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
Mongoid.default_session['users'].drop()

