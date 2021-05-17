module RelatonIec
  class TcScOfficersNote
    # @return [Array<RelatonIec::BasicBlock>]
    attr_reader :basic_blocks

    #
    # @param [Array<BasicBlock::ParagraphWithFootnote>] basic_blocks
    #
    def initialize(basic_blocks)
      @basic_blocks = basic_blocks
    end

    #
    # XML serialization
    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      builder.send "tc-sc-officers-note" do |b|
        basic_blocks.each { |bb| bb.to_xml b }
      end
    end
  end
end
