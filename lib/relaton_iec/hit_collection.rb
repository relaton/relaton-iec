# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://webstore.iec.ch"

    # @param ref_nbr [String]
    # @param year [String, nil]
    # @param part [String, nil]
    def initialize(ref_nbr, year = nil, part = nil)
      super ref_nbr, year
      @array = hits ref_nbr, year, part
    end

    private

    # @param ref [String]
    # @param year [String, nil]
    # @param part [String, nil]
    # @return [Array<RelatonIec::Hit>]
    def hits(ref, year, part)
      from, to = nil
      if year
        from = Date.strptime year, "%Y"
        to   = from.next_year.prev_day
      end
      get_results ref, from, to, part
    end

    # @param ref [String]
    # @param from [Date, nil]
    # @param to [Date, nil]
    # @param part [String, nil]
    # @return [Array<RelatonIec::Hit>]
    def get_results(ref, from, to, part = nil)
      code = part ? ref.sub(/(?<=-\d)\d+/, "*") : ref
      [nil, "trf", "wr"].reduce([]) do |m, t|
        url = "#{DOMAIN}/searchkey"
        url += "&type=#{t}" if t
        url += "&RefNbr=#{code}&From=#{from}&To=#{to}&start=1"
        m + results(Addressable::URI.parse(url).normalize, part)
      end
    end

    # @param url [String]
    # @param part [String, nil]
    # @return [Array<RelatonIec::Hit>]
    def results(uri, part)
      contains = "[contains(.,'Part #{part}:')]" if part
      resp = OpenURI.open_uri(uri, "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) "\
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.111 Safari/537.36")
      doc = Nokogiri::HTML(resp)
      doc.xpath(
        "//body/li#{contains}",
        "//ul[contains(@class,'search-results')]/li#{contains}",
        "//ul[contains(@class,'morethesame')]/li#{contains}"
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
