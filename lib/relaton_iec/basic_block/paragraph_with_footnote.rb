module BasicBlock
  class ParagraphWithFootnote
    #
    # @param [String] id
    # @param [Hash] args
    # @param [BasicBlock::Alignment, nil] align
    # @param [Array<BasicBlock::TextElement, BasicBlock::Eref, BasicBlock::Stem,
    #   BasicBlock::Image, BasicBlock::Index, BasicBlock::IndexXref>] content
    # @param [Array<RelatonIec::Note>] note
    #
    def initialize(id:, align: nil, content: [], note: [])
      @id = id
      @aligments = align
      @content = content
      @note = note
    end

    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      elm = builder.p(@id) do |b|
        @content.each { |te| te.to_xml b }
        @note.each { |n| n.to_xml b }
      end
      elm[:align] = @align if @align
    end
  end
end
