# frozen_string_literal: true

# Capybara.request_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new app, js_errors: false
# end
# Capybara.default_driver = :poltergeist

module RelatonIec
  # Scrapper.
  module Scrapper
    DOMAIN = "https://webstore.iec.ch"
    ABBREVS = {
      "ISO" => ["International Organization for Standardization", "www.iso.org"],
      "IEC" => ["International Electrotechnical Commission", "www.iec.ch"],
      "CISPR" => ["International special committee on radio interference", "www.iec.ch"],
    }.freeze

    TYPES = {
      "ISO" => "international-standard",
      "TS" => "technical-specification",
      "TR" => "technical-report",
      "PAS" => "publicly-available-specification",
      "AWI" => "appruved-work-item",
      "CD" => "committee-draft",
      "FDIS" => "final-draft-international-standard",
      "NP" => "new-proposal",
      "DIS" => "draft-international-standard",
      "WD" => "working-draft",
      "R" => "recommendation",
      "Guide" => "guide",
      "SRD" => "system-reference-delivrabble",
    }.freeze

    class << self
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # Parse page.
      # @param hit_data [Hash]
      # @return [Hash]
      def parse_page(hit_data)
        doc = get_page hit_data[:url]

        # Fetch edition.
        edition = doc.at(
          "//th[contains(., 'Edition')]/following-sibling::td/span",
        ).text

        status, relations = fetch_status_relations hit_data[:url]

        IecBibliographicItem.new(
          fetched: Date.today.to_s,
          docid: fetch_docid(hit_data),
          structuredidentifier: fetch_structuredidentifier(doc),
          edition: edition,
          language: ["en"],
          script: ["Latn"],
          title: fetch_titles(hit_data),
          doctype: fetch_type(doc),
          docstatus: status,
          ics: fetch_ics(doc),
          date: fetch_dates(doc),
          contributor: fetch_contributors(hit_data[:code]),
          editorialgroup: fetch_workgroup(doc),
          abstract: fetch_abstract(doc),
          copyright: fetch_copyright(hit_data[:code], doc),
          link: fetch_link(doc, hit_data[:url]),
          relation: relations,
          place: ["Geneva"],
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      # @param hit [Hash]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(hit)
        urn = RelatonIec.code_to_urn hit[:code], "en"
        [
          RelatonBib::DocumentIdentifier.new(id: hit[:code], type: "IEC", primary: true),
          RelatonBib::DocumentIdentifier.new(id: urn, type: "URN"),
        ]
      end

      # Fetch abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @return [Array<Array>]
      def fetch_abstract(doc)
        abstract_content = doc.at('//div[@itemprop="description"]').text
        [{
          content: abstract_content,
          language: "en",
          script: "Latn",
          format: "text/plain",
        }]
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(url)
        uri = URI url
        resp = Net::HTTP.get_response(uri)
        case resp.code
        when "301"
          path = resp["location"]
          url = DOMAIN + path
          uri = URI url
          resp = Net::HTTP.get_response(uri)
        when "404"
          raise RelatonBib::RequestError, "Page not found #{url}"
        end
        Nokogiri::HTML(resp.body)
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
             EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, OpenSSL::SSL::SSLError
        raise RelatonBib::RequestError, "Could not access #{url}"
      end
      # rubocop:enable Metrics/AbcSize

      # Fetch structuredidentifier.
      # @param doc [Nokogiri::HTML::Document]
      # @return [RelatonIsoBib::StructuredIdentifier]
      def fetch_structuredidentifier(doc)
        item_ref = doc.at("//span[@itemprop='productID']")
        unless item_ref
          return RelatonIsoBib::StructuredIdentifier.new(
            project_number: "?", part_number: "", prefix: nil, id: "?",
          )
        end

        m = item_ref.text.match(
          /(?<=\s)(?<project>\d+)-?(?<part>(?<=-)\d+|)-?(?<subpart>(?<=-)\d+|)/,
        )
        RelatonIsoBib::StructuredIdentifier.new(
          project_number: m[:project],
          part_number: m[:part],
          subpart_number: m[:subpart],
          prefix: nil,
          type: "IEC",
          id: item_ref.text,
        )
      end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc)
        wip = doc.at('//ROW[STATUS[.="PREPARING"]]')
        if wip
          statuses = YAML.load_file File.join __dir__, "statuses.yml"
          s = wip.at("STAGE").text
          return unless statuses[s]

          stage, substage = statuses[s]["stage"].split "."
        else
          stage    = "60"
          substage = "60"
        end
        RelatonBib::DocumentStatus.new(stage: stage, substage: substage)
      end

      # Fetch workgroup.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_workgroup(doc)
        wg = doc.at('//th/abbr[.="TC"]/../following-sibling::td/a').text
        {
          name: "International Electrotechnical Commission",
          abbreviation: "IEC",
          url: "webstore.iec.ch",
          technical_committee: [{
            name: wg,
            type: "technicalCommittee",
            number: wg.match(/\d+/)&.to_s&.to_i,
          }],
        }
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      # rubocop:disable Metrics/MethodLength
      def fetch_relations(doc)
        doc.xpath('//ROW[STATUS[.!="PREPARING"]][STATUS[.!="PUBLISHED"]]')
          .map do |r|
          r_type = r.at("STATUS").text.downcase
          type = case r_type
                 # when 'published' then 'obsoletes' # Valid
                 when "revised", "replaced" then "updates"
                 when "withdrawn" then "obsoletes"
                 else r_type
                 end
          fref = RelatonBib::FormattedRef.new(
            content: r.at("FULL_NAME").text, format: "text/plain",
          )
          bibitem = IecBibliographicItem.new(formattedref: fref)
          { type: type, bibitem: bibitem }
        end
      end

      def fetch_status_relations(url)
        pubid = url.match(/\d+$/).to_s
        uri = URI "#{DOMAIN}/webstore/webstore.nsf/AjaxRequestXML?"\
                  "Openagent&url=#{pubid}"
        resp = Net::HTTP.get_response uri
        doc = Nokogiri::XML resp.body
        status = fetch_status doc
        relations = fetch_relations doc
        [status, relations]
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch type.
      # @param doc [Nokogiri::HTML::Document]
      # @return [String]
      def fetch_type(doc)
        type = doc.at(
          '//th[contains(., "Publication type")]/following-sibling::td/span',
        ).text
        TYPES[type] || type.downcase.tr(" ", "-")
      end

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        RelatonBib::TypedTitleString.from_string hit_data[:title], "en", "Latn"
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_dates(doc)
        dates = []
        publish_date = doc.at("//span[@itemprop='releaseDate']").text
        unless publish_date.empty?
          dates << { type: "published", on: publish_date }
        end
        dates
      end

      # rubocop:disable Metrics/MethodLength

      def fetch_contributors(code)
        code.sub(/\s.*/, "").split("/").map do |abbrev|
          name, url = name_url abbrev
          { entity: { name: name, url: url, abbreviation: abbrev },
            role: [type: "publisher"] }
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch ICS.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_ics(doc)
        doc.xpath(
          '//th[contains(text(), "ICS")]/following-sibling::td/a',
        ).map do |i|
          code = i.text.match(/[\d.]+/).to_s.split "."
          { field: code[0], group: code[1], subgroup: code[2] }
        end
      end

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_link(doc, url)
        links = [{ type: "src", content: url }]
        obp_elms = doc.at_css("p.btn-preview a")
        links << { type: "obp", content: obp_elms[:href] } if obp_elms
        links
      end

      # rubocop:disable Metrics/MethodLength

      # Fetch copyright.
      # @param title [String]
      # @return [Array<Hash>]
      def fetch_copyright(code, doc)
        abbreviation = code.match(/.*?(?=\s)/).to_s
        name, url = name_url abbreviation
        from = code.match(/(?<=:)\d{4}/).to_s
        if from.empty?
          from = doc.xpath("//span[@itemprop='releaseDate']").text
            .match(/\d{4}/).to_s
        end
        [{
          owner: [{ name: name, abbreviation: abbreviation, url: url }],
          from: from,
        }]
      end
      # rubocop:enable Metrics/MethodLength

      def name_url(abbrev)
        ABBREVS[abbrev]
      end
    end
  end
end
