#!/usr/bin/env ruby

require 'rubygems'

# Sinatra
require "sinatra"
require "sinatra/reloader" if development?

# Page/Stylesheet helpers
require 'sass'
require 'haml'

# stuff needed to get items from steamcommunity.com
require 'uri'

# Use Sequel for db access
require 'sequel'

# Extra Stuff for WS & Parsing
require 'open-uri'
require 'xml'
require 'json/ext'

# Some constants
STEAM_API_KEY = ENV['steam_api_key']
puts "Using steam api key = #{STEAM_API_KEY}"

CLASS_MASKS = {
  0x001000000 => 'Engineer',
  0x000800000 => 'Spy',
  0x000400000 => 'Pyro',
  0x000200000 => 'Heavy',
  0x000100000 => 'Medic',
  0x000080000 => 'Demoman',
  0x000040000 => 'Soldier',
  0x000020000 => 'Sniper',
  0x000010000 => 'Scout'
}

# Define a predictable order for item slots
SLOT_INDEXES = Hash.new(99999)
SLOT_INDEXES.update({
  'Head' => 0,
  'Primary' => 1,
  'Secondary' => 2,
  'Melee' => 3
})

# Define some helpers
helpers do

  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://items.db')
  DS = DB[:items]

  # Name lookup
  def real_name(tf_int_item_name) 
    DS.filter(:item_id => tf_int_item_name).first[:en_name]
  end

  def item_slot(tf_int_item_name)
    slot = DS.filter(:item_id => tf_int_item_name).first[:item_slot]
    slot = slot.capitalize unless slot.nil?
    if slot == 'Pda2' then slot = 'PDA' end
    slot
  end

  def item_classes(tf_int_item_name)
    DS.filter(:item_id => tf_int_item_name).first[:item_classes]
  end

end

get '/' do
   haml :index
end

get '/u/:username' do
  
  # First, get the steamcommunity page for this user to retrieve the steamId64 number
  sc_url = "http://steamcommunity.com/id/#{params[:username]}?xml=1"
  sc_doc = XML::Reader.io(open(sc_url), :options => XML::Parser::Options::NOBLANKS |
                                                    XML::Parser::Options::NOENT)
  steamId64 = nil
  avatarUrl = nil
  continue = true
  while sc_doc.read && continue
    doc = sc_doc
    unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
      # Look for stuff of interest
      case doc.name
        when 'steamID64' then 
          doc.read
          # The first one is the one we actually want
          steamId64 = doc.value if steamId64.nil?
        when 'privacyState' then 
          doc.read 
          privateProfile = ( 'private' == doc.value )
        when 'avatarFull' then 
          doc.read
          avatarUrl = doc.value if avatarUrl.nil?
      end
    end

    # Should we quit here?
    continue = (steamId64.nil? || avatarUrl.nil?)
  end
  doc.close

  if privateProfile then
    haml :private, :locals => { 
      :username => params[:username],
      :avatarUrl => avatarUrl
    }
  else
    # Now I can make the steam api call to the web-service for the actual backpack
    api_url = "http://api.steampowered.com/ITFItems_440/GetPlayerItems/v0001/?key=#{STEAM_API_KEY}&SteamID=#{steamId64}"
    backpack = JSON.parse(open(api_url).read, { :symbolize_names => true })
    backpack = backpack[:result][:items][:item]

    json_top = {}
    class_type_map = {}
    CLASS_MASKS.values.each do |v|
      class_type_map[v] = Hash.new(0)
    end

    list = [] 
    backpack.each do |item|
      list << item 

      # Test for equipped classes
      equipped_by = CLASS_MASKS.collect do |mask, name|
        test = ( item[:inventory] & mask ) || 0 
        name if test > 0
      end
      item[:equipped_by] = equipped_by.find_all {|i| i}

      # Need to test which class this CAN be equipped by and 
      # add/update the class/type count dictionarys
      classes_for_item_str = item_classes(item[:defindex])
      classes_for_item_str = '' if classes_for_item_str.nil? 

      classes_for_item_str.split(',').each do |clazz_name|
        class_type_map[clazz_name][item_slot(item[:defindex])] += 1
      end

      # This need to be Hash keyed by clazz name
      # which value is an array
      # each array element is a hash with slot_name -> count
      class_type_map.each do |k,v|
        json_top[k] = []
        v.each do |slot_name, count|
          json_top[k] << { 
            'slot' => slot_name, 
            'slot_index' => SLOT_INDEXES[slot_name],
            'items' => count 
          }
        end
      end

    end

    # Make sure the equipped items are not put in dupes
    list, firsts = list.partition { |it| it[:equipped_by].empty? }
    dupes = [] 
    list.each { |i|
      # Put into firsts if doesn't exist already else in dupes
      if nil == ( firsts.detect { |o| o[:defindex] == i[:defindex] } )
        firsts << i
      else 
        dupes << i
      end
    }

    firsts = firsts.sort_by {|it| it[:defindex]}

    haml :backpack, :locals => {
      :username => params[:username], 
      :firsts => firsts, 
      :dupes => dupes,
      :avatarUrl => avatarUrl,
      :vis_json => [json_top].to_json
    }  
  end
end
   
get '/privacy' do
    haml :privacy
end

get '/:ss_name.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass params[:ss_name].intern
end

get '/:style_name/style.css' do
  content_type 'text/css', :charset => 'utf-8'
  redirect "/#{params[:style_name]}.css", 301
end

