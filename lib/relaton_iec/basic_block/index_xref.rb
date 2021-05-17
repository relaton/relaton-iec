module BasicBlock
  class IndexXref
    #
    # @param [Boolean] also
    # @param [Array<BasicBlock::TextElement>] primary
    # @param [Array<BasicBlock::TextElement>] target
    # @param [Hash] args
    # @option args [Array<BasicBlock::TextElement>, nil] secondary
    # @option args [Array<BasicBlock::TextElement>, nil] tertiary
    #
    def initialize(also:, primary:, target:, **args)
      @also = also
      @primary = primary
      @target = target
      @secondary = args[:secondary]
      @tertiary = args[:tertiary]
    end

    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder) # rubocop:disable Metrics/CyclomaticComplexity
      builder.send "index-xref", also: @also do |b|
        @primary.each { |p| p.to_xml b }
        @secondary&.each { |s| s.to_xml b }
        @tertiary&.each { |t| t.to_xml b }
        @target.each { |t| t.to_xml b }
      end
    end
  end
end
