module RelatonIec
  module HashConverter
    include RelatonIsoBib::HashConverter
    extend self

    def hash_to_bib(hash)
      ret = super
      ret[:function] = ret[:ext][:function] if ret.dig(:ext, :function)
      ret[:updates_document_type] = ret[:ext][:updates_document_type] if ret.dig(:ext, :updates_document_type)
      unless ret.dig(:ext, :accessibility_color_inside).nil?
        ret[:accessibility_color_inside] = ret[:ext][:accessibility_color_inside]
      end
      ret[:price_code] = ret[:ext][:price_code] if ret.dig(:ext, :price_code)
      ret[:cen_processing] = ret[:ext][:cen_processing] unless ret.dig(:ext, :cen_processing).nil?
      ret[:secretary] = ret[:ext][:secretary] if ret.dig(:ext, :secretary)
      ret[:interest_to_committees] = ret[:ext][:interest_to_committees] if ret.dig(:ext, :interest_to_committees)
      ret
    end

    #
    # Ovverides superclass's method
    #
    # @param item [Hash]
    # @retirn [RelatonIec::IecBibliographicItem]
    def bib_item(item)
      IecBibliographicItem.new(**item)
    end

    def create_doctype(**args)
      DocumentType.new(**args)
    end
  end
end
