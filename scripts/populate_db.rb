# Module for tf provided item txt file parsing code

require 'rubygems'
require 'sequel'

# use xml-simple for xml parsing
require 'xmlsimple'
require 'open-uri'

# File initialiser steps (ie. do the actual parsing)
# Need to parse items_game.txt (for identifier from JSON numbers) AND
# tf_english.txt for the localised real name of the item

STEAM_API_KEY = ENV['steam_api_key']

res = XmlSimple.xml_in(
  open("http://api.steampowered.com/ITFItems_440/GetSchema/v0001/?language=en&key=#{STEAM_API_KEY}&format=xml").read,
  'KeyToSymbol' => true
)   
@items = res[:items][0][:item]

# Items table - will be dropped and recreated 
# - item identifier
# - translated name
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://items.db')
DB.create_table! :items do
  primary_key :pk
  Integer :item_id
  String :en_name
  String :item_slot
end

# Populate the table
db_items = DB[:items]
@items.each do |item_info|
  en_name = item_info[:item_name][0]
  # There seems to be some inconsistency here with where the real name is stored
  # Check to see if the specified name starts with TF_ and it it does, get the 
  # :name string instead
  en_name = item_info[:name][0] if en_name['TF_']

  # Replace item_slot with token for tokens
  if en_name['Slot Token'] then
    item_info[:item_slot][0] = 'Token'
  end

  # This will give the name only when it can be translated
  db_items.insert(:item_id => item_info[:defindex], :en_name => en_name, :item_slot => item_info[:item_slot])
end
puts "Item count: #{db_items.count}"

