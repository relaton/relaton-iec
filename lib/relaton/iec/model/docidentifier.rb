module Relaton
  module Iec
    class Docidentifier < Bib::Docidentifier
      attribute :content, :string

      attr_reader :pubid

      def initialize(arg = nil, **kwargs)
        arg.is_a?(Hash) ? super(arg) : super(**kwargs)
        raw = arg.is_a?(Hash) ? (arg["content"] || arg[:content]) : kwargs[:content]
        self.content = raw if raw
      end

      alias_method :original_content=, :content=
      alias_method :original_content, :content

      def content=(value)
        @pubid = nil
        @raw_content = nil

        parsed =
          case value
          when ::Pubid::Iec::Base then value
          when String then parse_content(value)
          end

        if parsed
          @pubid = parsed
        elsif value.is_a?(String)
          @raw_content = value
        end

        send(:original_content=, to_s)
      end

      def content
        return @raw_content if @raw_content
        return render_pubid(@pubid) if @pubid

        original_content
      end

      def to_s
        content.to_s
      end

      def to_all_parts!
        return unless @pubid

        remove_part!
        remove_date!
        remove_stage!
        @pubid.all_parts = true if @pubid.respond_to?(:all_parts=)
        refresh_content!
      end

      def remove_stage!
        remove_attr!(:stage)
      end

      def remove_part!
        remove_attr!(:part)
      end

      def remove_date!
        remove_attr!(:year)
      end

      private

      # Parse a string identifier into a Pubid object. IEC URNs use a positional
      # format that pubid-iec cannot parse for amendments, series or
      # consolidations. Those URNs are already in canonical ABNF form, so on a
      # parse failure they are kept verbatim (as @raw_content) rather than warned
      # about (relaton-iec#73, metanorma-pdfa#77); genuinely malformed non-URN
      # identifiers still warn.
      def parse_content(value)
        ::Pubid::Iec::Identifier.parse(value)
      rescue StandardError
        Util.warn "Failed to parse Pubid: #{value}" unless value.start_with?("urn:")
        nil
      end

      def render_pubid(pubid)
        case type
        when "URN" then pubid.urn
        else pubid.to_s
        end
      end

      def remove_attr!(attr)
        return unless @pubid

        @pubid.send("#{attr}=", nil)
        base = @pubid.base
        while base
          base.send("#{attr}=", nil)
          base = base.base
        end
        refresh_content!
      end

      def refresh_content!
        send(:original_content=, to_s)
      end
    end
  end
end
