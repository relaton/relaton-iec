require "digest/md5"
require "net/http"
require "nokogiri"
require "zip"
require "open-uri"
require "relaton/index"
require "relaton_iso_bib"
require "relaton_iec/hit"
require "relaton_iec/version"
require "relaton_iec/util"
require "relaton_iec/document_type"
require "relaton_iec/iec_bibliography"
require "relaton_iec/iec_bibliographic_item"
require "relaton_iec/xml_parser"
require "relaton_iec/hash_converter"
# require "relaton_iec/index"
require "relaton_iec/data_fetcher"
require "relaton_iec/data_parser"

module RelatonIec
  class << self
    # Returns hash of XML reammar
    # @return [String]
    def grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest RelatonIec::VERSION + RelatonIsoBib::VERSION + RelatonBib::VERSION # grammars
    end

    # @param code [String]
    # @param lang [String]
    # @return [String, nil]
    def code_to_urn(code, lang = nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      rest = code.downcase.sub(%r{
        (?<head>[^\s]+)\s
        (?<type>is|ts|tr|pas|srd|guide|tec|wp)?(?(<type>)\s)
        (?<pnum>[\d-]+)\s?
        (?<_dd>:)?(?(<_dd>)(?<date>[\d-]+)\s?)
      }x, "")
      m = $~
      return unless m[:head] && m[:pnum]

      deliv = /cmv|csv|exv|prv|rlv|ser/.match(code.downcase).to_s
      urn = ["urn", "iec", "std", m[:head].split("/").join("-"), m[:pnum], m[:date], m[:type], deliv, lang]
      (urn + ajunct_to_urn(rest)).join ":"
    end

    # @param urn [String]
    # @return [Array<String>, nil] urn & language
    def urn_to_code(urn) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      fields = urn.upcase.split ":"
      return if fields.size < 5

      head, num, date, type, deliv, lang = fields[3, 8]
      code = head.gsub("-", "/")
      code += " #{type}" unless type.nil? || type.empty?
      code += " #{num}"
      code += ":#{date}" unless date.nil? || date.empty?
      code += ajanct_to_code(fields[9..-1])
      code += " #{deliv}" unless deliv.nil? || deliv.empty?
      [code, lang&.downcase]
    end

    private

    # @param fields [Array<String>]
    # @return [String]
    def ajanct_to_code(fields)
      return "" if fields.nil? || fields.empty?

      rel, type, num, date = fields[0..3]
      code = (rel.empty? ? "/" : "+") + type + num
      code += ":#{date}" unless date.empty?
      code + ajanct_to_code(fields[4..-1])
    end

    # @param rest [String]
    # @return [Array<String, nil>]
    def ajunct_to_urn(rest)
      r = rest.sub(%r{
        (?<pl>\+|/)(?(<pl>)(?<adjunct>(?:amd|cor|ish))(?<adjnum>\d+)\s?)
        (?<_d2>:)?(?(<_d2>)(?<adjdt>[\d-]+)\s?)
      }x, "")
      m = $~ || {}
      return [] unless m[:adjunct]

      plus = "plus" if m[:pl] == "+"
      urn = [plus, m[:adjunct], m[:adjnum], m[:adjdt]]
      urn + ajunct_to_urn(r)
    end
  end
end
