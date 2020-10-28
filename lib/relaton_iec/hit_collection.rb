# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://webstore.iec.ch"

    # @param ref_nbr [String]
    # @param year [String]
    def initialize(ref_nbr, year = nil)
      super
      @array = hits ref_nbr, year
    end

    private

    def hits(ref, year)
      from, to = nil
      if year
        from = Date.strptime year, "%Y"
        to   = from.next_year.prev_day
      end
      get_results ref, from, to
    end

    def get_results(ref, from,to)
      [nil, "trf", "wr"].reduce([]) do |m, t|
        url = "#{DOMAIN}/searchkey"
        url += "&type=#{t}" if t
        url += "&RefNbr=#{ref}&From=#{from}&To=#{to}&start=1"
        m + results(Addressable::URI.parse(url).normalize)
      end
    end

    def results(uri)
      Nokogiri::HTML(OpenURI.open_uri(uri)).css(
        "//body/li", "ul.search-results > li", "ul.morethesame > li"
      ).map { |h| make_hit h }
    end

    def make_hit(hit)
      link  = hit.at('a[@href!="#"]')
      code  = link.text.tr [194, 160].pack("c*").force_encoding("UTF-8"), ""
      title = hit.xpath("text()").text.gsub(/[\r\n]/, "")
      Hit.new({ code: code, title: title, url: DOMAIN + link[:href] }, self)
    end
  end
end
