module RelatonIec
  class DataParser
    #
    # Initialize new instance.
    #
    # @param [Hash] pub document data
    #
    def initialize(pub)
      @pub = pub
    end

    #
    # Parse document.
    #
    # @return [RelatonIec::IecBibliographicItem] bib item
    #
    def parse # rubocop:disable Metrics/AbcSize
      IecBibliographicItem.new(
        docid: docid,
        structuredidentifier: structuredidentifier, edition: @pub["edition"],
        language: language, script: scripts, title: title, doctype: doctype,
        docstatus: status, ics: ics, date: date, contributor: contributor,
        editorialgroup: editorialgroup, abstract: abstract,
        copyright: copyright, link: link, relation: relation,
        parce_code: @pub["priceInfo"]["priceCode"], place: ["Geneva"]
      )
    end

    #
    # Parse document identifiers.
    #
    # @return [Array<RelatonBib::DocumentIdentifier>] document identifiers
    #
    def docid
      ids = []
      ids << RelatonBib::DocumentIdentifier.new(id: @pub["reference"], type: "IEC", primary: true)
      ids << RelatonBib::DocumentIdentifier.new(id: @pub["urnAlt"][0], type: "URN")
    end

    #
    # Parse structured identifier.
    #
    # @return [RelatonIsoBib::StructuredIdentifier] structured identifier
    #
    def structuredidentifier
      m = @pub["reference"].match(
        /(?<=\s)(?<project>\w+)(?:-(?<part>\d*)(?:-(?<subpart>\d*))?)?/,
      )
      RelatonIsoBib::StructuredIdentifier.new(
        project_number: m[:project], part: m[:part], subpart: m[:subpart],
        type: "IEC", id: @pub["reference"]
      )
    end

    #
    # Parse languages.
    #
    # @return [Array<String>] languages
    #
    def language
      @pub["title"].map { |t| t["lang"] }.uniq
    end

    #
    # Parse scripts.
    #
    # @return [Array<String>] scripts
    #
    def scripts
      language.each_with_object([]) do |l, s|
        scr = script l
        s << scr if scr && !s.include?(scr)
      end
    end

    #
    # Detect script.
    #
    # @param [String] lang language
    #
    # @return [String] script
    #
    def script(lang)
      case lang
      when "en", "fr", "es" then "Latn"
      end
    end

    #
    # Parse titles.
    #
    # @return [Array<RelatonBib::TypedTitleString>] titles
    #
    def title
      @pub["title"].map do |t|
        RelatonBib::TypedTitleString.new(
          content: t["value"], language: t["lang"], script: script(t["lang"]), type: "main",
        )
      end
    end

    #
    # Parse editorial group.
    #
    # @return [Hash] editorial group
    #
    def editorialgroup
      return unless @pub["committee"]

      wg = @pub["committee"]["reference"]
      {
        technical_committee: [{
          name: wg,
          type: "technicalCommittee",
          number: wg.match(/\d+/)&.to_s&.to_i,
        }],
      }
    end

    #
    # Parse abstract.
    #
    # @return [Array<RelatonBib::FormattedString>] abstract
    #
    def abstract
      @pub["abstract"]&.map do |a|
        RelatonBib::FormattedString.new(
          content: a["content"], language: a["lang"], script: script(a["lang"]),
          format: a["format"]
        )
      end
    end

    # @return [Array<Hash>]
    def copyright # rubocop:disable Metrics/AbcSize
      from = @pub["reference"].match(/(?<=:)\d{4}/).to_s
      from = @pub["releaseDate"]&.match(/\d{4}/).to_s if from.empty?
      return [] if from.nil? || from.empty?

      abbreviation = @pub["reference"].match(/.*?(?=\s)/).to_s
      owner = abbreviation.split("/").map do |abbrev|
        name, url = Scrapper::ABBREVS[abbrev]
        { name: name, abbreviation: abbrev, url: url }
      end
      [{ owner: owner, from: from }]
    end

    #
    # Parse status.
    #
    # @return [RelatonBib::DocumentStatus] status
    #
    def status
      RelatonBib::DocumentStatus.new stage: @pub["status"]
    end

    #
    # Fetche ics.
    #
    # @return [Array<RelatonIsoBib::Ics>] ics
    #
    def ics
      return [] unless @pub["classifications"]

      @pub["classifications"].select { |c| c["type"] == "ICS" }.map do |c|
        RelatonIsoBib::Ics.new(c["value"])
      end
    end

    #
    # Parse dates.
    #
    # @return [Array<RelatonBib::BibliographicDate>] dates
    #
    def date
      date = []
      date << create_date("published", @pub["releaseDate"]) if @pub["releaseDate"]
      date << create_date("confirmed", @pub["confirmationDate"]) if @pub["confirmationDate"]
      date
    end

    def create_date(type, date)
      RelatonBib::BibliographicDate.new(type: type, on: date)
    end

    #
    # Parse contributors.
    #
    # @return [Array<Hash>] contributors
    #
    def contributor
      @pub["reference"].sub(/\s.*/, "").split("/").map do |abbrev|
        name, url = Scrapper::ABBREVS[abbrev]
        { entity: { name: name, url: url, abbreviation: abbrev },
          role: [type: "publisher"] }
      end
    end

    #
    # Parse links.
    #
    # @return [Array<RelatonBib::TypedUri>] links
    #
    def link
      url = "#{Scrapper::DOMAIN}/publication/#{urn_id}"
      l = [RelatonBib::TypedUri.new(content: url, type: "src")]
      return l unless @pub["releaseItems"]

      @pub["releaseItems"].each_with_object(l) do |r, a|
        next unless r["type"] == "PREVIEW"

        url = "#{Scrapper::DOMAIN}/preview/#{r['contentRef']['fileName']}"
        a << RelatonBib::TypedUri.new(content: url, type: "obp")
      end
    end

    #
    # Extract URN ID from URN.
    #
    # @return [String] URN ID
    #
    def urn_id
      @pub["urn"].split(":").last
    end

    #
    # Parse document type.
    #
    # @return [String] document type
    #
    def doctype
      case @pub["stdType"]
      when "IS" then "international-standard"
      when "TR" then "technical-report"
      when "TS" then "technical-specification"
      when "PAS" then "publicly-available-specification"
      when "SRD" then "system-reference-delivrabble"
      else @pub["stdType"].downcase
      end
    end

    #
    # Parse relation.
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def relation # rubocop:disable Metrics/MethodLength
      try = 0
      begin
        uri = URI "#{Scrapper::DOMAIN}/webstore/webstore.nsf/AjaxRequestXML?" \
                  "Openagent&url=#{urn_id}"
        resp = Net::HTTP.get_response uri
        doc = Nokogiri::XML resp.body
        create_relations doc
      rescue StandardError => e
        try += 1
        try < 3 ? retry : raise(e)
      end
    end

    #
    # Create relations.
    #
    # @param [Nokogiri::XML::Document] doc XML document
    #
    # @return [Array<Hash>] relations
    #
    def create_relations(doc) # rubocop:disable Metrics/MethodLength
      doc.xpath('//ROW[STATUS[.!="PREPARING" and .!="PUBLISHED"]]')
        .map do |r|
        r_type = r.at("STATUS").text.downcase
        type = case r_type
               when "revised", "replaced" then "updates"
               when "withdrawn" then "obsoletes"
               else r_type
               end
        ref = r.at("FULL_NAME").text
        fref = RelatonBib::FormattedRef.new content: ref, format: "text/plain"
        docid = RelatonBib::DocumentIdentifier.new(id: ref, type: "IEC", primary: true)
        bibitem = IecBibliographicItem.new(formattedref: fref, docid: [docid])
        RelatonBib::DocumentRelation.new type: type, bibitem: bibitem
      end
    end
  end
end
