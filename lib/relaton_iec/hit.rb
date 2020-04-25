# frozen_string_literal: true

module RelatonIec
  # Hit.
  class Hit < RelatonBib::Hit
    # Parse page.
    # @return [RelatonIec::IecBibliographicItem]
    def fetch
      @fetch ||= Scrapper.parse_page @hit
    end
  end
end
