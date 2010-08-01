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
require 'xmlsimple'
require 'json/pure'

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
    slot.capitalize unless slot.nil?
  end

end

get '/' do
   haml :index
end

get '/u/:username' do

  # First, get the steamcommunity page for this user to retrieve the steamId64 number
  sc_url = "http://steamcommunity.com/id/#{params[:username]}?xml=1"
  sc_res = XmlSimple.xml_in(open(sc_url).read)
  puts sc_res.inspect

  # Need to check privacy state to see if we are allowed to see the backpack
  steamId64 = sc_res['steamID64']
  privateProfile = sc_res['privacyState'] == ['private']
  avatarUrl = sc_res['avatarFull']
  puts privateProfile

  if privateProfile then
    haml :private, :locals => { :usernane => params[:username] }
  else
    # Now I can make the steam api call to the web-service for the actual backpack
    api_url = "http://api.steampowered.com/ITFItems_440/GetPlayerItems/v0001/?key=#{STEAM_API_KEY}&SteamID=#{steamId64}"
    raw_json_file = open(api_url).read
    backpack = JSON.parse(raw_json_file, { :symbolize_names => true })
    backpack = backpack[:result][:items][:item]

    list = [] 
    backpack.each do |item|
      list << item 

      # Test for equipped classes
      equipped_by = CLASS_MASKS.collect do |mask, name|
        test = ( item[:inventory] & mask ) || 0 
        name if test > 0
      end
      item[:equipped_by] = equipped_by.find_all {|i| i}

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

    haml :backpack, :locals => {:username => params[:username], :firsts => firsts, :dupes => dupes}
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
  redirect "/#{params[:style_name]}.css", 301
end
