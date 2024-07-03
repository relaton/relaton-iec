module BasicBlock
  class Alignment
    ALIGNS = %w[left right center justified].freeze

    #
    # @param [String] content
    #
    def initialize(content)
      unless ALIGNS.include?(content)
        Util.warn "invalid alignment `#{content}`\nalloved aligments are: `#{ALIGNS.join '`, `'}`"
      end
      @content = content
    end

    #
    # @return [String]
    #
    def to_s
      @content
    end

    #
    # @return [String]
    #
    def inspect
      to_s
    end
  end
end
