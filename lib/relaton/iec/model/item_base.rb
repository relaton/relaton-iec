module Relaton
  module Iec
    class ItemBase < Item
      model ItemData

      include Bib::ItemBaseAttributes
    end
  end
end
