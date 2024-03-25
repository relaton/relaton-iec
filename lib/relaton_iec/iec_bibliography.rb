# frozen_string_literal: true

# require 'isobib/iso_bibliographic_item'
require "relaton_iec/hit_collection"
require "date"

module RelatonIec
  # Class methods for search ISO standards.
  class IecBibliography
    class << self
      ##
      # Search for standards entries.
      #
      # @param ref [String]
      # @param year [String, nil]
      # @return [RelatonIec::HitCollection]
      def search(ref, year = nil)
        # HitCollection.new text&.sub(/(^\w+)\//, '\1 '), year&.strip
        HitCollection.new ref, year&.strip
      rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError => e
        raise RelatonBib::RequestError, e.message
      end

      # @param code [String] the IEC standard code to look up (e..g "IEC 8000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      #   reference is required
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        opts[:all_parts] ||= code.match?(/\s\(all parts\)/)
        ref = code.sub(/\s\(all parts\)/, "")
        year ||= ref_parts(ref)[:year]
        return iev if ref.casecmp("IEV").zero?

        ret = iecbib_get(ref, year, opts)
        return nil if ret.nil?

        ret = ret.to_most_recent_reference unless year || opts[:keep_year]
        ret
      end

      private

      # @param pubid [String]
      # @param year [String]
      # @param missed_years [Array<String>]
      def warn_missing_years(pubid, year, missed_years)
        id = ref_with_year(pubid, year)
        Util.info "TIP: No match for edition year `#{year}`, " \
                  "but matches exist for `#{missed_years.uniq.join('`, `')}`.", key: id
      end

      # @param code [String]
      # @param year [String]
      # @param missed_years [Array<String>]
      def fetch_ref_err(code, year, missed_years) # rubocop:disable Metrics/MethodLength
        id = ref_with_year(code, year)

        Util.info "Not found.", key: id

        if year && missed_years.any?
          warn_missing_years(code, year, missed_years)
        end

        # TODO: change this to pubid-iec
        has_part = /\d-\d/.match?(code)
        if has_part
          Util.info "TIP: If it cannot be found, the document may no longer be published in parts.", key: id

        else
          Util.info "TIP: If you wish to cite all document parts for " \
                    "the reference, use `#{code} (all parts)`.", key: id
        end

        # TODO: streamline after integration with pubid-iec
        doctypes = %w(TS TR PAS SRD TEC STTR WP Guide OD CS CA)
        selected_doctype = doctypes.select do |t|
          code.include?("#{t} ")
        end
        unless selected_doctype
          Util.info "TIP: If the document is not an International Standard, use its " \
                    "deliverable type abbreviation `#{doctypes.join('`, `')}`.", key: id
        end
      end

      # @param ref [String]
      # @param year [String]
      # @return [String]
      def ref_with_year(ref, year)
        year && !ref.match?(/:\d{4}/) ? [ref, year].join(":") : ref
      end

      # @param ref [String]
      # @param year [String, nil]
      # @return [RelatonIec::HitCollection]
      # def search_filter(ref, year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      #   rp1 = ref_parts ref.upcase
      #   year ||= rp1[:year]
      #   corr = rp1[:corr]&.sub " ", ""
      #   warn "[relaton-iec] (\"#{ref_with_year(ref, year)}\") Fetching from IEC..."
      #   result = search(rp1[:code], year)
      #   code = result.text.dup
      #   if result.empty? && /(?<=\d-)(?<part>[\w-]+)/ =~ rp1[:code]
      #     # try to search packaged standard
      #     result = search rp1[:code], year, part
      #     pkg_std = result.any?
      #   end
      #   result = search rp1[:code] if result.empty?
      #   if pkg_std
      #     code.sub!(/(?<=\d-)#{part}/, part[0])
      #   else
      #     code.sub!(/-[-\d]+/, "")
      #   end
      #   result.select do |i|
      #     rp2 = ref_parts i.hit[:code]
      #     code2 = if pkg_std
      #               rp2[:code].sub(/(?<=\d-\d)\d+/, "")
      #             else
      #               rp2[:code].sub(/-[-\d]+/, "")
      #             end
      #     code == code2 && rp1[:bundle] == rp2[:bundle] && corr == rp2[:corr]
      #   end
      # @return [RelatonIec::HitCollection]
      def search_filter(ref, year)
        code = ref.split(":").first
        Util.info "Fetching from Relaton repsitory ...", key: ref_with_year(ref, year)
        search(code)
      end

      def ref_parts(ref)
        %r{
          ^(?<code>[^\d]+(?:\d+(?:-\w+)*)?(?:\s?[A-Z]+)?(?:\sSUP)?)
          (?::(?<year>\d{4}))?
          (?<bundle>\+[^\s/]+)?
          (?:/(?<corr>AMD\s?\d+))?
        }x.match ref
      end

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

      # Look for a code in the search results
      # and return the first result that matches the code,
      # matches the year (if provided), and which a part
      # has a title (amendments do not).
      # If no match, returns any years which caused mismatch, for error reporting
      def results_filter(result, ref, year, opts)
        r_code, r_year, r_amd, r_consv = code_year ref
        r_year ||= year
        if opts[:all_parts]
          ret = result.to_all_parts(r_year)
        else
          ret, missed_parts = match_result(result, r_code, r_year, r_amd, r_consv)
        end
        { ret: ret, years: missed_years(result, r_year), missed_parts: missed_parts }
      end

      def missed_years(result, year)
        result.map { |h| codes_years(h.hit[:code])[1] }.flatten.uniq.reject { |y| y == year }
      end

      #
      # Find a match in the search results
      #
      # @param [RelatonIec::HitCollection] result search results
      # @param [String] code code of the document
      # @param [String] year year of the document
      # @param [String] amd amendment of the document
      # @param [String] consv consolidated version of the document
      #
      # @return [Array<RelatonIec::IecBibliographicItem, Array, nil>] result, missed parts
      #
      def match_result(result, code, year, amd, consv) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        missed_parts = false
        res = result.select do |h|
          h_codes, h_years, h_amds, h_consv = codes_years h.hit[:code]
          match_code = h_codes.include? code
          match_year = h_years.include?(year)
          missed_parts ||= !match_code
          match_code && (!year || match_year) && match_amd(amd, h_amds) && h_consv.first == consv
        end
        hit = year ? res.first : res.max_by { |h| code_year(h.hit[:code])[1].to_i }
        ret = hit&.fetch
        [ret, missed_parts]
      end

      def match_amd(amd, h_amds)
        # (!amd && h_amds.empty?) || h_amds.include?(amd)
        h_amds.first == amd
      end

      # @param ref [String]
      # @return [Array<Stringl, nil>] code, year, amd
      def code_year(ref)
        %r{
          # ^(?<code>\S+[^\d]*\s\d+(?:-\w+)*)
          ^(?<code>\S+\s[^:/]+)
          (?::(?<year>\d{4}))?
          (?:/(?<amd>\w+)(?::\d{4})?)?
          (?:\+(?<consv>\w+)(?::\d{4})?)?
        }x =~ ref
        [code, year, amd&.upcase, consv&.upcase]
      end

      # @param ref [String]
      # @return [Array<Array<Stringl>>] codes, years, amds
      def codes_years(refs)
        RelatonBib.array(refs).map do |r|
          code_year r
        end.transpose.map { |a| a.compact.uniq }
      end

      # @param ref [String]
      # @param year [String, nil]
      # @param opts [Hash]
      # @return [RelatonIec::IecBibliographicItem, nil]
      def iecbib_get(code, year, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        result = search_filter(code, year) || return
        ret = results_filter(result, code, year, opts)

        return fetch_ref_err(code, year, ret[:years]) unless ret[:ret]

        id = ref_with_year(code, year)
        docid = ret[:ret].docidentifier.first.id

        # if id == docid then Util.warn "(#{id}) Found exact match."
        # else
        Util.info "Found: `#{docid}`", key: id
        # end

        if ret[:missed_parts]
          Util.info "TIP: `#{code}` also contains other parts, " \
                    "if you want to cite all parts, use `#{code} (all parts)`.", key: id
        end

        ret[:ret]
      end
    end
  end
end
