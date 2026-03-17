require "relaton/core/processor"

module Relaton
  module Iec
    class Processor < Core::Processor
      def initialize
        @short = :relaton_iec
        @prefix = "IEC"
        @defaultprefix = %r{^(IEC\s|CISPR\s|IEV($|\s))}
        @idtype = "IEC"
        @datasets = %w[iec-harmonized-all iec-harmonized-latest]
      end

      # @param code [String]
      # @param date [String, nil] year
      # @param opts [Hash]
      # @return [Relaton::Iec::ItemData, nil]
      def get(code, date, opts)
        require_relative "../iec"
        Bibliography.get(code, date, opts)
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
        require_relative "data_fetcher"
        DataFetcher.fetch(source, **opts)
      end

      # @param xml [String]
      # @return [Relaton::Iec::ItemData]
      def from_xml(xml)
        require_relative "../iec"
        Item.from_xml xml
      end

      # @param yaml [String]
      # @return [Relaton::Iec::ItemData]
      def from_yaml(yaml)
        require_relative "../iec"
        Item.from_yaml yaml
      end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        require_relative "../iec"
        @grammar_hash ||= ::Relaton::Iec.grammar_hash
      end

      # @param code [String]
      # @return [String, nil]
      def urn_to_code(code)
        require_relative "../iec"
        Relaton::Iec.urn_to_code code
      end

      #
      # Remove index file
      #
      def remove_index_file
        require_relative "../iec"
        Relaton::Index.find_or_create(:iec, url: true, file: "#{INDEXFILE}.yaml").remove_file
      end
    end
  end
end
