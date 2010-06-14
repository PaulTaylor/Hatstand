# Module for tf provided item txt file parsing code

require 'rubygems'
require 'treetop'
require 'polyglot'
require 'valve_txt'

class Lookups

  # File initialiser steps (ie. do the actual parsing)
  # Need to parse items_game.txt (for identifier from JSON numbers) AND
  # tf_english.txt for the localised real name of the item
  # Just build some hashes for quick lookups
  def initialize
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
  end

  def get_item_real_name(tf_item_identifier) 
    # tf_item_identifier is a number so doesn't need downcasing
    puts "Getting name for id : #{tf_item_identifier.inspect}"
    item_info = @items[tf_item_identifier.to_s]
    if item_info.nil?
      tf_item_identifier
    else 
      item_ident = item_info['item_name'].slice(1..-1)
      item_ident = item_ident.downcase
      # This will give the name only when it can be translated
      @trans[item_ident] || "#{item_ident}*"
    end
  end

end
