require "relaton/processor"

module Relaton
  module Iecbib
    class Processor < Relaton::Processor

      def initialize
        @short = :isobib
        @prefix = "IEC"
        @defaultprefix = %r{^(IEC)[ /]|^IEV($| )}
        @idtype = "IEC"
      end

      def get(code, date, opts)
        ::Isobib::IsoBibliography.get(code, date, opts)
      end
    end
  end
end
