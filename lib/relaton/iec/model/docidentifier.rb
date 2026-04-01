module Relaton
  module Iec
    class Pubid < Lutaml::Model::Type::Value
      class << self
        def cast(value)
          value.is_a?(String) ? ::Pubid::Iec::Identifier.parse(value) : value
        rescue StandardError
          Util.warn "Failed to parse Pubid: #{value}"
          value
        end
      end

      ::Lutaml::Model::Config::AVAILABLE_FORMATS.each do |format|
        define_method(:"to_#{format}") { value.to_s }
      end

      def to_h = value.to_h
      def urn = value.urn
    end

    class Docidentifier < Bib::Docidentifier
      attribute :content, Pubid

      def content_to_xml(model, parent, doc)
        doc.add_xml_fragment parent, model.to_s
      end

      def content_to_key_value(model, doc)
        doc["content"] = model.to_s
      end

      def to_all_parts!
        if content.is_a? String
          Util.warn "Cannot convert String to all parts: #{content}"
          return
        end

        remove_part!
        remove_date!
        remove_stage!
        content.all_parts = true if content.respond_to?(:all_parts=)
      end

      def remove_stage!
        remove_attr! :stage
      end

      def remove_part!
        remove_attr! :part
      end

      def remove_date!
        remove_attr! :year
      end

      def to_s
        return content if content.is_a? String

        case type
        when "URN" then content.urn
        else content.to_s
        end
      end

      private

      def remove_attr!(attr)
        return false if content.is_a? String

        content.send(:"#{attr}=", nil)
        true
      end
    end
  end
end
