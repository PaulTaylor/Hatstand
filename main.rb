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

# Require my lookup parse results
require 'lookups'

# Define some helpers
helpers do

  # Name lookup
  def real_name(tf_int_item_name) 
    puts "Looked up #{tf_int_item_name}"
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
        list << item['quantity']
        get_item_real_name("Woop")
    end

    list.join(',')
end
    
