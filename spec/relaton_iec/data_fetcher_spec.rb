describe RelatonIec::DataFetcher do
  context "initialize" do
    it "with default options" do
      expect(subject.instance_variable_get(:@output)).to eq "data"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@all)).to eq false
    end

    it "with sertain options" do
      df = described_class.new "iec-harmonised-all", output: "dir", format: "bibxml"
      expect(df.instance_variable_get(:@output)).to eq "dir"
      expect(df.instance_variable_get(:@format)).to eq "bibxml"
      expect(df.instance_variable_get(:@ext)).to eq "xml"
      expect(df.instance_variable_get(:@files)).to eq []
      expect(df.instance_variable_get(:@all)).to eq true
    end
  end

  # it "feth data", vcr: "fetch_data" do
  #   subject.fetch
  # end

  context "instance methods" do
    let(:index) { subject.instance_variable_get(:@index) }

    context "#fetch" do
      before do
        expect(FileUtils).to receive(:mkdir_p).with("data")
      end

      it "all" do
        df = described_class.new "iec-harmonised-all"
        expect(FileUtils).to receive(:rm).with Dir["data/*.yaml"]
        idx = df.instance_variable_get(:@index)
        expect(idx).to receive(:clear).with no_args
        expect(idx).to receive(:save).with no_args
        expect(df).to receive(:fetch_all).with(no_args)
        expect(df).to receive(:add_static_files_to_index).with no_args
        df.fetch
      end

      it "latest" do
        expect(index).to receive(:save).with no_args
        expect(subject).to receive(:fetch_all).with no_args
        expect(subject).to receive(:add_static_files_to_index).with no_args
        subject.fetch
      end

      it "catch error" do
        expect(subject).to receive(:fetch_all).with(no_args).and_raise "Error"
        expect { subject.fetch }.to output(/Error/).to_stderr
      end
    end

    it "#add_static_files_to_index" do
      file = "static/iec_123.yaml"
      expect(Dir).to receive(:[]).with("static/*.yaml").and_return [file]
      expect(File).to receive(:read).with(file, encoding: "UTF-8").and_return :yaml
      pub = { "docid" => [{ "id" => "IEC 123", "primary" => true }] }
      expect(RelatonBib).to receive(:parse_yaml).with(:yaml).and_return pub
      subject.add_static_files_to_index
      expect(index.instance_variable_get(:@index)).to eq [{ pubid: "IEC 123", file: file }]
    end

    shared_examples "fetch_all" do |code|
      it "#fetch_all" do
        resp = double "response", body: '{"publication":["pub"]}'
        expect(resp).to receive(:code).and_return(code).twice
        expect(subject).to receive(:fetch_page).with(0).and_return resp
        if code == "401"
          expect(subject).to receive(:fetch_page).with(0).and_return resp
        end
        if code == "200"
          expect(resp).to receive(:code).and_return(code).twice
          subject.instance_variable_set :@fetch_all, false
          expect(resp).to receive(:[]).with("link").and_return "rel=\"last\"", nil
          expect(subject).to receive(:fetch_pub).with("pub").twice
          expect(subject).to receive(:fetch_page).with(1).and_return resp
        end
        subject.fetch_all
      end
    end

    it_should_behave_like "fetch_all", "200" # fetch 
    it_should_behave_like "fetch_all", "502" # API error
    it_should_behave_like "fetch_all", "401" # refresh token

    shared_examples "fetch_page" do |last_change|
      it "#fetch_page" do
        url = "#{RelatonIec::DataFetcher::ENTRYPOINT}0"
        if last_change
          expect(index).to receive(:last_change).with(no_args).and_return(last_change).twice
          subject.instance_variable_set :@fetch_all, false
          url += "&lastChangeTimestampFrom=#{last_change}"
        end
        uri = URI url
        req = double("Net::HTTP::Get")
        expect(subject).to receive(:access_token).and_return "token"
        expect(req).to receive(:[]=).with("Authorization", "Bearer token")
        expect(Net::HTTP::Get).to receive(:new).with(uri).and_return req
        http = double "Net::HTTP"
        expect(http).to receive(:request).with(req).and_return :resp
        expect(Net::HTTP).to receive(:start).with("api.iec.ch", 443, use_ssl: true).and_yield http
        expect(subject.fetch_page(0)).to eq :resp
      end
    end

    it_should_behave_like "fetch_page", nil # fetch all
    it_should_behave_like "fetch_page", "2015-04-09T09:30:10Z" # fetch latest

    it "#access_token" do
      expect(ENV).to receive(:fetch).with("IEC_HAPI_PROJ_PUBS_KEY").and_return "key"
      expect(ENV).to receive(:fetch).with("IEC_HAPI_PROJ_PUBS_SECRET").and_return "secret"
      allow(ENV).to receive(:fetch).and_call_original
      uri = double "uri"
      expect(uri).to receive(:hostname).and_return :hostname
      expect(uri).to receive(:port).and_return :port
      expect(URI).to receive(:parse).with(RelatonIec::DataFetcher::CREDENTIAL).and_return uri
      req = double "Net::HTTP::Get"
      expect(req).to receive(:basic_auth).with("key", "secret")
      expect(Net::HTTP::Get).to receive(:new).with(uri).and_return req
      http = double("Net::HTTP")
      expect(http).to receive(:request).with(req).and_return double("response", body: '{"access_token":"token"}')
      expect(Net::HTTP).to receive(:start).with(:hostname, :port, use_ssl: true).and_yield http
      expect(subject.access_token).to eq "token"
    end

    context "#fetch_pub" do
      let(:parser) { double "parser" }
      let(:pub) { { "lastChangeTimestamp" => "2015-04-09T09:30:10Z" } }
      let(:bib) do
        docid = double "docid", id: "CISPR 11:2009/AMD1:2010", type: "IEC", primary: true
        double "bib", docidentifier: [docid]
      end

      before do
        expect(parser).to receive(:parse).with(no_args).and_return bib
        expect(RelatonIec::DataParser).to receive(:new).with(pub).and_return parser
      end

      it "and save YAML" do
        expect(bib).to receive(:to_hash).and_return({ id: "id" })
        expect(File).to receive(:write).with("data/cispr_11_2009_amd1_2010.yaml", /id: id/, encoding: "UTF-8")
        expect(subject).to receive(:index_id).with(pub).and_return "CISPR 11:2009/AMD1:2010"
        index = subject.instance_variable_get :@index
        expect(index).to receive(:add).with("CISPR 11:2009/AMD1:2010", "data/cispr_11_2009_amd1_2010.yaml", pub["lastChangeTimestamp"])
        subject.fetch_pub pub
        expect(subject.instance_variable_get(:@files)).to eq ["data/cispr_11_2009_amd1_2010.yaml"]
      end

      it "and save XML" do
        subject.instance_variable_set :@format, "xml"
        subject.instance_variable_set :@ext, "xml"
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return("<id='id'/>")
        expect(File).to receive(:write).with("data/cispr_11_2009_amd1_2010.xml", "<id='id'/>", encoding: "UTF-8")
        subject.fetch_pub pub
      end

      it "and save BibXML" do
        subject.instance_variable_set :@format, "bibxml"
        subject.instance_variable_set :@ext, "xml"
        expect(bib).to receive(:to_bibxml).with(no_args).and_return "<id='id'/>"
        expect(File).to receive(:write).with("data/cispr_11_2009_amd1_2010.xml", "<id='id'/>", encoding: "UTF-8")
        subject.fetch_pub pub
      end

      it "warn if file exists" do
        subject.instance_variable_set :@files, ["data/cispr_11_2009_amd1_2010.yaml"]
        expect(bib).to receive(:to_hash).and_return({ id: "id" })
        expect(File).to receive(:write).with("data/cispr_11_2009_amd1_2010.yaml", /id: id/, encoding: "UTF-8")
        expect { subject.fetch_pub pub }.to output(/File data\/cispr_11_2009_amd1_2010\.yaml exists/).to_stderr
      end
    end

    context "#index_id" do
      let(:title) do
        "International Electrotechnical Vocabulary (IEV) - Part 300: Electrical and electronic " \
          "measurements and measuring instruments - Part 311: General terms relating to measurements "\
          "- Part 312: General terms relating to electrical measurements - Part 313: Types of electrical "\
          "measuring instruments - Part 314: Specific terms according to the type of instrument"
      end

      it "packaged standard" do
        pub = { "title" => [{ "value" => title }], "reference" => "IEC 60050-311:2001" }
        id = subject.index_id pub
        expect(id).to eq [
          "IEC 60050-300:2001", "IEC 60050-311:2001", "IEC 60050-312:2001",
          "IEC 60050-313:2001", "IEC 60050-314:2001"
        ]
      end

      it "not packaged standard" do
        pub = { "title" => [{ "value" => title }], "reference" => "IEC 60050-211:2001" }
        expect(subject.index_id(pub)).to eq "IEC 60050-211:2001"
      end

      it "no part" do
        pub = { "title" => [{ "value" => title }], "reference" => "IEC 60050:2001" }
        expect(subject.index_id(pub)).to eq "IEC 60050:2001"
      end
    end
  end
end
