# frozen_string_literal: true

require "relaton_iec/hit"
require "addressable/uri"

module RelatonIec
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://webstore.iec.ch"

    # @param ref_nbr [String]
    # @param year [String]
    def initialize(ref_nbr, year = nil) #(text, hit_pages = nil)
      super
      from, to = nil
      if year
        from = Date.strptime year, "%Y"
        to   = from.next_year.prev_day
      end
      url  = "#{DOMAIN}/searchkey&RefNbr=#{ref_nbr}&From=#{from}&To=#{to}&start=1"
      doc  = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
      @array = doc.css("ul.search-results > li").map do |h|
        link  = h.at('a[@href!="#"]')
        code  = link.text.tr [194, 160].pack("c*").force_encoding("UTF-8"), ""
        title = h.xpath("text()").text.gsub(/[\r\n]/, "")
        url   = DOMAIN + link[:href]
        Hit.new({ code: code, title: title, url: url }, self)
      end
    end
  end
end
