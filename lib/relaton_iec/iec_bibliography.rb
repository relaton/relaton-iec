# frozen_string_literal: true

require "relaton_iec/hit_collection"
require "date"

module RelatonIec
  # Class methods for search IEC standards.
  class IecBibliography
    class << self
      ##
      # Search for standards entries.
      #
      # @param pubid [Pubid::Iec::Identifier]
      # @param exclude [Array<Symbol>] keys to exclude from comparison
      # @return [RelatonIec::HitCollection]
      def search(pubid, exclude: [:year])
        HitCollection.new pubid, exclude: exclude
      rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError => e
        raise RelatonBib::RequestError, e.message
      end

      # @param code [String] the IEC standard code to look up (e.g. "IEC 8000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      #   reference is required
      # @return [RelatonIec::IecBibliographicItem, nil]
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        opts[:all_parts] ||= code.match?(/\s\(all parts\)/)
        ref = code.sub(/\s\(all parts\)/, "")
        return iev if ref.casecmp("IEV").zero?

        pubid = Pubid::Iec::Identifier.parse ref.upcase
        pubid.year = year.to_i if year

        ret = iecbib_get(pubid, opts)
        return nil if ret.nil?

        ret = ret.to_most_recent_reference unless pubid.year || opts[:keep_year]
        ret
      end

      private

      def iev(code = "IEC 60050")
        RelatonIsoBib::XMLParser.from_xml(<<~"XML")
          <bibitem>
            <fetched>#{Date.today}</fetched>
            <title format="text/plain" language="en" script="Latn">International Electrotechnical Vocabulary</title>
            <link type="src">http://www.electropedia.org</link>
            <docidentifier>#{code}:2011</docidentifier>
            <date type="published"><on>2011</on></date>
            <contributor>
              <role type="publisher"/>
              <organization>
                <name>International Electrotechnical Commission</name>
                <abbreviation>IEC</abbreviation>
                <uri>www.iec.ch</uri>
              </organization>
            </contributor>
            <language>en</language> <language>fr</language>
            <script>Latn</script>
            <status> <stage>60</stage> </status>
            <copyright>
              <from>2018</from>
              <owner>
                <organization>
                <name>International Electrotechnical Commission</name>
                <abbreviation>IEC</abbreviation>
                <uri>www.iec.ch</uri>
                </organization>
              </owner>
            </copyright>
          </bibitem>
        XML
      end

      # @param pubid [Pubid::Iec::Identifier]
      # @param opts [Hash]
      # @return [RelatonIec::IecBibliographicItem, nil]
      def iecbib_get(pubid, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        Util.info "Fetching from Relaton repsitory ...", key: pubid.to_s
        exclude = opts[:all_parts] ? %i[year part] : %i[year]
        result = search(pubid, exclude: exclude) || return

        if opts[:all_parts]
          ret = result.to_all_parts(pubid.year&.to_s)
          Util.info "Found: `#{ret&.docidentifier&.first&.id}`", key: pubid.to_s if ret
          return ret
        end

        ret = find_match(result, pubid)
        return ret if ret

        provide_tips(pubid, result)
        nil
      end

      # Find exact match considering year. If no year, return most recent.
      # @param result [RelatonIec::HitCollection]
      # @param pubid [Pubid::Iec::Identifier]
      # @return [RelatonIec::IecBibliographicItem, nil]
      def find_match(result, pubid)
        hit = if pubid.year
                result.detect { |h| h.hit[:pubid].year == pubid.year }
              else
                result.max_by { |h| h.hit[:pubid].year.to_i }
              end
        return unless hit

        ret = hit.fetch
        Util.info "Found: `#{ret.docidentifier.first.id}`", key: pubid.to_s
        ret
      end

      # Analyze why no match was found and give helpful tips.
      # @param pubid [Pubid::Iec::Identifier]
      # @param result [RelatonIec::HitCollection]
      def provide_tips(pubid, result) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        Util.info "Not found.", key: pubid.to_s

        # Year mismatch: hits exist but not for the requested year
        if pubid.year && result.any?
          years = result.map { |h| h.hit[:pubid].year&.to_s }.compact.uniq.sort
          Util.info "TIP: No match for edition year `#{pubid.year}`, " \
                    "but matches exist for `#{years.join('`, `')}`.", key: pubid.to_s
          return
        end

        # Search broadly (exclude year + part) to check for part/type mismatches
        broad = search(pubid, exclude: %i[year part])

        # Part mismatch: no part given but parts exist
        unless pubid.part
          if broad.any?
            parts = broad.map { |h| h.hit[:pubid].to_s }.uniq.sort
            Util.info "TIP: If you wish to cite all document parts for " \
                      "the reference, use `#{pubid} (all parts)`. " \
                      "Available: `#{parts.join('`, `')}`.", key: pubid.to_s
            return
          end
        end

        # Doctype mismatch: search excluding type to find entries with same number but different type
        type_broad = search(pubid, exclude: %i[year type])
        if type_broad.any?
          types = type_broad.map { |h| h.hit[:pubid].to_s }.uniq.sort
          Util.info "TIP: No match for type, but matches exist: " \
                    "`#{types.join('`, `')}`.", key: pubid.to_s
        end
      end
    end
  end
end
