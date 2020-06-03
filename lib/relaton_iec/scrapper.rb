# frozen_string_literal: true

require "relaton_iso_bib"
require "relaton_iec/hit"
require "nokogiri"
require "net/http"

# Capybara.request_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new app, js_errors: false
# end
# Capybara.default_driver = :poltergeist

module RelatonIec
  # Scrapper.
  # rubocop:disable Metrics/ModuleLength
  module Scrapper
    DOMAIN = "https://webstore.iec.ch"

    TYPES = {
      "ISO" => "international-standard",
      "TS" => "technicalSpecification",
      "TR" => "technicalReport",
      "PAS" => "publiclyAvailableSpecification",
      "AWI" => "appruvedWorkItem",
      "CD" => "committeeDraft",
      "FDIS" => "finalDraftInternationalStandard",
      "NP" => "newProposal",
      "DIS" => "draftInternationalStandard",
      "WD" => "workingDraft",
      "R" => "recommendation",
      "Guide" => "guide",
    }.freeze

    class << self
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # Parse page.
      # @param hit [Hash]
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
          docid: [RelatonBib::DocumentIdentifier.new(id: hit_data[:code], type: "IEC")],
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
          statuses = YAML.load_file "lib/relaton_iec/statuses.yml"
          s = wip.at("STAGE").text
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
        doc.xpath('//ROW[STATUS[.!="PREPARING"]][STATUS[.!="PUBLISHED"]]').
          map do |r|
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
        uri = URI DOMAIN + "/webstore/webstore.nsf/AjaxRequestXML?"\
        "Openagent&url=http://www.iec.ch/dyn/www/f?"\
        "p=103:390:::::P390_PUBLICATION_ID:" + pubid
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
        doc.at(
          '//th[contains(., "Publication type")]/following-sibling::td/span',
        ).text.downcase.tr " ", "-"
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        titles = hit_data[:title].split " - "
        case titles.size
        when 0
          intro, main, part = nil, "", nil
        when 1
          intro, main, part = nil, titles[0], nil
        when 2
          if /^(Part|Partie) \d+:/ =~ titles[1]
            intro, main, part = nil, titles[0], titles[1]
          else
            intro, main, part = titles[0], titles[1], nil
          end
        when 3
          if /^(Part|Partie) \d+:/ =~ titles[1]
            intro, main, part = nil, titles[0], titles[1..2].join(" - ")
          else
            intro, main, part = titles[0], titles[1], titles[2]
          end
        else
          intro, main, part = titles[0], titles[1], titles[2..-1]&.join(" -- ")
        end
        [{
          title_intro: intro,
          title_main: main,
          title_part: part,
          language: "en",
          script: "Latn",
        }]
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

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
          case abbrev
          when "ISO"
            name = "International Organization for Standardization"
            url = "www.iso.org"
          when "IEC"
            name = "International Electrotechnical Commission"
            url  = "www.iec.ch"
          end
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
          code = i.text.match(/[\d\.]+/).to_s.split "."
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
        case abbreviation
        when "IEC"
          name = "International Electrotechnical Commission"
          url = "www.iec.ch"
        end
        from = code.match(/(?<=:)\d{4}/).to_s
        if from.empty?
          from = doc.xpath("//span[@itemprop='releaseDate']").text.
            match(/\d{4}/).to_s
        end
        [{
          owner: [{ name: name, abbreviation: abbreviation, url: url }],
          from: from,
        }]
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
