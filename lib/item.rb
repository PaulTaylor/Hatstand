# Class for items
class Item
  include Mongoid::Document

  # Masks used to represent TF classes in the backback
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

  # List of fields
  field :en_name
  field :slot
  field :used_by
  field :item_id
  field :item_pic_url

  # Constructor
  def initialize(item_info)
    super()

    self[:defindex] = item_info[:defindex]

    en_name = item_info[:item_name]
    # There seems to be some inconsistency here with where the real name is stored
    # Check to see if the specified name starts with TF_ and it it does, get the
    # :name string instead
    en_name = item_info[:name] if en_name['TF_']
    self[:en_name] = en_name

    # Replace item_slot with token for tokens
    slot = 'Token' if en_name['Slot Token']
    case item_info[:item_slot]
      when 'pda2'
        slot = 'PDA'
      else
        slot = item_info[:item_slot].capitalize
    end
    self[:slot] = slot

    used_by = (item_info[:used_by_classes] || {})[:class]
    unless used_by then
      used_by = CLASS_MASKS.keys
    end
    self[:used_by] = used_by.compact

    self[:item_id] = item_info[:defindex]
    self[:item_pic_url] = "#{item_info[:image_url]}"

  end

end
