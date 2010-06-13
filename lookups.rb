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
     str = IO.read 'steam_content/items_game.txt'
     res = parser.parse str 
     @items = res.content_hash["items_game"]['items']

     # Translations
     en_str = IO.read 'steam_content/tf_english.txt'
     en_res = parser.parse en_str
     puts en_res.inspect
  end

  def get_item_real_name(tf_item_identifier) 
    puts "Getting name for id : #{tf_item_identifier.inspect}"
    item_info = @items[tf_item_identifier.to_s]
    item_info['name'] unless item_info.nil?
  end

end
