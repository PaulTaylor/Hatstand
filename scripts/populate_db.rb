# Module for tf provided item txt file parsing code

require 'rubygems'
require 'treetop'
require 'polyglot'
require 'scripts/valve_txt'
require 'sequel'

# use xml-simple for xml parsing
require 'xmlsimple'
require 'open-uri'

# File initialiser steps (ie. do the actual parsing)
# Need to parse items_game.txt (for identifier from JSON numbers) AND
# tf_english.txt for the localised real name of the item

STEAM_API_KEY = ENV['STEAM_API_KEY']

res = XmlSimple.xml_in(
  open("http://api.steampowered.com/ITFItems_440/GetSchema/v0001/?key=#{STEAM_API_KEY}&format=xml").read,
  'KeyToSymbol' => true
)   
@items = res[:items][0][:item]

# Translations
en_str = IO.read 'steam_content/tf_english.txt'
require 'iconv'
conv = Iconv.new('UTF-8', 'UTF-16')
# See http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/ for a 
# reason why the dodge on the next line is require
en_str = conv.iconv(en_str + ' ')[0..-2]

parser = ValveTxtParser.new
parser.consume_all_input = false
en_res = parser.parse en_str
if en_res.nil? then
  puts parser.failure_reason 
end
@trans = en_res.content_hash[:lang][:tokens]

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
puts @trans.inspect
@items.each do |item_info|
  item_ident = item_info[:item_name][0].slice(1..-1).downcase.intern
  puts item_ident.inspect
  # This will give the name only when it can be translated
  en_name = @trans[item_ident]
  db_items.insert(:item_id => item_info[:defindex], :en_name => en_name, :item_slot => item_info[:item_slot])
end
puts "Item count: #{db_items.count}"

# Push to heroku
`heroku db:push sqlite://items.db`
