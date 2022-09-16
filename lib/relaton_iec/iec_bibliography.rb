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
      # @param part [String, nil] search for packaged stndard if not nil
      # @return [RelatonIec::HitCollection]
      def search(text, year = nil, part = nil)
        HitCollection.new text&.sub(/(^\w+)\//, '\1 '), year&.strip, part
      rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError
        raise RelatonBib::RequestError, "Could not access http://www.iec.ch"
      end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      #   reference is required
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        opts[:all_parts] ||= code.match?(/\s\(all parts\)/)
        ref = code.sub(/\s\(all parts\)/, "")
        if year.nil?
          /^(?<code1>[^:]+):(?<year1>[^:]+)/ =~ ref
          unless code1.nil?
            ref = code1
            year = year1
          end
        end
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
        warn "[relaton-iec] (\"#{id}\") TIP: " \
          "No match for edition year #{year}, " \
          "but matches exist for #{missed_years.uniq.join(', ')}."
      end

      # @param code [String]
      # @param year [String]
      # @param missed_years [Array<String>]
      def fetch_ref_err(code, year, missed_years) # rubocop:disable Metrics/MethodLength
        id = ref_with_year(code, year)

        warn "[relaton-iec] (\"#{id}\") " \
             "Not found. "\
             "The identifier must be exactly as shown on the IEC Webstore."

        if year && missed_years.any?
          warn_missing_years(code, year, missed_years)
        end

        # TODO: change this to pubid-iec
        has_part = /\d-\d/.match?(code)
        if has_part
          warn "[relaton-iec] (\"#{id}\") TIP: " \
               "If it cannot be found, the document may no longer be published in parts."

        else
          warn "[relaton-iec] (\"#{id}\") TIP: " \
               "If you wish to cite all document parts for the reference, " \
               "use (\"#{code} (all parts)\")."
        end

        # TODO: streamline after integration with pubid-iec
        doctypes = %w(TS TR PAS SRD TEC STTR WP Guide OD CS CA)
        selected_doctype = doctypes.select do |t|
          code.include?("#{t} ")
        end
        unless selected_doctype
          warn "[relaton-iec] (\"#{id}\") TIP: " \
              "If the document is not an International Standard, use its " \
              "deliverable type abbreviation (#{doctypes.join(", ")})."
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
      # @param year [String]
      # @return [String]
      def ref_with_year(ref, year)
        year ? [ref, year].join(":") : ref
      end

      # @param ref [String]
      # @param year [String, nil]
      # @return [RelatonIec::HitCollection]
      def search_filter(ref, year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        rp1 = ref_parts ref.upcase
        year ||= rp1[:year]
        corr = rp1[:corr]&.sub " ", ""
        warn "[relaton-iec] (\"#{ref_with_year(ref, year)}\") Fetching from IEC..."
        result = search(rp1[:code], year)
        code = result.text.dup
        if result.empty? && /(?<=\d-)(?<part>[\w-]+)/ =~ rp1[:code]
          # try to search packaged standard
          result = search rp1[:code], year, part
          pkg_std = result.any?
        end
        result = search rp1[:code] if result.empty?
        if pkg_std
          code.sub!(/(?<=\d-)#{part}/, part[0])
        else
          code.sub!(/-[-\d]+/, "")
        end
        result.select do |i|
          rp2 = ref_parts i.hit[:code]
          code2 = if pkg_std
                    rp2[:code].sub(/(?<=\d-\d)\d+/, "")
                  else
                    rp2[:code].sub(/-[-\d]+/, "")
                  end
          code == code2 && rp1[:bundle] == rp2[:bundle] && corr == rp2[:corr]
        end
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
        r_code, r_year = code_year result.text, result.part
        r_year ||= year
        missed_years = []
        missed_parts = false
        # result.each_slice(3) do |s| # ISO website only allows 3 connections
        ret = if opts[:all_parts]
                result.to_all_parts
              else
                result.detect do |h|
                  h_code, h_year = code_year h.hit[:code], result.part
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
      # @param part [String, nil]
      # @return [Array<String, nil>]
      def code_year(ref, part)
        %r{
          ^(?<code>\S+[^\d]*\s\d+(?:-\w+)*)
          (?::(?<year>\d{4}))?
        }x =~ ref
        code.sub!(/-\d+/, "") if part
        [code, year]
      end

      # @param code [String]
      # @param year [String, nil]
      # @param opts [Hash]
      # @return [RelatonIec::IecBibliographicItem, nil]
      def iecbib_get(code, year, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        result = search_filter(code, year) || return
        ret = results_filter(result, year, opts)

        return fetch_ref_err(code, year, ret[:years]) unless ret[:ret]

        id = ref_with_year(code, year)
        docid = ret[:ret].docidentifier.first.id

        if id == docid
          warn "[relaton-iec] (\"#{id}\") Found exact match."
        else
          warn "[relaton-iec] (\"#{id}\") Found (\"#{docid}\")."
        end

        if ret[:missed_parts]
          warn "[relaton-iec] (\"#{id}\") TIP: " \
          "\"#{code}\" also contains other parts, " \
          "if you want to cite all parts, use "\
          "(\"#{code} (all parts)\")."
        end

        ret[:ret]
      end
    end
  end
end
