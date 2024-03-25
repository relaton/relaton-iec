module RelatonIec
  class DocumentType < RelatonBib::DocumentType
    DOCTYPES = %w[
      international-standard technical-specification technical-report
      publicly-available-specification international-workshop-agreement
      guide industry-technical-agreement system-reference-deliverable
    ].freeze

    def initialize(type:, abbreviation: nil)
      check_type type
      super
    end

    def check_type(type)
      unless DOCTYPES.include? type
        Util.warn "Invalid doctype: `#{type}`"
      end
    end
  end
end
