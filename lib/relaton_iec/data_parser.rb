module RelatonIec
  class DataParser
    DOMAIN = "https://webstore.iec.ch"

    ATTRS = %i[
      docid structuredidentifier language script title doctype
      ics date contributor editorialgroup abstract copyright link relation
    ].freeze

    ABBREVS = {
      "ISO" => ["International Organization for Standardization", "www.iso.org"],
      "IEC" => ["International Electrotechnical Commission", "www.iec.ch"],
      "IEEE" => ["Institute of Electrical and Electronics Engineers", "www.ieee.org"],
      "ASTM" => ["American Society of Testing Materials", "www.astm.org"],
      "CISPR" => ["International special committee on radio interference", "www.iec.ch"],
    }.freeze

    DOCTYPES = {
      "IS" => "international-standard",
      "TR" => "technical-report",
      "TS" => "technical-specification",
      "PAS" => "publicly-available-specification",
      "SRD" => "system-reference-deliverable",
    }

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
      args = ATTRS.each_with_object({}) { |a, h| h[a] = send a }
      args[:docstatus] = RelatonBib::DocumentStatus.new stage: @pub["status"]
      args[:edition] = @pub["edition"]
      args[:price_code] = @pub["priceInfo"]["priceCode"]
      args[:place] = ["Geneva"]
      IecBibliographicItem.new(**args)
    end

    #
    # Parse document identifiers.
    #
    # @return [Array<RelatonBib::DocumentIdentifier>] document identifiers
    #
    def docid
      ids = []
      ids << RelatonBib::DocumentIdentifier.new(id: @pub["reference"], type: "IEC", primary: true)
      urnid = "urn:#{@pub['urnAlt'][0]}"
      ids << RelatonBib::DocumentIdentifier.new(id: urnid, type: "URN")
    end

    #
    # Parse structured identifier.
    #
    # @return [RelatonIsoBib::StructuredIdentifier] structured identifier
    #
    def structuredidentifier
      m = @pub["reference"].match(
        /(?<=\s)(?<project>\w+)(?:-(?<part>\w*)(?:-(?<subpart>\w*))?)?/,
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
    def script
      language.each_with_object([]) do |l, s|
        scr = lang_to_script l
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
    def lang_to_script(lang)
      case lang
      when "en", "fr", "es" then "Latn"
      end
    end

    #
    # Parse titles.
    #
    # @return [RelatonBib::TypedTitleStringCollection] titles
    #
    def title
      @pub["title"].reduce(RelatonBib::TypedTitleStringCollection.new) do |a, t|
        a + RelatonBib::TypedTitleString.from_string(
          t["value"], t["lang"], lang_to_script(t["lang"])
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
          content: a["content"], language: a["lang"], script: lang_to_script(a["lang"]),
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
        name, url = ABBREVS[abbrev]
        { name: name, abbreviation: abbrev, url: url }
      end
      [{ owner: owner, from: from }]
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
      {
        "published" => "publicationDate",
        "stable-until" => "stabilityDate",
        "confirmed" => "confirmationDate",
        "obsoleted" => "dateOfWithdrawal",
      }.reduce([]) do |a, (k, v)|
        next a unless @pub[v]

        a << RelatonBib::BibliographicDate.new(type: k, on: @pub[v])
      end
    end

    #
    # Parse contributors.
    #
    # @return [Array<Hash>] contributors
    #
    def contributor
      @pub["reference"].sub(/\s.*/, "").split("/").map do |abbrev|
        name, url = ABBREVS[abbrev]
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
      url = "#{DOMAIN}/publication/#{urn_id}"
      l = [RelatonBib::TypedUri.new(content: url, type: "src")]
      RelatonBib.array(@pub["releaseItems"]).each_with_object(l) do |r, a|
        next unless r["type"] == "PREVIEW"

        url = "#{DOMAIN}/preview/#{r['contentRef']['fileName']}"
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
      type = DOCTYPES[@pub["stdType"]] || @pub["stdType"].downcase
      DocumentType.new type: type
    end

    #
    # Parse relation.
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def relation # rubocop:disable Metrics/MethodLength
      try = 0
      begin
        uri = URI "#{DOMAIN}/webstore/webstore.nsf/AjaxRequestXML?" \
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
