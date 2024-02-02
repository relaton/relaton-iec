RSpec.describe RelatonIec::XMLParser do
  it "create bibitem from XML" do
    xml = File.read "spec/examples/hit.xml", encoding: "UTF-8"
    item = RelatonIec::XMLParser.from_xml xml
    expect(item).to be_instance_of RelatonIec::IecBibliographicItem
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "create_doctype" do
    xml = Nokogiri::XML(<<~XML).at "doctype"
      <doctype abbreviation="SRD">system-reference-deliverable</doctype>
    XML
    expect do
      doctype = described_class.send :create_doctype, xml
      expect(doctype).to be_instance_of RelatonIec::DocumentType
      expect(doctype.type).to eq "system-reference-deliverable"
      expect(doctype.abbreviation).to eq "SRD"
    end.not_to output(/Invalid doctype/).to_stderr_from_any_process
  end
end
