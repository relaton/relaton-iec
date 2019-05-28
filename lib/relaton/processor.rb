require "relaton/processor"

module Relaton
  module RelatonIec
    class Processor < Relaton::Processor

      def initialize
        @short = :relaton_iec
        @prefix = "IEC"
        @defaultprefix = %r{^(IEC)[ /]|^IEV($| )}
        @idtype = "IEC"
      end

      def get(code, date, opts)
        ::RelatonIec::IecBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        RelatonIsoBib::XMLParser.from_xml xml
      end
    end
  end
end
