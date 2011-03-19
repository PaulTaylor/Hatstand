require 'json'

require './lib/load_mongoid.rb'
require './lib/backpack'
require 'test/unit'

class TestBackpack < Test::Unit::TestCase

  def test_initialize

    # read json from local file
    backpack_file = File.join(File.dirname(__FILE__), 'backpack_test.json')
    backpack = JSON.parse(open(backpack_file).read, { :symbolize_names => true })
    bpk_items = backpack[:result][:items][:item]

    # Construct the backpack
    bpk = Backpack.new(bpk_items)

    # Check all of the items are there
    assert_equal bpk_items.size, bpk.item_count

    # Check the number of duplicates is accurate
    assert_equal 8, bpk.duplicates.size

    # Check the miscs
    assert_equal 5, bpk.miscs.size

    # Check non-tradable items as marked as such
    assert !bpk[125].tradable?

    # Check the fedora is equipped by spy
    ec = bpk[55].equipped_classes
    assert ec == ['Spy'], "Fedora not equipped by Spy! (actual: #{ec})"
  end

end
