# frozen_string_literal: true

require "addressable/uri"
require_relative "hit"

module Relaton
  module Iec
    # Page of hit collection.
    class HitCollection < Core::HitCollection
      def_delegators :@array, :detect, :last, :max_by

      def search
        @array = fetch_from_gh
        self
      end

      def index
        @index ||= Relaton::Index.find_or_create :IEC, url: "#{Hit::GHURL}#{INDEXFILE}.zip" , file: "#{INDEXFILE}.yaml"
      end

      # @return [Relaton::Iec::ItemData, nil]
      def to_all_parts(r_year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        parts = @array.select { |h| h.part && h.hit[:code].match?(/^[\s\w-]+:#{r_year}/) }
        hit = parts.min_by { |h| h.part.to_i }
        return @array.first&.fetch unless hit

        bibitem = hit.item
        all_parts_item = bibitem.to_all_parts
        parts.reject { |h| h.hit[:code] == hit.hit[:code] }.each do |hi|
          bib = ItemData.new(
            formattedref: hi.hit[:code],
            docidentifier: [Docidentifier.new(content: hi.hit[:code], type: "IEC", primary: true)],
          )
          all_parts_item.relation << Relation.new(type: "partOf", bibitem: bib)
        end
        all_parts_item
      end

      private

      def fetch_from_gh
        return [] unless ref

        ref_yr = year && !/:\d{4}$/.match?(ref) ? "#{ref}:#{year}" : ref
        reference = ref_yr.sub(/^IEC\s(?=ISO\/IEC\sDIR)/, "")
        index.search do |row|
          row[:id].include? reference
        end.sort_by { |row| row[:id] }.map do |row|
          # pubid = row[:pubid].is_a?(Array) ? row[:pubid][0] : row[:pubid]
          Hit.new({ code: row[:id], file: row[:file] }, self)
        end
      end
    end
  end
end
