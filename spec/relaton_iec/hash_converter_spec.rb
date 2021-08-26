RSpec.describe RelatonIec::HashConverter do
  it "create item form YAML" do
    hash = YAML.load_file "spec/examples/hit.yaml"
    item = RelatonIec::IecBibliographicItem.from_hash hash
    expect(item.to_hash).to eq hash
  end

  it "convert relation" do
    hash = {
      "id" => "IEC1",
      "title" => ["content" => "Title content"],
      "relation" => [{
        "type" => "updates",
        "bibitem" => { "formattedref" => "ref" },
      }],
    }
    item_hash = RelatonIec::HashConverter.hash_to_bib hash
    item = RelatonIec::IecBibliographicItem.new(**item_hash)
    expect(item.relation.first.bibitem.formattedref.content).to eq "ref"
  end
end
