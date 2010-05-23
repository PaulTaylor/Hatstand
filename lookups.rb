# Module for tf provided item txt file parsing code

class Lookups

  # File initialiser steps (ie. do the actual parsing)
  # Need to parse items_game.txt (for identifier from JSON numbers) AND
  # tf_english.txt for the localised real name of the item
  # Just build some hashes for quick lookups
  def initialize
    item_file_lines = File.open('steam_content/items_game.txt').readlines
    
    # Need to write a parser for this
    # Probably best to use a library of some sort

  end

  def get_item_real_name(tf_item_identifier) 
    puts "get_item_real_name with #{tf_item_identifier}"
  end

end
