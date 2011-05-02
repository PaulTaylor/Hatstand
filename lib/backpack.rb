require File.join(File.dirname(__FILE__), 'item.rb')

# ruby class for refactoring backup workings inside
class Backpack

  # Define a predictable order for item slots
  SLOT_INDEXES = {
    'Head' => 0,
    'Primary' => 1,
    'Secondary' => 2,
    'Melee' => 3,
    'PDA' => 4,
    'Misc' => 99
  }

  attr_reader :display_sections, :vis_data, :duplicates, :miscs, :items

  # Constructor
  def initialize(bpk_items, type)

    # Master list of items key-d by defindex
    @items = {}

    # This will return a list of backpack items for each display section
    @display_sections = {}
    SLOT_INDEXES.each do |section_name, sort_idx|
      @display_sections[section_name] = []
    end

    # This will return {class, item type, count} for the visualisation
    @vis_data = {}
    type::CLASS_MASKS.each do |class_name, mask_value|
      @vis_data[class_name] = {
        'head' => [],
        'primary' => [],
        'secondary' => [],
        'melee' => []
      }
    end

    # Foreach item
    bpk_items.each do |item_json|
      defidx = item_json[:defindex]
      bpk_item = (@items[defidx] ||= BackpackItem.new(item_json, type))
      bpk_item.update item_json
    end

    @items.each do |defindex, bpk_item|
      # Put in the correct display slot
      @display_sections[bpk_item.slot] << bpk_item if @display_sections[bpk_item.slot]
      # And in the current graph places
      bpk_item.used_by.each do |class_name|
        begin
          @vis_data[class_name][bpk_item.slot.downcase] << bpk_item.defindex
        rescue
          # ignore this
        end
      end
    end

    @duplicates = @items.values.find_all { |i| i.equippable? && i.count > 1 }
    @miscs = @items.values.find_all { |i| !i.equippable? }
  end

  # Allow drilling to items
  def [](idx)
    @items[idx]
  end

  # Returns the total number of items (including duplicates)
  def item_count
    @items.values.inject(0) do |count, item|
      count + item.count
    end
  end

end

# Class for an item in a backpack
class BackpackItem

  attr_reader :defindex, :count, :equipped_classes, :paint_col

  # Constructor
  # MUST be followed by a call to update
  def initialize(item_json, type)
    @defindex = item_json[:defindex]
    @item = type.where(:defindex => @defindex).first
    @equipped_classes = []
    @count = 0
    @type = type

    # Deal with the paint color
    @paint_col = 'transparent'
    if item_json[:attributes] then
      attr_list = item_json[:attributes]
      col_attr = attr_list.detect { |a| a[:defindex] == 142 }
      if (col_attr) then
        col_int = col_attr[:float_value]
        @paint_col = "#%06x" % col_int;
      end
    end

    # Special handling for paint - since it should be considered
    # to be painted its own colour
    @paint_col = @item.paint_col if type == TF_Item && @item.paint_col

    # tradable flag
    @tradable = !item_json[:flag_cannot_trade]
  end

  # Delegate stuff though to item if necessary
  def method_missing(name)
    @item.send(name)
  end

  def tradable?
    @tradable
  end

  def equippable?
    ! @item.used_by.empty?
  end

  def equipped_pics
    @equipped_classes.collect do |class_name|
      "/valve-imgs/20px-Leaderboard_class_#{class_name.downcase}.png"
    end
  end

  # Used to update the class values with a (possible duplicate) item
  def update(new_item_json)
    # Append any classes using this instance of the item to the equipped_classes array
    @item.used_by.each do |class_name|
      if @type::CLASS_MASKS[class_name]
        inventory = new_item_json[:inventory]
        inventory ||= 0
        if ( inventory & @type::CLASS_MASKS[class_name] ) > 0
          @equipped_classes << class_name
        end
      end
    end

    # Increase this items count
    @count += 1
  end

end
