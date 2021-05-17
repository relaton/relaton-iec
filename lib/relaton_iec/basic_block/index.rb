module BasicBlock
  class Index
    #
    # @param [Array<BasicBlock::TextElement] primary
    # @param [Hash] args
    # @option args [String, nil] :to
    # @option args [Array<BasicBlock::TextElement>, nil] :secondary
    # @option args [Array<BasicBlock::TextElement>, nil] :tertiary
    #
    def initialize(primary:, **args)
      @to = args[:to]
      @primary = primary
      @secondary = args[:secondary]
      @tertiary = args[:tertiary]
    end

    # @param [Nokogiri::XML::Builder] builder
    def to_xml(builder) # rubocop:disable Metrics/CyclomaticComplexity
      idx = builder.index do |b|
        @primary.each { |p| p.to_xml b }
        @secondary&.each { |s| s.to_xml b }
        @tertiary&.each { |t| t.to_xml b }
      end
      idx[:to] = @to if @to
    end
  end
end
