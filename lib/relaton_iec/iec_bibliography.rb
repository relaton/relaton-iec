# frozen_string_literal: true

# require 'isobib/iso_bibliographic_item'
require "relaton_iec/scrapper"
require "relaton_iec/hit_collection"
require "date"

module RelatonIec
  # Class methods for search ISO standards.
  class IecBibliography
    class << self
      ##
      # Search for standards entries. To seach packaged document it needs to
      # pass part parametr.
      #
      # @example Search for packaged standard
      #   RelatonIec::IecBibliography.search 'IEC 60050-311', nil, '311'
      #
      # @param text [String]
      # @param year [String, nil]
      # @return [RelatonIec::HitCollection]
      def search(text, year = nil)
        HitCollection.new text&.sub(/(^\w+)\//, '\1 '), year&.strip
      rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError => e
        raise RelatonBib::RequestError, e.message
      end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      #   reference is required
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        opts[:all_parts] ||= code.match?(/\s\(all parts\)/)
        ref = code.sub(/\s\(all parts\)/, "")
        # if year.nil?
        #   /^(?<code1>[^:]+):(?<year1>[^:]+)/ =~ ref
        #   unless code1.nil?
        #     ref = code1
        #     year = year1
        #   end
        # end
        year ||= ref_parts(ref)[:year]
        return iev if ref.casecmp("IEV").zero?

        ret = iecbib_get(ref, year, opts)
        return nil if ret.nil?

        ret = ret.to_most_recent_reference unless year || opts[:keep_year]
        ret
      end

      private

      # @param code [String]
      # @param year [String]
      # @param missed_years [Array<String>]
      def fetch_ref_err(code, year, missed_years) # rubocop:disable Metrics/MethodLength
        id = year ? "#{code}:#{year}" : code
        warn "[relaton-iec] WARNING: no match found online for #{id}. "\
             "The code must be exactly like it is on the standards website."
        unless missed_years.empty?
          warn "[relaton-iec] (There was no match for #{year}, though there "\
               "were matches found for #{missed_years.join(', ')}.)"
        end
        if /\d-\d/.match? code
          warn "[relaton-iec] The provided document part may not exist, or "\
               "the document may no longer be published in parts."
        else
          warn "[relaton-iec] If you wanted to cite all document parts for "\
               "the reference, use \"#{code} (all parts)\".\nIf the document "\
               "is not a standard, use its document type abbreviation (TS, "\
               "TR, PAS, Guide)."
        end
        nil
      end

      # @param hits [Array<RelatonIec::Hit>]
      # @param threads [Integer]
      # @return [Array<RelatonIec::Hit>]
      # def fetch_pages(hits, threads)
      #   workers = RelatonBib::WorkersPool.new threads
      #   workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
      #   hits.each_with_index { |hit, i| workers << { i: i, hit: hit } }
      #   workers.end
      #   workers.result.sort_by { |a| a[:i] }.map { |x| x[:hit] }
      # end

      # @param ref [String]
      # @return [RelatonIec::HitCollection]
      def search_filter(ref, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        code = opts[:all_parts] ? ref.split(":").first : ref
        # rp1 = ref_parts code.upcase
        # year ||= rp1[:year]
        warn "[relaton-iec] (\"#{ref}\") fetching..."
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

      # Sort through the results from Isobib, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which
      # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error
      # reporting
      def results_filter(result, year, opts) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        r_code, r_year = code_year result.text
        r_year ||= year
        missed_years = []
        missed_parts = false
        # result.each_slice(3) do |s| # ISO website only allows 3 connections
        ret = if opts[:all_parts]
                result.to_all_parts(r_year)
              else
                result.detect do |h|
                  h_code, h_year = code_year h.hit[:code]
                  missed_parts ||= !opts[:all_parts] && r_code != h_code
                  missed_years << h_year unless !r_year || h_year == r_year
                  r_code == h_code && (!year || h_year == r_year)
                  # fetch_pages(s, 3).each_with_index do |r, _i|
                  # return { ret: r } if !year

                  # r.date.select { |d| d.type == "published" }.each do |d|
                  # return { ret: r } if year.to_i == d.on(:year)

                  # missed_years << d.on(:year)
                  # end
                  # end
                end&.fetch
              end
        { ret: ret, years: missed_years, missed_parts: missed_parts }
      end

      # @param ref [String]
      # @return [Array<String, nil>]
      def code_year(ref)
        %r{
          ^(?<code>\S+[^\d]*\s\d+(?:-\w+)*)
          (?::(?<year>\d{4}))?
        }x =~ ref
        # code.sub!(/-\d+/, "") if part
        [code, year]
      end

      # @param ref [String]
      # @param year [String, nil]
      # @param opts [Hash]
      # @return [RelatonIec::IecBibliographicItem, nil]
      def iecbib_get(ref, year, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        result = search_filter(ref, opts) || return
        ret = results_filter(result, year, opts)
        if ret[:ret]
          if ret[:missed_parts]
            warn "[relaton-iec] WARNING: #{ref} found as #{ret[:ret].docidentifier.first.id} "\
                 "but also contain parts. If you wanted to cite all document parts for the reference, use "\
                 "\"#{ref} (all parts)\""
          else
            warn "[relaton-iec] (\"#{ref}\") found #{ret[:ret].docidentifier.first.id}"
          end
          ret[:ret]
        else
          fetch_ref_err(ref, year, ret[:years])
        end
      end
    end
  end
end
