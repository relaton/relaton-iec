module BasicBlock
  class Stem
    TYPES = %w[MathML AsciiMath].freeze

    # @return [String]
    attr_reader :type

    #
    # @param [String] type
    # @param [Array<#to_xml>] content any element
    #
    def initialize(type:, content: [])
      unless TYPES.include? type
        warn "[relaton-iec] WARNING: Invalud type: \"#{type}\""
        warn "[relaton-iec] Allowed types are: #{TYPES.join ', '}"
      end
      @type = type
      @content = content
    end

    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      builder.stem(type) do |b|
        content.each { |c| c.to_xml b }
      end
    end
  end
end
