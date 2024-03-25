module BasicBlock
  class Table
    #
    # @param [String] id
    # @param [Array<BasicBlock::Tr>] tbody
    # @param [Array<BasicBlock::Paragraph>] note
    # @param [Hash] args
    # @option args [Boolean, nil] :unnumbered
    # @option args [String, nil] :subsequence
    # @option args [String, nil] :alt
    # @option args [String, nil] :summary
    # @option args [String, nil] :uri
    # @option args [BasicBlock::TextElement, nil] :tname
    # @option args [BasicBlock::Table::Tr, nil] :thead
    # @option args [BasicBlock::TextElement, nil] :tfoot
    # @option args [BasicBlock::Dl, nil] :dl
    #
    def initialize(id:, tbody:, note:, **args) # rubocop:disable Metrics/MethodLength
      @id = id
      @unnumbered = args[:unnumbered]
      @subsequence = args[:subsequence]
      @alt = args[:alt]
      @summary = args[:summary]
      @uri = args[:uri]
      @tname = args[:tname]
      @thead = args[:thead]
      @tbody = tbody
      @tfoot = args[:tfoot]
      @note = note
      @dl = args[:dl]
    end

    # @param [Nokogiri::XML::Builder] builder
    def to_xml(builder) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      tab = builder.table id: @id do |b|
        b.name { @tname.to_xml b } if @tname
        b.thead { @thead.to_xml b } if @thead
        @tbody.each { |tb| tb.to_xml b }
        b.name { @tfoot.to_xml b } if @tfoot
        @note.each { |n| b.note { n.to_xml b } }
        @dl.to_xml b
      end
      tab[:unnumbered] = @unnumbered if @unnumbered
      tab[:subsequence] = @subsequence if @subsequence
      tab[:alt] = @alt if @alt
      tab[:summary] = @summary if @summary
      tab[:uri] = @uri if @uri
    end

    class Tr
      # @param [Array<BasicBlock::Table::Td, BasicBlock::Table::Th>] content
      def initialize(content)
        @content = content
      end

      # @param [Nokogiri::XML::Builder] builder
      def to_xml(builder)
        builder.tr do |b|
          @content.each { |c| c.to_xm b }
        end
      end
    end

    class TabCell
      ALIGNS = %w[left right ceter].freeze
      VALIGNS = %w[top middle bottom baseline].freeze

      # @param [Array<BasicBlock::TextElement,
      #   BasicBlock::ParagraphWithFootnote>] content
      # @param [Hssh] args
      # @option args [String, nil] :colspan
      # @option args [String, nil] :rowspan
      # @option args [String, nil] :align
      # @option args [String, nil] :valign
      def initialize(content, **args) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if args[:align] && !ALIGNS.include?(args[:align])
          Util.warn "invalid table/tr/td align `#{args[:align]}`\n" \
            "alloved aligns are: `#{ALIGNS.join '`, `'}`"
        end
        if args[:valign] && !VALIGNS.include?(args[:valign])
          Util.warn "invalid table/tr/td valign `#{args[:valign]}`\n" \
            "alloved valigns are: `#{VALIGNS.join '`, `'}`"
        end
        @content = content
        @colspan = args[:colspan]
        @rowspan = args[:rowspan]
        @align = args[:align]
        @valign = args[:valign]
      end

      # @param [Nokogiri::XML::Builder] builder
      def to_xml(builder)
        td = @content.each { |c| c.to_xml builder }
        td[:colspan] = @colspan if @colspan
        td[:rowspan] = @rowspan if @rowspan
        td[:align] = @align if @align
        td[:valign] = @valign if @valign
      end
    end

    class Td < BasicBlock::Table::TabCell
      # @param [Nokogiri::XML::Builder] builder
      def to_xml(builder)
        builder.th { super }
      end
    end

    class Th < BasicBlock::Table::TabCell
      # @param [Nokogiri::XML::Builder] builder
      def to_xml(builder)
        builder.td { super }
      end
    end
  end
end
