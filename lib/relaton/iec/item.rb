require_relative "ext"

module Relaton
  module Iec
    class Item < Iso::Item
      model Bib::ItemData

      attribute :ext, Ext
    end
  end
end
