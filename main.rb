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
STARTUP_TIME = Time.now
STEAM_API_KEY = ENV['steam_api_key']
puts "Using steam api key = #{STEAM_API_KEY}"

CLASS_MASKS = {
  'Engineer' => 0x001000000,
  'Spy' => 0x000800000,
  'Pyro' => 0x000400000,
  'Heavy' => 0x000200000,
  'Medic' => 0x000100000,
  'Demoman' => 0x000080000,
  'Soldier' => 0x000040000,
  'Sniper' => 0x000020000,
  'Scout' => 0x000010000
}

# Define a predictable order for item slots
SLOT_INDEXES = Hash.new(99999)
SLOT_INDEXES.update({
  'Head' => 0,
  'Primary' => 1,
  'Secondary' => 2,
  'Melee' => 3,
  'PDA' => 4,
  'Misc' => 5
})

# Define some helpers
helpers do

  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://hatstand.db')
  DS = DB[:items]
  USERS = DB[:users]

  def dbLookup(defindex) 
    DS.filter(:item_id => defindex).first
  end

  def user(steamId64)
    USERS.filter(:steamId64 => steamId64.to_s).first
  end

  def update_user(updates)
    USERS.filter(:steamId64 => updates[:steamId64]).delete
    USERS.insert(updates)
  end

end

get '/' do
  # This can be cached long term because Heroku will flush its varnish
  # front end on deploy 
  expires 43200, :public, :must_revalidate
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
  unknownProfile = true
  while sc_doc.read && continue
    doc = sc_doc
    unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
      # Look for stuff of interest
      case doc.name
        when 'steamID64' then 
          doc.read
          # The first one is the one we actually want
          steamId64 = doc.value if steamId64.nil?
          unknownProfile = false
        when 'privacyState' then 
          doc.read 
          privateProfile = ( 'private' == doc.value )
          unknownProfile = false
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
  elsif unknownProfile then
    haml :unknown, :locals => { 
      :username => params[:username],
      :avatarUrl => avatarUrl
    }
  else 

    # Update the db with the latest info
    update_user({
      :steamId64 => steamId64,
      :avatarUrl => avatarUrl,
      :username => params[:username]
    })

    # Forward to the backpack page, and get heroku's varnish to
    # cache the forward
    expires 3600, :public, :must_revalidate
    redirect "/id/#{steamId64}", 302

  end
end

get '/id/:steamId64' do

  # grab the steamId from the url
  steamId64 = params[:steamId64].to_i
  user = user(steamId64)
  avatarUrl = ''
  username = ''

  if user.nil? then
    # This could be the case if the users table is empty and the steam id
    # (this) url is used
    
    # TODO Get the populate_db.rb script to update avatars from existing users
    # using this (or similar code)
    sc_url = "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0001/?key=#{STEAM_API_KEY}&steamids=#{steamId64}"
    sc_res = JSON.parse(open(sc_url).read, { :symbolize_names => true })
    player_list = sc_res[:response][:players][:player]
    player_list.each do |player| 
      update_user({
        :steamId64 => player[:steamId64], 
        :avatarUrl => player[:avatarfull],
        :username => player[:personaname]
      })
      username = player[:personaname]
      avatarUrl = player[:avatarfull]
    end
  else
    avatarUrl = user[:avatarUrl]
    username = user[:username]
  end

  # Now I can make the steam api call for the actual backpack
  api_url = "http://api.steampowered.com/ITFItems_440/GetPlayerItems/v0001/?key=#{STEAM_API_KEY}&SteamID=#{steamId64}"
  backpackJson = open(api_url).read 

  backpack = JSON.parse(backpackJson, { :symbolize_names => true })
  backpack = backpack[:result][:items][:item]

  # Example of the use of this has
  # classCategoryItem(<class>)(<slot>) = [ item_json, item_json ]
  classSlotItem = Hash.new
  # Populate hash with empty collections
  CLASS_MASKS.each do |class_name, mask|
    classSlotItem[class_name] = Hash.new
    SLOT_INDEXES.each do |slot_name, slot_idx| 
      classSlotItem[class_name][slot_name] = Hash.new
    end
  end

  observedDefIds = Hash.new
  miscs = []
  duplicates = []
  backpack.each do |bItem|
      
    # Get the schema entry for this item
    schemaEntry = dbLookup(bItem[:defindex])
    possibleClasses = ( schemaEntry[:item_classes] || '' ).split(',')
    slot_name = schemaEntry[:item_slot]

    if possibleClasses.empty? then
      # Non-equippable item - like Scrap for example
      miscs << {
        :defindex => bItem[:defindex],
        :real_name => bItem[:custom_name] || schemaEntry[:en_name],
        :img_url => schemaEntry[:item_pic_url]
      }
    elsif observedDefIds[bItem[:defindex]] then

      # Here just need to check that said item is not equipped, and to change the equipped
      # value of the item in the classSlotItem hash if it is
      possibleClasses.each do |class_name|
        mask = CLASS_MASKS[class_name]
        equipped = ( bItem[:inventory] & mask ) || 0 
        if (equipped > 0) then
          match = classSlotItem[class_name][slot_name][bItem[:defindex]]
          match[:equipped] = true 
        end
      end

      duplicates << {
        :defindex => bItem[:defindex], 
        :real_name => bItem[:custom_name] || schemaEntry[:en_name],
        :img_url => schemaEntry[:item_pic_url]
      }
    else
      
      # Add this item to classSlotItem in the correct location(s)
      possibleClasses.each do |class_name|

        # Is the item equipped by this class?
        mask = CLASS_MASKS[class_name]
        equipped = ( bItem[:inventory] & mask ) || 0 

        classSlotItem[class_name][slot_name][bItem[:defindex]] = { 
          :defindex => bItem[:defindex], 
          :equipped => equipped > 1,
          :real_name => bItem[:custom_name] || schemaEntry[:en_name],
          :img_url => schemaEntry[:item_pic_url]
        }
      end

      # Mark that we have seen this item now
      observedDefIds[bItem[:defindex]] = 1
    end

  end

  haml :backpack, :locals => {
    :sections => SLOT_INDEXES.keys.sort { |one,two| SLOT_INDEXES[one] <=> SLOT_INDEXES[two] },
    :username => username, 
    :classSlotItem => classSlotItem,
    :dupes => duplicates,
    :miscs => miscs,
    :avatarUrl => avatarUrl
  }  
end
   
get '/privacy' do
    haml :privacy
end

# Generate stylesheets from sass templates
get '/:ss_name.css' do
  # This can be cached long term because Heroku will flush its varnish
  # front end on deploy 
  expires 43200, :public, :must_revalidate
  content_type 'text/css', :charset => 'utf-8'
  sass params[:ss_name].intern
end

get '/:style_name/style.css' do
  expires 43200, :public, :must_revalidate
  redirect "/#{params[:style_name]}.css", 302
end

