require_relative "docidentifier"
require_relative "ext"

module Relaton
  module Iec
    class Relation < Bib::Relation
    end

    class Item < Iso::Item
      model ItemData

      attribute :docidentifier, Docidentifier, collection: true, initialize_empty: true
      attribute :relation, Relation, collection: true, initialize_empty: true
      attribute :ext, Ext
    end
  end
end

require_relative "item_base"
require_relative "relation"
