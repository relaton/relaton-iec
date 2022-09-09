# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    def_delegators :@array, :detect

    attr_reader :part

    DOMAIN = "https://webstore.iec.ch"
    GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-iec/main/"

    # @param ref [String]
    # @param year [String, nil]
    # @param part [String, nil]
    def initialize(ref, year = nil, part = nil)
      super ref, year
      @part = part
      @array = ref ? hits(ref, year) : []
    end

    # @return [RelatonIec::IecBibliographicItem]
    def to_all_parts # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
      parts = @array.reject { |h| h.part.nil? }
      hit = parts.min_by &:part
      return @array.first&.fetch unless hit

      bibitem = hit.fetch
      all_parts_item = bibitem.to_all_parts
      parts.reject { |h| h.hit[:code] == hit.hit[:code] }.each do |hi|
        isobib = RelatonIec::IecBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: hi.hit[:code]),
          docid: [RelatonBib::DocumentIdentifier.new(id: hi.hit[:code], type: "IEC", primary: true)],
        )
        all_parts_item.relation << RelatonBib::DocumentRelation.new(type: "partOf", bibitem: isobib)
      end
      all_parts_item
    end

    private

    # @param ref [String]
    # @param year [String, nil]
    # @return [Array<RelatonIec::Hit>]
    def hits(ref, year) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      if /61360-4\sDB|ISO[\s\/]IEC\sDIR/.match?(ref)
        fetch_from_gh ref
      else
        from, to = nil
        if year
          from = Date.strptime year, "%Y"
          to   = from.next_year.prev_day
        end
        get_results ref, from, to
      end
      # file = "../data/#{ref.sub(/^IEC\s/, '').gsub(/[\s\/]/, '_').upcase}.yaml"
      # path = File.expand_path file, __dir__
      # if File.exist? path
      #   hash = YAML.safe_load File.read(path, encoding: "utf-8")
      #   hit = Hit.new({ code: ref }, self)
      #   hit.fetch = IecBibliographicItem.from_hash hash
      #   return [hit]
      # end
    end

    def fetch_from_gh(ref)
      file = ref.sub(/^IEC\s/, "").gsub(/[\s\/]/, "_").upcase
      url = "#{GHURL}data/#{file}.yaml"
      resp = Net::HTTP.get URI(url)
      hash = YAML.safe_load resp
      hit = Hit.new({ code: ref }, self)
      hit.fetch = IecBibliographicItem.from_hash hash
      [hit]
    end

    # @param ref [String]
    # @param from [Date, nil]
    # @param to [Date, nil]
    # @return [Array<RelatonIec::Hit>]
    def get_results(ref, from, to)
      code = part ? ref.sub(/(?<=-\d)\d+/, "*") : ref
      [nil, "trf", "wr"].reduce([]) do |m, t|
        url = "#{DOMAIN}/searchkey"
        url += "&type=#{t}" if t
        url += "&RefNbr=#{code}&From=#{from}&To=#{to}&start=1"
        m + results(Addressable::URI.parse(url).normalize)
      end
    end

    # @param url [String]
    # @return [Array<RelatonIec::Hit>]
    def results(uri)
      contains = "[contains(.,'Part #{part}:')]" if part
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/" \
           "537.36 (KHTML, like Gecko) Chrome/86.0.4240.111 Safari/537.36"
      resp = OpenURI.open_uri(uri, "User-Agent" => ua)
      doc = Nokogiri::HTML(resp)
      doc.xpath(
        "//body/li#{contains}",
        "//ul[contains(@class,'search-results')]/li#{contains}",
        "//ul[contains(@class,'morethesame')]/li#{contains}",
      ).map { |h| make_hit h }.compact
    end

    def make_hit(hit)
      link = hit.at('a[@href!="#"]')
      return unless link

      code  = link.text.tr [194, 160].pack("c*").force_encoding("UTF-8"), ""
      title = hit.xpath("text()").text.gsub(/[\r\n]/, "")
      Hit.new({ code: code, title: title, url: DOMAIN + link[:href] }, self)
    end
  end
end
