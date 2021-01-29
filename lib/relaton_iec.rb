require "relaton_iso_bib"
require "relaton_iec/hit"
require "nokogiri"
require "net/http"
require "relaton_iec/version"
require "relaton_iec/iec_bibliography"
require "relaton_iec/iec_bibliographic_item"
require "relaton_iec/xml_parser"
require "relaton_iec/hash_converter"
require "digest/md5"

module RelatonIec
  class << self
    # Returns hash of XML reammar
    # @return [String]
    def grammar_hash
      gem_path = File.expand_path "..", __dir__
      grammars_path = File.join gem_path, "grammars", "*"
      grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest grammars
    end

    # @param code [String]
    # @param lang [String]
    # @return [String]
    def code_to_urn(code, lang = nil)
      rest = code.downcase.sub(%r{
        (?<head>[^\s]+)\s
        (?<type>is|ts|tr|pas|srd|guide|tec|wp)?(?(<type>)\s)
        (?<pnum>[\d-]+)\s?
        (?<_dd>:)?(?(<_dd>)(?<date>[\d-]+)\s?)
      }x, "")
      m = $~
      deliv = /cmv|csv|exv|prv|rlv|ser/.match(code.downcase).to_s
      urn = ["urn", "iec", "std", m[:head].split("/").join("-"), m[:pnum], m[:date], m[:type], deliv, lang]
      (urn + fetch_ajunct(rest)).join ":"
    end

    private

    # @param rest [String]
    # @return [Array<String, nil>]
    def fetch_ajunct(rest)
      r = rest.sub(%r{
        (?<_pl>\+|\/)(?(<_pl>)(?<adjunct>amd)(?<adjnum>\d+)\s?)
        (?<_d2>:)?(?(<_d2>)(?<adjdt>[\d-]+)\s?)
      }x, "")
      m = $~ || {}
      return [] unless m[:adjunct]

      plus = m[:adjunct] && "plus"
      urn = [plus, m[:adjunct], m[:adjnum], m[:adjdt]]
      urn + fetch_ajunct(r)
    end
  end
end
