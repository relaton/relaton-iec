require "relaton/processor"

module RelatonIec
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_iec
      @prefix = "IEC"
      @defaultprefix = %r{^(IEC)[ /]|^IEV($| )}
      @idtype = "IEC"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def get(code, date, opts)
      ::RelatonIec::IecBibliography.get(code, date, opts)
    end

    # @param xml [String]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def from_xml(xml)
      RelatonIsoBib::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def hash_to_bib(hash)
      item_hash = ::RelatonIsoBib::HashConverter.hash_to_bib(hash)
      ::RelatonIsoBib::IsoBibliographicItem.new item_hash
    end
  end
end
