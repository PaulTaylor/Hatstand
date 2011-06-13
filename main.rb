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

# Extra Stuff for WS & Parsing
require 'open-uri'
require 'xml'
require 'json/ext'

# my classes
require 'mongoid'
require './lib/item.rb'
require './lib/backpack.rb'
require './lib/user.rb'

configure do
  require './lib/load_mongoid.rb'
end

# Some constants
STARTUP_TIME = Time.now
STEAM_API_KEY = ENV['steam_api_key']
puts "Using steam api key = #{STEAM_API_KEY}"

ITEM_TYPES = {
  440 => TF_Item,
  620 => Portal_Item
}

APPS = {
  'tf2' => 440,
  'p2' => 620
}

# Define some helpers
helpers do

  def user_by_steam_id(steamId64)
    User.where(:steamId64 => steamId64).first || User.new({:steamId64 => steamId64})
  end

  def poke_mongo(steamId64, name)
    # Poke MongoDB for stats (only on production)
    coll = Mongoid.database['stats']
    mgo_doc = coll.find({'steamId64' => steamId64}).to_a[0]
    unless mgo_doc
      mgo_doc = {
        'steamId64' => steamId64,
        'count' => 0,
        'lastTime' => Time.now,
        'name' => name
      }
      mgo_doc = { '_id' => coll.insert(mgo_doc) }
    end
    coll.update({'_id' => mgo_doc['_id']}, {'$inc' => {'count' => 1}, '$set' => { 'lastTime' => Time.now }})
  end

end

# Handle errors
error do
  haml :error
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

    user = user_by_steam_id(steamId64)
    user.update({
      :avatarUrl => avatarUrl,
      :username => params[:username]
    })
    user.save

    # Forward to the backpack page, and get heroku's varnish to
    # cache the forward
    expires 3600, :public, :must_revalidate
    redirect "/id/#{steamId64}", 302
  end
end

get '/id/:steamId64' do
  redirect "/id/#{params[:steamId64]}/tf2"
end

get '/id/:steamId64/:app_name' do

  # if unknown app give 404
  not_found unless APPS[params[:app_name]]

  # grab the steamId from the url
  steamId64 = params[:steamId64].to_i
  user = user_by_steam_id(steamId64)
  app_id = APPS[params[:app_name]]

  if user.username.nil? then
    # This could be the case if the users table is empty and the steam id
    # (this) url is used

    # TODO Get the populate_db.rb script to update avatars from existing users
    # using this (or similar code)
    sc_url = "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0001/?key=#{STEAM_API_KEY}&steamids=#{steamId64}"
    sc_res = JSON.parse(open(sc_url).read, { :symbolize_names => true })
    player_list = sc_res[:response][:players][:player]
    player_list.each do |player|
      user.avatarUrl = player[:avatarfull]
      user.username = player[:personaname]
      user.save
      p user
    end
  end

  # Now I can make the steam api call for the actual backpack
  api_url = "http://api.steampowered.com/IEconItems_#{app_id}/GetPlayerItems/v0001/?key=#{STEAM_API_KEY}&SteamID=#{steamId64}"
  #api_url = './tests/backpack_test.json'
  backpackJson = open(api_url).read

  backpack = JSON.parse(backpackJson, { :symbolize_names => true })

  unless backpack[:result][:status] == 1 then
    haml :private, :locals => {
      :username => username,
      :avatarUrl => avatarUrl
    }
  else

    bpk_items = backpack[:result][:items]
    poke_mongo(steamId64, user[:username])
    bpk = Backpack.new(bpk_items, ITEM_TYPES[app_id])

    haml "backpack_#{app_id}".to_sym, :locals => {
      :user => user,
      :backpack => bpk
    }
  end
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

