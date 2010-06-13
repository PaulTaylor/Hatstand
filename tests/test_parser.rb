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
else
  puts p.failure_reason
end

puts 'tf_english.txt : '

str = IO.read 'steam_content/tf_english.txt'

require 'iconv'
conv = Iconv.new('UTF-8', 'UTF-16')
str = conv.iconv(str)

nvp = p.parse str
if nvp
  puts 'Parsed'
else
  puts p.failure_reason
end

