module BasicBlock
  class Note
    #
    # @param [String] id
    # @param [Array<BasicBlock::Paragraph>] content
    #
    def initialize(id:, content:)
      @id = id
      @contain = content
    end

    #
    # @param [Nokogiei::XMO::Builder] builder
    #
    def to_xml(builder)
      builder.note id: @id do |b|
        @content.each { |c| c.to_xm b }
      end
    end
  end
end
