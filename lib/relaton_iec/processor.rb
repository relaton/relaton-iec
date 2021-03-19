require "relaton/processor"

module RelatonIec
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_iec
      @prefix = "IEC"
      @defaultprefix = %r{^IEC\s|^IEV($|\s)}
      @idtype = "IEC"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def get(code, date, opts)
      ::RelatonIec::IecBibliography.get(code, date, opts)
    end

    # @param xml [String]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def from_xml(xml)
      RelatonIec::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def hash_to_bib(hash)
      ::RelatonIec::IecBibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonIec.grammar_hash
    end

    # @param code [String]
    # @return [String, nil]
    def urn_to_code(code)
      RelatonIec.urn_to_code code
    end
  end
end
