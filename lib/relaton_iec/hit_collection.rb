# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    def_delegators :@array, :detect, :map, :last, :[], :max_by

    # @param pubid [Pubid::Iec::Identifier]
    # @param exclude [Array<Symbol>] keys to exclude from comparison (e.g. :year, :part, :type)
    def initialize(pubid, exclude: [:year])
      super pubid.to_s
      @pubid = pubid
      @exclude = exclude
      @index = Relaton::Index.find_or_create(
        :iec, url: "#{Hit::GHURL}#{INDEXFILE}.zip", file: "#{INDEXFILE}",
        pubid_class: Pubid::Iec::Identifier
      )
      @array = fetch_from_index
    end

    # @return [RelatonIec::IecBibliographicItem]
    def to_all_parts(r_year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      parts = @array.select { |h| h.part && (!r_year || h.hit[:pubid].year&.to_s == r_year) }
      hit = parts.min_by { |h| h.part.to_i }
      return @array.first&.fetch unless hit

      bibitem = hit.fetch
      all_parts_item = bibitem.to_all_parts
      parts.reject { |h| h.hit[:pubid] == hit.hit[:pubid] }.each do |hi|
        code = hi.hit[:pubid].to_s
        isobib = RelatonIec::IecBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: code),
          docid: [DocumentIdentifier.new(id: hi.hit[:pubid], type: "IEC", primary: true)],
        )
        all_parts_item.relation << RelatonBib::DocumentRelation.new(type: "partOf", bibitem: isobib)
      end
      all_parts_item
    end

    private

    # Returns array of integers for sorting compound parts like "2-1", "2-6"
    # @param part [String, nil] part string e.g. "1", "2-1", "2-6"
    # @return [Array<Integer>] e.g. [2, 1] for "2-1", [6] for "6"
    def part_sort_key(part)
      return [] unless part

      part.to_s.split("-").map(&:to_i)
    end

    def fetch_from_index
      return [] unless @pubid

      if @exclude.include?(:type)
        # Can't use exclude(:type) on pubid (subclass re-adds it),
        # so compare using to_h(add_type: false) hashes
        exclude_keys = @exclude - [:type]
        ref_hash = @pubid.to_h(add_type: false).reject { |k, _| exclude_keys.include?(k) }
        @index.search do |row|
          row_hash = row[:id].to_h(add_type: false).reject { |k, _| exclude_keys.include?(k) }
          ref_hash == row_hash
        end
      else
        ref_base = @pubid.exclude(*@exclude)
        @index.search do |row|
          ref_base == row[:id].exclude(*@exclude)
        end
      end.sort_by { |row| [row[:id].year.to_i, *part_sort_key(row[:id].part)] }.map do |row|
        Hit.new({ pubid: row[:id], file: row[:file] }, self)
      end
    end
  end
end
