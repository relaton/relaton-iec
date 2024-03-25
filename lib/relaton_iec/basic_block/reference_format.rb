module RelatonIec
  def self.respond_to_missing?(method, _include_private)
    method == "ReferenceFormat"
  end

  def self.method_missing(_method, *args)
    ReferenceFormat.new(*args)
  end

  class ReferenceFormat
    FORMATS = %w[external inline footnote callout].freeze

    #
    # @param [String] format
    #
    def initialize(format)
      unless FORMATS.include? format
        Util.warn "Invalid reference format: `#{format}`\n" \
          "Alloved reference formats are: `#{FORMATS.join '`, `'}`"
      end
      @format = format
    end

    #
    # @return [String]
    #
    def to_s
      @format
    end

    #
    # @return [Sting] <description>
    #
    def inspect
      to_s
    end
  end
end
