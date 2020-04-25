module RelatonIec
  class XMLParser < RelatonIsoBib::XMLParser
    class << self
      private

      # override RelatonIsoBib::IsoBibliographicItem.bib_item method
      # @param item_hash [Hash]
      # @return [RelatonIec::IecBibliographicItem]
      def bib_item(item_hash)
        IecBibliographicItem.new item_hash
      end
    end
  end
end
