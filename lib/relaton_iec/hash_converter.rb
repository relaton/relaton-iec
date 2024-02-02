module RelatonIec
  module HashConverter
    include RelatonIsoBib::HashConverter
    extend self

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
