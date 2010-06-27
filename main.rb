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
require 'yajl/http_stream'

# Use Sequel for db access
require 'sequel'

# Some constants
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
    url = "http://steamcommunity.com/id/#{params[:username]}/tfitems?json=1" 

    list = [] 
    backpack = Yajl::HttpStream.get(URI.parse(url), :symbolize_keys => true)
    backpack.each do |key, item|
        list << item 

      # Test for equipped classes
      equipped_by = CLASS_MASKS.collect do |mask, name|
        test = ( item[:inventory] & mask ) 
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

    haml :backpack, :locals => {:firsts => firsts, :dupes => dupes}
end
   
get '/main.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :main
end
