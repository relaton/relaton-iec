module BasicBlock
  class TextElement
    TAGS = %w[em strong sub sup tt underline strike smallcap br hr keyword rp
              rt ruby pagebreak bookmark].freeze

    #
    # @param [String] tag
    # @param [Array<String, BasicBlock::TextElement, BasicBlock::Stem>,
    #   String] content
    #
    def initialize(tag:, content:)
      unless TAGS.include? tag
        Util.warn "invalid tag `#{tag}`\nallowed tags are: `#{TAGS.join '`, `'}`"
      end
      @tag = tag
      @content = content
    end

    # @param [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.send @tag do |b|
        @content.each { |c| c.is_a?(String) ? c : c.to_xml(b) }
      end
    end
  end
end
