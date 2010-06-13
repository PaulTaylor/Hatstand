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

LOOKUP = Lookups.new

# Define some helpers
helpers do

  # Name lookup
  def real_name(tf_int_item_name) 
    item_str_identifier = LOOKUP.get_item_real_name(tf_int_item_name)
    # Now need to look this up in the steam_content/tf_english.txt
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
        item_idx = item['defindex']
        list << real_name(item_idx)
    end

    list.join(',')
end
    
