#!/usr/bin/env ruby

require 'rubygems'

# Sinatra
require "sinatra"
require "sinatra/reloader" if development?

# Page/Stylesheet helpers
require 'sass'
require 'haml'

# stuff needed to get items from steamcommunity.com
require 'json'
require 'net/http'

# Use Sequel for db access
require 'sequel'

# Define some helpers
helpers do

  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://items.db')
  DS = DB[:items]

  # Name lookup
  def real_name(tf_int_item_name) 
    item_str_identifier = DS.filter(:item_id => tf_int_item_name).first[:en_name]
  end

end

get '/' do
   haml :index
end

get '/u/:username' do
    "Hello #{params[:username]}"
    url = "/id/#{params[:username]}/tfitems?json=1" 
    res = Net::HTTP.start('steamcommunity.com') { |http|
        http.get(url).body
    }
    list = [] 
    backpack = JSON.parse(res)
    backpack.each do |key, item|
        list << item 
    end

    haml :backpack, :locals => {:items => list}
end
    
