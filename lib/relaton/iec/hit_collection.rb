# frozen_string_literal: true

require "addressable/uri"
require_relative "hit"

module Relaton
  module Iec
    # Page of hit collection.
    class HitCollection < Core::HitCollection
      def_delegators :@array, :detect, :last, :max_by, :sort_by

      # @param exclude [Array<Symbol>] keys to exclude from comparison (e.g. :year, :part, :type)
      def search(exclude: [:year])
        @array = fetch_from_index exclude
        self
      end

      # @return [Relaton::Iec::ItemData, nil]
      def to_all_parts(r_year, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        parts = @array.select { |h| h.part && (!r_year || h.hit[:id]&.year&.to_s == r_year) }
        if opts[:publication_date_before] || opts[:publication_date_after]
          parts = parts.select { |h| Bibliography.send(:year_in_range?, h.hit[:id].year.to_i, opts) }
        end
        hit = parts.min_by { |h| h.part.to_i }
        return @array.first&.item unless hit

        bibitem = hit.item
        all_parts_item = bibitem.to_all_parts
        parts.reject { |h| h.hit[:id] == hit.hit[:id] }.each do |hi|
          code = hi.hit[:id].to_s
          bib = ItemData.new(
            formattedref: code,
            docidentifier: [Docidentifier.new(content: code, type: "IEC", primary: true)],
          )
          all_parts_item.relation << Relation.new(type: "partOf", bibitem: bib)
        end
        all_parts_item
      end

      private

      VALID_ID_KEYS = %i[
        publisher number year type vap amendments corrigendums copublisher part base fragment edition database sheet
      ]

      def index
        @index ||= Relaton::Index.find_or_create(
          :IEC,
          url: "#{Hit::GHURL}#{INDEXFILE}.zip",
          file: "#{INDEXFILE}.yaml",
          id_keys: VALID_ID_KEYS,
          pubid_class: Pubid::Iec::Identifier
        )
      end

      # Returns array of integers for sorting compound parts like "2-1", "2-6"
      # @param part [String, nil] part string e.g. "1", "2-1", "2-6"
      # @return [Array<Integer>] e.g. [2, 1] for "2-1", [6] for "6"
      def part_sort_key(part)
        return [] unless part

        part.to_s.split("-").map(&:to_i)
      end

      # Compare pubids for matching, excluding specified fields
      # @param row_pubid [Pubid::Iec::Identifier] pubid from index row
      # @return [Boolean]
      def pubid_matches?(row_pubid, exclude)
        return false unless row_pubid

        if exclude.include?(:type)
          # Can't use exclude(:type) on pubid (subclass re-adds it),
          # so compare using to_h(add_type: false) hashes
          exclude_keys = exclude - [:type]
          ref_hash = @ref.to_h(add_type: false).reject { |k, _| exclude_keys.include?(k) }
          row_hash = row_pubid.to_h(add_type: false).reject { |k, _| exclude_keys.include?(k) }
          ref_hash == row_hash
        else
          @ref.exclude(*exclude) == row_pubid.exclude(*exclude)
        end
      end

      def fetch_from_index(exclude) # rubocop:disable Metrics/MethodLength
        return [] unless @ref

        index.search(@ref) do |row|
          pubid_matches?(row[:id], exclude)
        end.sort_by do |row|
          [row[:id].year.to_i, *part_sort_key(row[:id].part)]
        end.map do |row|
          Hit.new(row, self)
        end
      end
    end
  end
end
