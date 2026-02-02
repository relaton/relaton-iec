module Relaton
  module Iec
    class Doctype < Bib::Doctype
      TYPES = %w[
        international-standard technical-specification technical-report publicly-available-specification
        international-workshop-agreement guide industry-technical-agreement system-reference-deliverable
      ].freeze

      attribute :content, :string, values: TYPES
    end
  end
end
