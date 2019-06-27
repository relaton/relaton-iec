RSpec.describe RelatonIec::Scrapper do
  it "follow http redirect" do
    resp = double "response"
    expect(resp).to receive(:code).and_return "301"
    expect(resp).to receive(:body).and_return "<html><body></body></html>"
    expect(resp).to receive(:[]).with("location").and_return "/new_path"
    expect(Net::HTTP).to receive(:get_response).and_return resp
    uri = URI RelatonIec::Scrapper::DOMAIN + "/new_path"
    expect(Net::HTTP).to receive(:get_response).with(uri).and_return resp
    RelatonIec::Scrapper.send(:get_page, RelatonIec::Scrapper::DOMAIN + "/path")
  end

  it "returns default structured identifier" do
    doc = Nokogiri::HTML "<html><body></body></html>"
    result = RelatonIec::Scrapper.send(:fetch_structuredidentifier, doc)
    expect(result).to be_instance_of RelatonIsoBib::StructuredIdentifier
  end

  context "returns relation" do
    it "obsoletes" do
      status = double text: "Withdrawn"
      relation = double
      expect(relation).to receive(:at).with("STATUS").and_return status
      name = double text: "Name"
      expect(relation).to receive(:at).with("FULL_NAME").and_return name
      doc = double xpath: [relation]
      result = RelatonIec::Scrapper.send :fetch_relations, doc
      expect(result.first[:type]).to eq "obsoletes"
    end

    it "other" do
      status = double text: "Other"
      relation = double
      expect(relation).to receive(:at).with("STATUS").and_return status
      name = double text: "Name"
      expect(relation).to receive(:at).with("FULL_NAME").and_return name
      doc = double xpath: [relation]
      result = RelatonIec::Scrapper.send :fetch_relations, doc
      expect(result.first[:type]).to eq "other"
    end
  end

  context "returns title" do
    it "with no parts" do
      hit_data = { title: "" }
      title = RelatonIec::Scrapper.send :fetch_titles, hit_data
      expect(title.first[:title_main]).to eq ""
    end

    it "with main part" do
      hit_data = { title: "Main" }
      title = RelatonIec::Scrapper.send :fetch_titles, hit_data
      expect(title.first[:title_main]).to eq "Main"
    end

    it "with extra parts" do
      hit_data = { title: "Intro - Main - Part - Extra" }
      title = RelatonIec::Scrapper.send :fetch_titles, hit_data
      expect(title.first[:title_part]).to eq "Part -- Extra"
    end
  end

  it "returns ISO contributor" do
    result = RelatonIec::Scrapper.send :fetch_contributors, "ISO 123"
    expect(result.first[:entity][:name]).to eq "International Organization for Standardization"
  end

  it "returns copyright with release date" do
    doc = double
    expect(doc).to receive(:xpath).and_return double(text: "2018")
    result = RelatonIec::Scrapper.send :fetch_copyright, "IEC 123", doc
    expect(result[:from]).to eq "2018"
  end

  context "raises error" do
    it "could not access" do
      expect(Net::HTTP).to receive(:get_response).and_raise SocketError
      expect do
        RelatonIec::Scrapper.parse_page url: "https://webstore.iec.ch/searchkey&RefNbr=1234"
      end.to raise_error RelatonBib::RequestError
    end

    it "page not found" do
      resp = double
      expect(resp).to receive(:code).and_return "404"
      expect(Net::HTTP).to receive(:get_response).and_return resp
      expect do
        RelatonIec::Scrapper.parse_page url: "https://webstore.iec.ch/searchkey&RefNbr=1234"
      end.to raise_error RelatonBib::RequestError
    end
  end
end
