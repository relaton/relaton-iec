module Relaton
  module Iec
    class DataParser
      include Core::ArrayWrapper

      DOMAIN = "https://webstore.iec.ch"

      ATTRS = %i[
        type docidentifier language script title date contributor
        status edition abstract copyright source relation place ext
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
      }.freeze

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
      def parse
        args = ATTRS.each_with_object({}) { |a, h| h[a] = send a }
        ItemData.new(**args)
      end

      private

      def type = "standard"

      #
      # Parse document identifiers.
      #
      # @return [Array<Relaton::Bib::Docidentifier>] document identifiers
      #
      def docidentifier
        ids = []
        ids << Docidentifier.new(content: @pub["reference"], type: "IEC", primary: true)
        urnid = "urn:#{@pub['urnAlt'][0]}"
        ids << Docidentifier.new(content: urnid, type: "URN")
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
      # @return [Array<Relaton::Bib::Title>] titles
      #
      def title
        @pub["title"].reduce([]) do |acc, t|
          acc + Bib::Title.from_string(t["value"], t["lang"], lang_to_script(t["lang"]))
        end
      end

      def status
        stage = Bib::Status::Stage.new content: @pub["status"]
        Bib::Status.new stage: stage
      end

      def edition
        Bib::Edition.new content: @pub["edition"]
      end

      #
      # Parse abstract.
      #
      # @return [Array<Relaton::Bib::LocalizedMarkedUpString>] abstract
      #
      def abstract
        @pub["abstract"]&.map do |a|
          Bib::LocalizedMarkedUpString.new(
            content: a["content"], language: a["lang"], script: lang_to_script(a["lang"]),
          )
        end
      end

      # @return [Array<Relaton::Bib::Copyright>] copyright
      def copyright # rubocop:disable Metrics/AbcSize
        from = @pub["reference"].match(/(?<=:)\d{4}/).to_s
        from = @pub["releaseDate"]&.match(/\d{4}/).to_s if from.empty?
        return [] if from.nil? || from.empty?

        abbreviation = @pub["reference"].match(/.*?(?=\s)/).to_s
        owner = abbreviation.split("/").map do |abbrev|
          name, url = ABBREVS[abbrev]
          orgname = Bib::TypedLocalizedString.new(content: name, language: "en", script: "Latn")
          abbrev = Bib::LocalizedString.new(content: abbrev, language: "en", script: "Latn")
          uri = Bib::Uri.new(content: url, type: "org")
          org = Bib::Organization.new(name: [orgname], abbreviation: abbrev, uri: [uri])
          Bib::ContributionInfo.new(organization: org)
        end
        [Bib::Copyright.new(owner: owner, from: from)]
      end

      #
      # Parse dates.
      #
      # @return [Array<Relaton::Bib::Date>] dates
      #
      def date
        {
          "published" => "publicationDate",
          "stable-until" => "stabilityDate",
          "confirmed" => "confirmationDate",
          "obsoleted" => "dateOfWithdrawal",
        }.reduce([]) do |a, (k, v)|
          next a unless @pub[v]

          a << Bib::Date.new(type: k, at: @pub[v])
        end
      end

      #
      # Parse contributors.
      #
      # @return [Array<Bib::Contributor>] contributors
      #
      def contributor
        contribs = @pub["reference"].sub(/\s.*/, "").split("/").map do |abbrev|
          name, url = ABBREVS[abbrev]
          orgname = Bib::TypedLocalizedString.new(content: name, language: "en", script: "Latn")
          abbr = Bib::LocalizedString.new(content: abbrev, language: "en", script: "Latn")
          uri = Bib::Uri.new(content: url, type: "org")
          org = Bib::Organization.new(name: [orgname], uri: [uri], abbreviation: abbr)
          role = Bib::Contributor::Role.new(type: "publisher")
          Bib::Contributor.new(organization: org, role: [role])
        end
        contribs + editorialgroup_contributors
      end

      #
      # Create contributors from editorial group (committee).
      #
      # @return [Array<Bib::Contributor>] editorial group contributors
      #
      def editorialgroup_contributors
        return [] unless @pub["committee"]

        wg = @pub["committee"]["reference"]
        number = wg.match(/\d+/)&.to_s
        orgname = Bib::TypedLocalizedString.new(content: "International Electrotechnical Commission",
                                                language: "en", script: "Latn")
        abbr = Bib::LocalizedString.new(content: "IEC", language: "en", script: "Latn")
        tcname = Bib::TypedLocalizedString.new(content: wg, language: "en", script: "Latn")
        identifiers = array(number).map { |n| Bib::OrganizationType::Identifier.new(content: n) }
        subdivision = Bib::Subdivision.new(
          type: "technical-committee",
          name: [tcname],
          identifier: identifiers,
        )
        org = Bib::Organization.new(name: [orgname], abbreviation: abbr, subdivision: [subdivision])
        desc = Bib::LocalizedMarkedUpString.new(content: "committee")
        role = Bib::Contributor::Role.new(type: "author", description: [desc])
        [Bib::Contributor.new(organization: org, role: [role])]
      end

      #
      # Parse links.
      #
      # @return [Array<Relaton::Bib::Uri>] links
      #
      def source
        url = "#{DOMAIN}/publication/#{urn_id}"
        l = [Bib::Uri.new(content: url, type: "src")]
        array(@pub["releaseItems"]).each_with_object(l) do |r, a|
          next unless r["type"] == "PREVIEW"

          url = "#{DOMAIN}/preview/#{r['contentRef']['fileName']}"
          a << Bib::Uri.new(content: url, type: "obp")
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
      # Parse relation.
      #
      # @return [Array<Relaton::Bib::Relation>] relation
      #
      def relation # rubocop:disable Metrics/MethodLength
        try = 0
        begin
          uri = URI "#{DOMAIN}/webstore/webstore.nsf/AjaxRequestXML?Openagent&url=#{urn_id}"
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
      # @return [Array<Relaton::Bib::Relation>] relations
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
          docid = Docidentifier.new(content: ref, type: "IEC", primary: true)
          bibitem = ItemData.new(formattedref: ref, docidentifier: [docid])
          Relation.new type: type, bibitem: bibitem
        end
      end

      def place
        [Bib::Place.new(city: "Geneva")]
      end

      def ext
        Ext.new(
          doctype: doctype,
          structuredidentifier: structuredidentifier,
          flavor: "iec",
          ics: ics,
          price_code: @pub["priceInfo"]["priceCode"],
        )
      end

      #
      # Parse structured identifier.
      #
      # @return [Relaton::Iso::StructuredIdentifier] structured identifier
      #
      def structuredidentifier
        urn = @pub.dig("project", "urn")
        return unless urn

        pnum = Iso::ProjectNumber.new(content: urn.split(":").last)
        Iso::StructuredIdentifier.new(project_number: pnum, type: "IEC")
      end

      #
      # Parse document type.
      #
      # @return [Relaton::Iec::Doctype] document type
      #
      def doctype
        type = DOCTYPES[@pub["stdType"]] || @pub["stdType"].downcase
        Doctype.new content: type
      end

      #
      # Fetche ics.
      #
      # @return [Array<Relaton::Bib::ICS>] ics
      #
      def ics
        return [] unless @pub["classifications"]

        @pub["classifications"].select { |c| c["type"] == "ICS" }.map do |c|
          Bib::ICS.new(code: c["value"])
        end
      end
    end
  end
end
