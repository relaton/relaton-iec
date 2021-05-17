module RelatonIec
  class CitationType
    # @return [String]
    attr_reader :bibitemid

    # @return [Array<elatonBib::Locality, RelatonBib::LocalityStack>]
    attr_reader :locality

    # @return [String, nil]
    attr_reader :date

    #
    # @param [String] bibitemid
    # @param [Array<RelatonBib::Locality, RelatonBib::LocalityStack>] locality
    # @param [String, nil] date
    #
    def initialize(bibitemid:, locality:, date: nil)
      @bibitemid = bibitemid
      @locality = locality
      @date = date
    end

    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      builder.parent[:bibitemid] = bibitemid
      locality.each { |l| l.to_xml builder }
      builder.date date if date
    end
  end
end
