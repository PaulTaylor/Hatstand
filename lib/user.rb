# Class for user info
class User
  include Mongoid::Document

  field :steamId64
  field :username
  field :avatarUrl

end
