# frozen_string_literal: true

module RelatonIec
  # Hit.
  class Hit < RelatonBib::Hit
    GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-iec/main/"

    attr_writer :fetch

    # Parse page.
    # @return [RelatonIec::IecBibliographicItem]
    def fetch
      @fetch ||= begin
        url = "#{GHURL}#{hit[:file]}"
        resp = Net::HTTP.get URI(url)
        hash = YAML.safe_load resp
        hash["fetched"] = Date.today.to_s
        IecBibliographicItem.from_hash hash
      end
    end

    def part
      @part ||= hit[:code].match(/(?<=-)[\w-]+/)&.to_s
    end

    def inspect
      "<#{self.class}:#{format('%<id>#.14x', id: object_id << 1)} " \
        "@text=\"#{@hit_collection&.text}\" " \
        "@fetched=\"#{!@fetch.nil?}\" " \
        "@fullIdentifier=\"#{@fetch&.shortref(nil, no_year: true)}\" " \
        "@title=\"#{@hit[:code]}\">"
    end
  end
end
