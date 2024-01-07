require "relaton/processor"

module RelatonIec
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_iec
      @prefix = "IEC"
      @defaultprefix = %r{^(IEC\s|CISPR\s|IEV($|\s))}
      @idtype = "IEC"
      @datasets = %w[iec-harmonized-all iec-harmonized-latest]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def get(code, date, opts)
      ::RelatonIec::IecBibliography.get(code, date, opts)
    end

    #
    # Fetch all the documents from a source
    #
    # @param [String] source source name (iec-harmonized-all, iec-harmonized-latest)
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format output format (xml, yaml, bibxml)
    #
    def fetch_data(source, opts)
      DataFetcher.new(source, **opts).fetch
    end

    # @param xml [String]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def from_xml(xml)
      RelatonIec::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIec::IecBibliographicItem]
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

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:IEC, url: true, file: HitCollection::INDEX_FILE).remove_file
    end
  end
end
