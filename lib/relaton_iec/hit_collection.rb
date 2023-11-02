# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    def_delegators :@array, :detect, :map, :last, :[], :max_by

    INDEX_FILE = "index1.yaml"

    # @param ref [String]
    # @param year [String, nil]
    def initialize(ref, year = nil)
      super ref, year
      @index = Relaton::Index.find_or_create :IEC, url: "#{Hit::GHURL}index1.zip" , file: INDEX_FILE
      @array = fetch_from_gh
    end

    # @return [RelatonIec::IecBibliographicItem]
    def to_all_parts(r_year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      parts = @array.select { |h| h.part && h.hit[:code].match?(/^[\s\w-]+:#{r_year}/) }
      hit = parts.min_by { |h| h.part.to_i }
      return @array.first&.fetch unless hit

      bibitem = hit.fetch
      all_parts_item = bibitem.to_all_parts
      parts.reject { |h| h.hit[:code] == hit.hit[:code] }.each do |hi|
        isobib = RelatonIec::IecBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: hi.hit[:code]),
          docid: [RelatonBib::DocumentIdentifier.new(id: hi.hit[:code], type: "IEC", primary: true)],
        )
        all_parts_item.relation << RelatonBib::DocumentRelation.new(type: "partOf", bibitem: isobib)
      end
      all_parts_item
    end

    private

    def fetch_from_gh
      return [] unless text

      ref = year && !/:\d{4}$/.match?(text) ? "#{text}:#{year}" : text
      reference = ref.sub(/^IEC\s(?=ISO\/IEC\sDIR)/, "")
      @index.search do |row|
        row[:id].include? reference
      end.sort_by { |row| row[:id] }.map do |row|
        # pubid = row[:pubid].is_a?(Array) ? row[:pubid][0] : row[:pubid]
        Hit.new({ code: row[:id], file: row[:file] }, self)
      end
    end
  end
end
