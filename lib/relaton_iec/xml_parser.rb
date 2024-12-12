module RelatonIec
  class XMLParser < RelatonIsoBib::XMLParser
    class << self
      # Override RelatonIsoBib::XMLParser.item_data method.
      # @param isoitem [Nokogiri::XML::Element]
      # @returtn [Hash]
      def item_data(isoitem) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        data = super
        ext = isoitem.at "./ext"
        return data unless ext

        data[:function] = ext.at("./function")&.text
        data[:updates_document_type] = ext.at("./updates-document-type")&.text
        aci = ext.at("./accessibility-color-inside")
        data[:accessibility_color_inside] = aci.text == "true" if aci
        cp = ext.at("./cen-processing")
        data[:cen_processing] = cp.text == "true" if cp
        data[:secretary] = ext.at("./secretary")&.text
        data[:interest_to_committees] = ext.at("./interest-to-committees")&.text
        data
      end

      private

      # override RelatonIsoBib::IsoBibliographicItem.bib_item method
      # @param item_hash [Hash]
      # @return [RelatonIec::IecBibliographicItem]
      def bib_item(item_hash)
        IecBibliographicItem.new(**item_hash)
      end

      def create_doctype(type)
        DocumentType.new type: type.text, abbreviation: type[:abbreviation]
      end
    end
  end
end
