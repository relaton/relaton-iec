module RelatonIec
  class IecBibliographicItem < RelatonIsoBib::IsoBibliographicItem
    SUBDOCTYPES = %w[specification method-of-test vocabulary code-of-practice].freeze

    FUNCTION = %w[emc safety enviroment quality-assurance].freeze

    # @return [String, nil]
    attr_reader :function, :updates_document_type, :secretary,
                :interest_to_committees

    # @return [Boolean, nil]
    attr_reader :accessibility_color_inside, :cen_processing

    # attr_reader :tc_sc_officers_note

    #
    # Initialize instance of RelatonIec::IecBibliographicItem
    #
    # @param [Hash] **args hash of attributes
    # @option args [String, nil] :function function
    # @option args [String, nil] :updates_document_type updates document type
    # @option args [String, nil] :price_code price code
    # @option args [Boolean, nil] :cen_processing
    # @option args [String, nil] :secretary
    # @option args [String, nil] :secretary secretary
    # @option args [String, nil] :interest_to_committees interest to committees
    # @option args [Boolean, nil] :accessibility_color_inside accessibility color inside
    #
    def initialize(**args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if args[:function] && !FUNCTION.include?(args[:function])
        Util.warn do
          "Invalid function: `#{args[:function]}`\n" \
          "Allowed function values are: `#{FUNCTION.join('`, `')}`"
        end
      end
      if args[:updates_document_type] &&
          !DocumentType::DOCTYPES.include?(args[:updates_document_type])
        Util.warn do
          "WARNING: Invalid updates_document_type: `#{args[:updates_document_type]}`\n" \
          "Allowed updates_document_type values are: `#{DocumentType::DOCTYPES.join('`, `')}`"
        end
      end
      @function = args.delete :function
      @updates_document_type = args.delete :updates_document_type
      @accessibility_color_inside = args.delete :accessibility_color_inside
      @cen_processing = args.delete :cen_processing
      @secretary = args.delete :secretary
      @interest_to_committees = args.delete :interest_to_committees
      super
    end

    #
    # Fetch flavor schema version
    #
    # @return [String] schema version
    #
    def ext_schema
      schema_versions["relaton-model-iec"]
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def self.from_hash(hash)
      item_hash = ::RelatonIec::HashConverter.hash_to_bib(hash)
      new(**item_hash)
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [String] :lang language
    # @return [String] XML
    def to_xml(**opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      super(**opts) do |b|
        if opts[:bibdata]
          ext = b.ext do
            doctype&.to_xml b
            b.horizontal horizontal unless horizontal.nil?
            b.function function if function
            editorialgroup&.to_xml b
            ics.each { |i| i.to_xml b }
            structuredidentifier&.to_xml b
            b.stagename stagename if stagename
            if updates_document_type
              b.send(:"updates-document-type", updates_document_type)
            end
            unless accessibility_color_inside.nil?
              b.send(:"accessibility-color-inside", accessibility_color_inside)
            end
            b.send(:"price-code", price_code) if price_code
            b.send(:"cen-processing", cen_processing) unless cen_processing.nil?
            b.secretary secretary if secretary
            if interest_to_committees
              b.send(:"interest-to-committees", interest_to_committees)
            end
          end
          ext["schema-version"] = ext_schema unless opts[:embedded]
        end
      end
    end

    # @return [Hash]
    def to_hash(embedded: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      hash = super
      hash["ext"]["function"] = function if function
      if updates_document_type
        hash["ext"]["updates_document_type"] = updates_document_type
      end
      unless accessibility_color_inside.nil?
        hash["ext"]["accessibility_color_inside"] = accessibility_color_inside
      end
      hash["ext"]["cen_processing"] = cen_processing unless cen_processing.nil?
      hash["ext"]["secretary"] = secretary if secretary
      if interest_to_committees
        hash["ext"]["interest_to_committees"] = interest_to_committees
      end
      hash
    end

    def has_ext?
      super || function || updates_document_type || !accessibility_color_inside.nil? ||
        !cen_processing.nil? || secretary || interest_to_committees
    end
  end
end
