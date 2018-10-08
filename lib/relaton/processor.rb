require "relaton/processor"

module Relaton
  module Iecbib
    class Processor < Relaton::Processor

      def initialize
        @short = :iecbib
        @prefix = "IEC"
        @defaultprefix = %r{^(IEC)[ /]|^IEV($| )}
        @idtype = "IEC"
      end

      def get(code, date, opts)
        ::Iecbib::IecBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        IsoBibItem::XMLParser.from_xml xml
      end
    end
  end
end
