RSpec.describe RelatonIec::XMLParser do
  it "create bibitem from XML" do
    xml = File.read "spec/examples/hit.xml", encoding: "UTF-8"
    item = RelatonIec::XMLParser.from_xml xml
    expect(item).to be_instance_of RelatonIec::IecBibliographicItem
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end
end
