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
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://hatstand.db')
DB.create_table! :items do
  primary_key :pk
  Integer :item_id
  String :en_name
  String :item_slot
  String :item_classes
  String :item_pic_url
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
  elsif item_info[:item_slot][0] == 'pda2' then
    item_info[:item_slot][0] = 'PDA'
  elsif item_info[:item_slot] then
    item_info[:item_slot] = item_info[:item_slot][0].capitalize
  end


  used_by_classes_raw = item_info[:used_by_classes]
  require 'pp'
  if used_by_classes_raw.nil? then
    used_by_str = nil
  else
    used_by_str = used_by_classes_raw[0].values.join(',')
  end
 
  if used_by_str.nil? then
    used_by_str = 'Scout,Soldier,Pyro,Demoman,Heavy,Engineer,Medic,Sniper,Spy'
  end

  # This will give the name only when it can be translated
  db_items.insert(:item_id => item_info[:defindex], 
                  :en_name => en_name, 
                  :item_slot => item_info[:item_slot],
                  :item_classes => used_by_str,
                  :item_pic_url => "#{item_info[:image_url]}"
                 )
end
puts "Item count: #{db_items.count}"

# Also recreate the users table
DB.create_table! :users do
  primary_key :pk
  Bignum :steamId64
  String :avatarUrl
  String :username
end
