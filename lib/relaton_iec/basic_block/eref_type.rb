module RelatonIec
  class ErefType < RelatonIec::CitationType
    # @return [String]
    attr_reader :citeas

    # @return [RelatonIec::ReferenceFormat]
    attr_reader :type

    # @return [Boolean, nil]
    attr_reader :normative

    # @return [String, nil]
    attr_reader :alt

    # @param [String] citeas
    # @param [RelatonIec::ReferenceFormat] type
    # @param [Hash] args
    # @option args [Boolean, nil] :normative
    # @option args [String, nil] :alt
    def initialize(citeas:, type:, bibitemid:, locality:, **args)
      super bibitemid, locality, args[:date]
      @citeas = citeas
      @type = type
      @normative = args[:normative]
      @alt = args[:alt]
    end

    #
    # @param [Nokogiri::XML::Builder] builder <description>
    #
    def to_xml(builder) # rubocop:disable Metrics/AbcSize
      builder.parent[:normative] = normative unless normative.nil?
      builder.parent[:citeas] = citeas
      builder.parent[:type] = type
      builder.parent[:alt] = alt if alt
      super
    end
  end
end
