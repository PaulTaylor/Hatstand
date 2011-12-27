# Class for items
class Item
  include Mongoid::Document

  # List of fields
  field :en_name
  field :slot
  field :used_by
  field :item_id
  field :item_pic_url

  # Constructor
  def initialize(item_info, class_masks)
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
        slot = (item_info[:item_slot] || 'Misc').capitalize
    end
    self[:slot] = slot

    # if used_by_class doesn't exists - the item can be used by ALL classes
    # if used_by_class == [ null ] - then the item is not equippable
    # otherwise used_by_class contains the names of the appropriate classes
    used_by = item_info[:used_by_classes] || class_masks.keys
    self[:used_by] = used_by.compact

    self[:item_id] = item_info[:defindex]
    self[:item_pic_url] = "#{item_info[:image_url]}"

  end

end

class TFItem < Item

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

  # Need an additional field for paint colour
  field :paint_col

  # Add paint logic to the initialiser
  def initialize(item_info)
    super(item_info, CLASS_MASKS)

    # Get the colour of paint
    if item_info[:name][/^Paint Can/] then
      col_attr = item_info[:attributes].detect { |a| a[:class] == 'set_item_tint_rgb' }
      if (col_attr) then
        col_int = col_attr[:value]
        self[:paint_col] = "#%06x" % col_int;
      end
    end
  end


end

class PortalItem < Item

  # Masks for Portal Classes
  CLASS_MASKS = {
    'P-Body' => 0x00010000,
    'Atlas' => 0x00020000
  }

  def initialize(item_info)
    super(item_info, CLASS_MASKS)
  end

end
