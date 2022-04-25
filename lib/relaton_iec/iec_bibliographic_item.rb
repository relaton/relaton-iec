module RelatonIec
  class IecBibliographicItem < RelatonIsoBib::IsoBibliographicItem
    TYPES = %w[
      international-standard technical-specification technical-report
      publicly-available-specification international-workshop-agreement
      guide industry-technical-agreement system-reference-delivrabble
    ].freeze

    FUNCTION = %w[emc safety enviroment quality-assurance].freeze

    # @return [String, nil]
    attr_reader :function, :updates_document_type, :price_code, :secretary,
                :interest_to_committees

    # @return [Boolean, nil]
    attr_reader :accessibility_color_inside, :cen_processing

    # attr_reader :tc_sc_officers_note

    def initialize(**args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if args[:function] && !FUNCTION.include?(args[:function])
        warn "[relaton-iec] WARNING: invalid function \"#{args[:function]}\""
        warn "[relaton-iec] allowed function values are: #{FUNCTION.join(', ')}"
      end
      if args[:updates_document_type] &&
          !TYPES.include?(args[:updates_document_type])
        warn "[relaton-iec] WARNING: invalid updates_document_type "\
             "\"#{args[:updates_document_type]}\""
        warn "[relaton-iec] allowed updates_document_type values are: "\
             "#{TYPES.join(', ')}"
      end
      @function = args.delete :function
      @updates_document_type = args.delete :updates_document_type
      @accessibility_color_inside = args.delete :accessibility_color_inside
      @price_code = args.delete :price_code
      @cen_processing = args.delete :cen_processing
      @secretary = args.delete :secretary
      @interest_to_committees = args.delete :interest_to_committees
      super
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::IecBibliographicItem]
    def self.from_hash(hash)
      item_hash = ::RelatonIec::HashConverter.hash_to_bib(hash)
      new **item_hash
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [String] :lang language
    # @return [String] XML
    def to_xml(**opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      super **opts do |b|
        if opts[:bibdata]
          b.ext do
            b.doctype doctype if doctype
            b.horizontal horizontal unless horizontal.nil?
            b.function function if function
            editorialgroup&.to_xml b
            ics.each { |i| i.to_xml b }
            structuredidentifier&.to_xml b
            b.stagename stagename if stagename
            if updates_document_type
              b.send("updates-document-type", updates_document_type)
            end
            unless accessibility_color_inside.nil?
              b.send("accessibility-color-inside", accessibility_color_inside)
            end
            b.send("price-code", price_code) if price_code
            b.send("cen-processing", cen_processing) unless cen_processing.nil?
            b.secretary secretary if secretary
            if interest_to_committees
              b.send("interest-to-committees", interest_to_committees)
            end
          end
        end
      end
    end

    # @return [Hash]
    def to_hash # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      hash = super
      hash["function"] = function if function
      if updates_document_type
        hash["updates_document_type"] = updates_document_type
      end
      unless accessibility_color_inside.nil?
        hash["accessibility_color_inside"] = accessibility_color_inside
      end
      hash["price_code"] = price_code if price_code
      hash["cen_processing"] = cen_processing unless cen_processing.nil?
      hash["secretary"] = secretary if secretary
      if interest_to_committees
        hash["interest_to_committees"] = interest_to_committees
      end
      hash
    end
  end
end
