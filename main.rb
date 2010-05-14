require 'rubygems'
require 'sinatra'
require 'haml'

# stuff needed to get items from steamcommunity.com
require 'json'
require 'net/http'

get '/' do
   haml :index
end

get '/u/:username' do
    "Hello #{params[:username]}"
    url = "/id/#{params[:username]}/tfitems?json=1" 
    Net::HTTP::Proxy('proxy.intra.bt.com', 8080).start('www.steamcommunity.com') { |http|
        http.get(url).body
    }
end
    
