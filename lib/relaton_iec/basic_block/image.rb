module BasicBlock
  class Image
    #
    # @param [String] id
    # @param [String] src
    # @param [String] mimetype
    # @param [Hash] args
    # @option args [String] :filename
    #
    def initialize(id:, src:, mimetype:, **args) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
      @id = id
      @src = src
      @mimetype = mimetype
      @filename = args[:filename]
      if args[:width] && !args[:width].is_a?(Integer) && args[:width] != "auto"
        Util.warn "Invalid image width attribute: `#{args[:width]}`\nImage width should be integer or `auto`"
      end
      if args[:height] && !args[:height].is_a?(Integer) && args[:height] != "auto"
        Util.warn "Invalid image height attribute: `#{args[:height]}`\n" \
          "Image height should be integer or `auto`"
      end
      @width = args[:width]
      @height = args[:height]
      @alt = args[:alt]
      @title = args[:title]
      @longdesc = args[:longdesc]
    end

    # @param [Nokogiri::XML::Builder]
    def to_xml(builder) # rubocop:disable Metrics/CyclomaticComplexity
      img = builder.image id: @id, src: @src, mimetype: @mimetype
      img[:filename] = @filename if @filename
      img[:width] = @width if @width
      img[:height] = @height if @height
      img[:alt] = @alt if @alt
      img[:title] = @title if @title
      img[:longdesc] = @longdesc if @longdesc
    end
  end
end
