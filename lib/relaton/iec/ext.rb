require_relative "doctype"
require_relative "stage_name"

module Relaton
  module Iec
    class Ext < Lutaml::Model::Serializable
      attribute :schema_version, :string
      attribute :doctype, Doctype
      attribute :subdoctype, :string, values: %w[specification method-of-test vocabulary code-of-practice]
      attribute :flavor, :string
      attribute :horizontal, :boolean
      attribute :function, :string, values: %w[emc safety environment quality-assurance]
      attribute :editorialgroup, Iso::ISOProjectGroup
      attribute :ics, Bib::ICS, collection: true
      attribute :structuredidentifier, Iso::StructuredIdentifier
      attribute :stagename, StageName
      attribute :updates_document_type, :string, values: Doctype::TYPES
      attribute :price_code, :string
      attribute :accessibility_color_inside, :boolean
      attribute :cen_processing, :boolean
      attribute :secretary, :string
      attribute :interest_to_committees, :string
      attribute :tc_sc_officers_note, :string, raw: true

      xml do
        map_attribute "schema-version", to: :schema_version
        map_element "doctype", to: :doctype
        map_element "subdoctype", to: :subdoctype
        map_element "flavor", to: :flavor
        map_element "horizontal", to: :horizontal
        map_element "function", to: :function
        map_element "editorialgroup", to: :editorialgroup
        map_element "ics", to: :ics
        map_element "structuredidentifier", to: :structuredidentifier
        map_element "stagename", to: :stagename
        map_element "updates-document-type", to: :updates_document_type
        map_element "price-code", to: :price_code
        map_element "accessibility-color-inside", to: :accessibility_color_inside
        map_element "cen-processing", to: :cen_processing
        map_element "secretary", to: :secretary
        map_element "interest-to-committees", to: :interest_to_committees
        map_element "tc-sc-officers-note", to: :tc_sc_officers_note
      end
    end
  end
end
