module BasicBlock
  class Formula
    #
    # @param [String] id
    # @param [BasicBlock::Stem] content
    # @param [Array<BasicBlock::Note>] note
    # @param [Hash] args
    # @option args [Boolean, nil] :unnumbered
    # @option args [String, nil] :subsequence
    # @option args [Boolean, nil] :inequality
    # @option args [BasicBlock::Dl, nil] :dl
    #
    def initialize(id:, content:, note:, **args)
      @id = id
      @content = content
      @note = note
      @unnumbered = args[:unnumbered]
    end

    #
    # @param [Builder] builder
    #
    def to_xml(builder) # rubocop:disable Metrics/CyclomaticComplexity
      f = builder.formula id: @id do |b|
        @content.to_xml b
        @dl&.each { |d| d.to_xml b }
        @note.each { |n| n.to_xml b }
      end
      f[:unnumbered] = @unnumbered if @unnumbered
      f[:subsequence] = @subsequence if @subsequence
      f[:inequality] = @inequality if @ineainequality
    end
  end
end
