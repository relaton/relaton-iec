module BasicBlock
  class Dl
    #
    # @param [String] id
    # @param [Array<BasicBlock::Dl::Dt, BasicBlock::Dl::Dd>] content
    # @param [Array<BasicBlock::Note>] note
    #
    def initialize(id:, content:, note:)
      @id = id
      @content = content
      @note = note
    end

    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      builder.dl id: @id do |b|
        @content.each { |c| c.to_xml b }
        @note.each { |n| n.to_xml b }
      end
    end

    class Dt
      #
      # @param [Array<BasicBlock::TextElement>] content
      #
      def initialize(content)
        @content = content
      end

      #
      # @param [Nokogiri::XML::Builder] builder
      #
      def to_xml(builder)
        builder.dt do |b|
          @content.each { |c| c.to_xml b }
        end
      end
    end

    class Dd
      #
      # @param [Array<BasicBlock::ParagraphWithFootnote>] content
      #
      def initialize(content)
        @content = content
      end

      #
      # @param [Nokogiri::XML::Builder] builder
      #
      def to_xml(builder)
        builder.dd do |b|
          @content.each { |c| c.to_xml b }
        end
      end
    end
  end
end
