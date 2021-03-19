module RelatonIec
  class IecBibliographicItem < RelatonIsoBib::IsoBibliographicItem
    TYPES = %w[
      international-standard technical-specification technical-report
      publicly-available-specification international-workshop-agreement
      guide
    ].freeze

    # @param hash [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def self.from_hash(hash)
      item_hash = ::RelatonIec::HashConverter.hash_to_bib(hash)
      new **item_hash
    end
  end
end
