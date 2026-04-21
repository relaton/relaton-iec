require_relative "docidentifier"

module Relaton
  module Iec
    class ItemBase < Iso::ItemBase
      model ItemData

      attribute :docidentifier, Docidentifier, collection: true, initialize_empty: true
      attribute :relation, Relation, collection: true, initialize_empty: true
    end
  end
end
