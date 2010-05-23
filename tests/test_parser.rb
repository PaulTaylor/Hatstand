require 'rubygems'
require 'treetop'
require 'polyglot'
require 'valve_txt'

p = ValveTxtParser.new
p.consume_all_input = false

#str = IO.read 'steam_content/items_game.txt'
str = IO.read 'steam_content/gibus_text.txt'

nvp = p.parse(str)
if nvp
  puts 'Parsed'
  puts nvp.content_hash.inspect
else
  puts p.failure_reason
end

