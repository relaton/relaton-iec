module Relaton
  module Iec
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
