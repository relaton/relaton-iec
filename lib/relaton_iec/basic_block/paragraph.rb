module BasicBlock
  class Paragraph
    #
    # @param [String] id
    # @param [Array<BasicBlock::TextElement>] content
    # @param [Array<BasicBlock::Note>] note
    # @param [BasicBlock::Alignment, nil] align
    #
    def initialize(id:, content:, note:, align: nil)
      @id = id
      @content = content
      @note = note
      @align = align
    end
  end

  #
  # @param [Nokogiri::XML::Builder] builder
  #
  def to_xml(builder)
    p = builder.p id: @id do |b|
      @content.each { |c| c.to_xml b }
      @note.each { |n| n.to_xml b }
    end
    p[:align] = @align if @align
  end
end
