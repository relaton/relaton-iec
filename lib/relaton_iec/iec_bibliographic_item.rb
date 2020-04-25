module RelatonIec
  class IecBibliographicItem < RelatonIsoBib::IsoBibliographicItem
    TYPES = %w[
      international-standard technical-specification technical-report
      publicly-available-specification international-workshop-agreement
      guide
    ].freeze
  end
end
