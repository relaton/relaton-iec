require_relative "doctype"
require_relative "stage_name"

module Relaton
  module Iec
    class Ext < Bib::Ext
      attribute :doctype, Doctype
      attribute :subdoctype, :string, values: %w[specification method-of-test vocabulary code-of-practice]
      attribute :structuredidentifier, Iso::StructuredIdentifier
      attribute :horizontal, :boolean
      attribute :stagename, StageName
      attribute :updates_document_type, :string, values: Doctype::TYPES
      attribute :fast_track, :boolean
      attribute :price_code, :string
      attribute :function, :string, values: %w[emc safety environment quality-assurance]
      attribute :accessibility_color_inside, :boolean
      attribute :cen_processing, :boolean
      attribute :secretary, :string
      attribute :interest_to_committees, :string
      attribute :tc_sc_officers_note, :string, raw: true

      xml do
        map_element "horizontal", to: :horizontal
        map_element "stagename", to: :stagename
        map_element "updates-document-type", to: :updates_document_type
        map_element "fast-track", to: :fast_track
        map_element "price-code", to: :price_code
        map_element "function", to: :function
        map_element "accessibility-color-inside", to: :accessibility_color_inside
        map_element "cen-processing", to: :cen_processing
        map_element "secretary", to: :secretary
        map_element "interest-to-committees", to: :interest_to_committees
        map_element "tc-sc-officers-note", to: :tc_sc_officers_note
      end

      key_value do
        map_element "horizontal", to: :horizontal
        map_element "stagename", to: :stagename
        map_element "updates_document_type", to: :updates_document_type
        map_element "fast_track", to: :fast_track
        map_element "price_code", to: :price_code
        map_element "function", to: :function
        map_element "accessibility_color_inside", to: :accessibility_color_inside
        map_element "cen_processing", to: :cen_processing
        map_element "secretary", to: :secretary
        map_element "interest_to_committees", to: :interest_to_committees
        map_element "tc_sc_officers_note", to: :tc_sc_officers_note
      end

      def get_schema_version = Relaton.schema_versions["relaton-model-iec"]
    end
  end
end
