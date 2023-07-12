RSpec.describe RelatonIec::IecBibliographicItem do
  it "XML serialize" do
    file = "spec/examples/bibdata.xml"
    hash = YAML.load_file "spec/examples/hit.yaml"
    bib = RelatonIec::IecBibliographicItem.from_hash hash
    xml = bib.to_xml bibdata: true
    File.write file, xml, encoding: "UTF-8" unless File.exist? file
    expect(xml).to be_equivalent_to File.read file, encoding: "UTF-8"
  end

  it "warn if function is invalid" do
    expect do
      RelatonIec::IecBibliographicItem.new function: "invalid"
    end.to output(/invalid function "invalid"/).to_stderr
  end

  it "warn if updates_document_type is invalid" do
    expect do
      RelatonIec::IecBibliographicItem.new updates_document_type: "invalid"
    end.to output(/invalid updates_document_type "invalid"/).to_stderr
  end

  it "not warn if doctype is valid" do
    expect do
      RelatonIec::IecBibliographicItem.new doctype: "system-reference-deliverable"
    end.not_to output.to_stderr
  end
end
