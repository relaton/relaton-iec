# frozen_string_literal: true

# require 'isobib/iso_bibliographic_item'
require "relaton_iec/scrapper"
require "relaton_iec/hit_collection"
require "date"

module RelatonIec
  # Class methods for search ISO standards.
  class IecBibliography
    class << self
      # @param text [String]
      # @return [RelatonIec::HitCollection]
      def search(text, year = nil)
        HitCollection.new text, year
      rescue SocketError, OpenURI::HTTPError
        warn "Could not access http://www.iec.ch"
        []
      end

      # @param text [String]
      # @return [Array<IsoBibliographicItem>]
      # def search_and_fetch(text, year = nil)
      #   Scrapper.get(text, year)
      # end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts reference is required
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {})
        if year.nil?
          /^(?<code1>[^:]+):(?<year1>[^:]+)$/ =~ code
          unless code1.nil?
            code = code1
            year = year1
          end
        end

        return iev if code.casecmp("IEV").zero?

        code += "-1" if opts[:all_parts]
        ret = iecbib_get1(code, year, opts)
        return nil if ret.nil?

        ret.to_most_recent_reference unless year || opts[:keep_year]
        ret.to_all_parts if opts[:all_parts]
        ret
      end

      private

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "WARNING: no match found online for #{id}. "\
          "The code must be exactly like it is on the standards website."
        warn "(There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/ =~ code
          warn "The provided document part may not exist, or the document "\
            "may no longer be published in parts."
        else
          warn "If you wanted to cite all document parts for the reference, "\
            "use \"#{code} (all parts)\".\nIf the document is not a standard, "\
            "use its document type abbreviation (TS, TR, PAS, Guide)."
        end
        nil
      end

      def fetch_pages(s, n)
        workers = RelatonBib::WorkersPool.new n
        workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
        s.each_with_index { |hit, i| workers << { i: i, hit: hit } }
        workers.end
        workers.result.sort { |x, y| x[:i] <=> y[:i] }.map { |x| x[:hit] }
      end

      def isobib_search_filter(code)
        docidrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+}
        corrigrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+:[0-9]+/}
        warn "fetching #{code}..."
        result = search(code)
        result.select do |i|
          i.hit[:code] &&
            i.hit[:code].match(docidrx).to_s == code &&
            corrigrx !~ i.hit[:code]
        end
      end

      def iev(code = "IEC 60050")
        RelatonIsoBib::XMLParser.from_xml(<<~"END")
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
        END
      end

      # Sort through the results from Isobib, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def isobib_results_filter(result, year)
        missed_years = []
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, _i|
            return { ret: r } if !year

            r.dates.select { |d| d.type == "published" }.each do |d|
              return { ret: r } if year.to_i == d.on.year

              missed_years << d.on.year
            end
          end
        end
        { years: missed_years }
      end

      def iecbib_get1(code, year, _opts)
        return iev if code.casecmp("IEV").zero?

        result = isobib_search_filter(code) || return
        ret = isobib_results_filter(result, year)
        return ret[:ret] if ret[:ret]

        fetch_ref_err(code, year, ret[:years])
      end
    end
  end
end
