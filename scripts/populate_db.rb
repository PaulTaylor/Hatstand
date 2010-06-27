# Module for tf provided item txt file parsing code

require 'rubygems'
require 'treetop'
require 'polyglot'
require 'scripts/valve_txt'
require 'sequel'

  # File initialiser steps (ie. do the actual parsing)
  # Need to parse items_game.txt (for identifier from JSON numbers) AND
  # tf_english.txt for the localised real name of the item
 parser = ValveTxtParser.new
 parser.consume_all_input = false

 str = IO.read 'steam_content/items_game.txt'
 res = parser.parse str 
 @items = res.content_hash["items_game"]['items']

 # Translations
 en_str = IO.read 'steam_content/tf_english.txt'
 require 'iconv'
 conv = Iconv.new('UTF-8', 'UTF-16')
 en_str = conv.iconv(en_str)

 en_res = parser.parse en_str
 if en_res.nil? then
   puts parser.failure_reason 
 end
 @trans = en_res.content_hash["lang"]["tokens"]

 # Delete the old db first
 File.delete 'items.db'
 DB = Sequel.sqlite 'items.db'

 # Items table 
 # - item identifier
 # - translated name
 DB.create_table :items do
   primary_key :pk
   Integer :item_id
   String :en_name
   String :item_slot
 end
 
 # Populate the table
 db_items = DB[:items]
 @items.each do |k,item_info|
   puts item_info.inspect
   item_ident = item_info['item_name'].slice(1..-1)
   item_ident = item_ident.downcase
   # This will give the name only when it can be translated
   en_name = @trans[item_ident]
   db_items.insert(:item_id => k, :en_name => en_name, :item_slot => item_info['item_slot'])
 end
 puts "Item count: #{db_items.count}"

 # Push to heroku
 `heroku db:push sqlite://items.db`
