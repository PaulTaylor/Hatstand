# Include to setup a connection to Mongoid
require 'mongoid'

Mongoid.configure do |config|
  MONGOHQ_URL = ENV['MONGOHQ_URL'] || 'mongodb://localhost/'
  mgo_uri = URI.parse MONGOHQ_URL
  mongo_db_name = mgo_uri.path.gsub(/^\//, '')
  mongo_db_name = 'hatstand' if mongo_db_name == ''
  mgo_conn = Mongo::Connection.from_uri MONGOHQ_URL

  config.master = mgo_conn[mongo_db_name]
  config.persist_in_safe_mode = true
end

puts 'connected to mongohq'

