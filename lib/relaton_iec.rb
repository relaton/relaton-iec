require "relaton_iec/version"
require "relaton_iec/iec_bibliography"
require "relaton_iec/iec_bibliographic_item"
require "relaton_iec/xml_parser"
require "relaton_iec/hash_converter"
require "digest/md5"

module RelatonIec
  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    gem_path = File.expand_path "..", __dir__
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end
