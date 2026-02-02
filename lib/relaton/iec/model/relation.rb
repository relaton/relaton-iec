module Relaton
  module Iec
    class Relation < Bib::Relation
      attribute :bibitem, ItemBase
    end
  end
end
