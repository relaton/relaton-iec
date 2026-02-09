require "relaton/iec/data_fetcher"

describe Relaton::Iec::DataFetcher do
  context "instance methods" do
    subject { described_class.new("data", "xml") }

    context "#fetch" do
      before do
        allow(FileUtils).to receive(:mkdir_p).with("data")
      end

      it "all" do
        expect(FileUtils).to receive(:rm_rf).with "data"
        expect_any_instance_of(Relaton::Index::Type).to receive(:save).with(no_args)
        expect_any_instance_of(described_class).to receive(:fetch_all).with(no_args)
        expect_any_instance_of(described_class).to receive(:save_last_change).with(no_args)
        described_class.fetch "iec-harmonised-all"
      end

      it "latest" do
        expect(FileUtils).not_to receive(:rm_rf)
        expect_any_instance_of(Relaton::Index::Type).to receive(:save).with(no_args)
        expect_any_instance_of(described_class).to receive(:fetch_all).with no_args
        expect_any_instance_of(described_class).to receive(:save_last_change).with no_args
        described_class.fetch
      end

      it "catch error" do
        expect(subject).to receive(:fetch_all).with(no_args).and_raise "Error"
        expect_any_instance_of(Relaton::Index::Type).not_to receive(:save)
        expect { subject.fetch }.to output(/Error/).to_stderr_from_any_process
      end
    end

    context "#rebuild_index" do
      it "indexes YAML files from output directory" do
        files = ["data/file1.yaml", "data/file2.yaml"]
        expect(Dir).to receive(:glob).with("data/*.yaml").and_return files
        expect(subject).to receive(:add_file_to_index).with("data/file1.yaml")
        expect(subject).to receive(:add_file_to_index).with("data/file2.yaml")
        expect(Dir).to receive(:exist?).with("static").and_return false
        subject.send :rebuild_index
      end

      it "indexes static files when static directory exists" do
        expect(Dir).to receive(:glob).with("data/*.yaml").and_return ["data/file1.yaml"]
        expect(subject).to receive(:add_file_to_index).with("data/file1.yaml")
        expect(Dir).to receive(:exist?).with("static").and_return true
        expect(subject).to receive(:add_static_files_to_index).with(no_args)
        subject.send :rebuild_index
      end

      it "does not index static files when static directory does not exist" do
        expect(Dir).to receive(:glob).with("data/*.yaml").and_return []
        expect(Dir).to receive(:exist?).with("static").and_return false
        expect(subject).not_to receive(:add_static_files_to_index)
        subject.send :rebuild_index
      end
    end

    context "#add_file_to_index" do
      let(:file) { "data/iec-61058-2-4.yaml" }
      let(:yaml) { File.read("spec/fixtures/item.yaml", encoding: "UTF-8") }

      before do
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(file, encoding: "UTF-8").and_return yaml
      end

      it "adds file with primary docidentifier to index" do
        idx = double("index")
        allow(subject).to receive(:index).and_return idx
        expect(idx).to receive(:add_or_update).with(
          a_kind_of(Pubid::Iec::Base), file
        )
        subject.send :add_file_to_index, file
      end

      it "skips file without docidentifier" do
        item = Relaton::Iec::ItemData.new docidentifier: []
        allow(File).to receive(:read).with(file, encoding: "UTF-8").and_return item.to_yaml
        expect(subject).not_to receive(:index)
        subject.send :add_file_to_index, file
      end

      it "skips index update when pubid parsing fails" do
        docid = Relaton::Iec::Docidentifier.new content: "invalid", type: "IEC", primary: true
        item = Relaton::Iec::ItemData.new docidentifier: [docid]
        allow(File).to receive(:read).with(file, encoding: "UTF-8").and_return item.to_yaml
        idx = double("index")
        allow(subject).to receive(:index).and_return idx
        expect(idx).not_to receive(:add_or_update)
        expect { subject.send(:add_file_to_index, file) }.to output(
          /Failed to parse pubid/
        ).to_stderr_from_any_process
      end

      it "warns on error and continues" do
        allow(File).to receive(:read).with(file, encoding: "UTF-8").and_raise "read error"
        expect { subject.send(:add_file_to_index, file) }.to output(
          /Failed to index file `#{file}`: read error/
        ).to_stderr_from_any_process
      end
    end

    it "#add_static_files_to_index" do
      files = ["static/iec_123.yaml", "static/iec_456.yaml"]
      expect(Dir).to receive(:glob).with("static/*.yaml").and_return files
      expect(subject).to receive(:add_file_to_index).with("static/iec_123.yaml")
      expect(subject).to receive(:add_file_to_index).with("static/iec_456.yaml")
      subject.send :add_static_files_to_index
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
        subject.send :fetch_all
      end
    end

    it_should_behave_like "fetch_all", "200" # fetch
    it_should_behave_like "fetch_all", "502" # API error
    it_should_behave_like "fetch_all", "401" # refresh token

    shared_examples "fetch_page" do |last_change|
      it "#fetch_page" do
        url = "#{described_class::ENTRYPOINT}0"
        if last_change
          # expect(subject).to receive(:last_change).with(no_args).and_return(last_change).twice
          subject.instance_variable_set :@last_change, last_change
          subject.instance_variable_set :@last_change_max, last_change
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
        expect(subject.send(:fetch_page, 0)).to eq :resp
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
      expect(URI).to receive(:parse).with(described_class::CREDENTIAL).and_return uri
      req = double "Net::HTTP::Get"
      expect(req).to receive(:basic_auth).with("key", "secret")
      expect(Net::HTTP::Get).to receive(:new).with(uri).and_return req
      http = double("Net::HTTP")
      expect(http).to receive(:request).with(req).and_return double("response", body: '{"access_token":"token"}')
      expect(Net::HTTP).to receive(:start).with(:hostname, :port, use_ssl: true).and_yield http
      expect(subject.send(:access_token)).to eq "token"
    end

    context "#fetch_pub" do
      let(:pub) { JSON.parse File.read("spec/fixtures/pub.json", encoding: "UTF-8") }
      let(:bib) do
        docid = Relaton::Bib::Docidentifier.new content: "CISPR 11:2009/AMD1:2010", type: "IEC", primary: true
        Relaton::Iec::ItemData.new docidentifier: [docid]
      end

      before do
        allow_any_instance_of(Relaton::Iec::DataParser).to receive(:relation).and_return []
      end

      it "and save YAML" do
        subject.instance_variable_set :@format, "yaml"
        subject.instance_variable_set :@ext, "yaml"
        expect(File).to receive(:write).with(
          "data/iec-iso-1234-1-2.yaml", /docidentifier:\n- content: IEC\/ISO 1234-1-2/, encoding: "UTF-8"
        )
        subject.send :fetch_pub, pub
        expect(subject.instance_variable_get(:@files)).to include "data/iec-iso-1234-1-2.yaml"
      end

      it "and save XML" do
        expect(File).to receive(:write).with("data/iec-iso-1234-1-2.xml", /<bibdata/, encoding: "UTF-8")
        subject.send :fetch_pub, pub
      end

      xit "and save BibXML" do
        subject.instance_variable_set :@format, "bibxml"
        subject.instance_variable_set :@ext, "xml"
        expect(bib).to receive(:to_bibxml).with(no_args).and_return "<id='id'/>"
        expect(File).to receive(:write).with("data/cispr_11_2009_amd1_2010.xml", "<id='id'/>", encoding: "UTF-8")
        subject.send :fetch_pub, pub
      end

      it "warn if file exists" do
        subject.instance_variable_get(:@files) << "data/iec-iso-1234-1-2.xml"
        expect(File).to receive(:write).with("data/iec-iso-1234-1-2.xml", />IEC\/ISO 1234-1-2</, encoding: "UTF-8")
        expect { subject.send(:fetch_pub, pub) }.to output(
          include("relaton-iec] WARN: File data/iec-iso-1234-1-2.xml exists.")
        ).to_stderr_from_any_process
      end
    end

    context "#save_last_change" do
      it "writes last_change_max to file when not empty" do
        subject.instance_variable_set :@last_change_max, "2024-01-15T10:30:00Z"
        expect(File).to receive(:write).with(
          described_class::LAST_CHANGE_FILE, "2024-01-15T10:30:00Z", encoding: "UTF-8"
        )
        subject.send :save_last_change
      end

      it "does not write file when last_change_max is empty" do
        subject.instance_variable_set :@last_change_max, ""
        expect(File).not_to receive(:write)
        subject.send :save_last_change
      end

      it "does not write file when last_change_max is nil (converted to empty string)" do
        subject.instance_variable_set :@last_change, nil
        expect(File).not_to receive(:write)
        subject.send :save_last_change
      end
    end

    context "#find_primary_docidentifier" do
      it "returns docidentifier with primary flag" do
        primary = Relaton::Iec::Docidentifier.new content: "IEC 61058-2-4:1995", type: "IEC", primary: true
        other = Relaton::Iec::Docidentifier.new content: "urn:iec:std:iec:61058-2-4:1995", type: "URN"
        item = Relaton::Iec::ItemData.new docidentifier: [other, primary]
        result = subject.send(:find_primary_docidentifier, item)
        expect(result).to eq primary
      end

      it "falls back to IEC type when no primary" do
        iec = Relaton::Iec::Docidentifier.new content: "IEC 61058-2-4:1995", type: "IEC"
        urn = Relaton::Iec::Docidentifier.new content: "urn:iec:std:iec:61058-2-4:1995", type: "URN"
        item = Relaton::Iec::ItemData.new docidentifier: [urn, iec]
        result = subject.send(:find_primary_docidentifier, item)
        expect(result).to eq iec
      end

      it "falls back to first when no primary and no IEC type" do
        urn = Relaton::Iec::Docidentifier.new content: "urn:iec:std:iec:61058-2-4:1995", type: "URN"
        other = Relaton::Iec::Docidentifier.new content: "other-id", type: "OTHER"
        item = Relaton::Iec::ItemData.new docidentifier: [urn, other]
        result = subject.send(:find_primary_docidentifier, item)
        expect(result).to eq urn
      end

      it "returns nil when docidentifier list is empty" do
        item = Relaton::Iec::ItemData.new docidentifier: []
        result = subject.send(:find_primary_docidentifier, item)
        expect(result).to be_nil
      end
    end

    context "#parse_pubid" do
      it "parses valid IEC identifier" do
        pubid = subject.send(:parse_pubid, "IEC 60050-311:2001")
        expect(pubid.to_s).to eq "IEC 60050-311:2001"
        expect(pubid.number.to_s).to eq "60050"
        expect(pubid.part.to_s).to eq "311"
        expect(pubid.year).to eq 2001
      end

      it "returns nil for invalid identifier" do
        expect { subject.send(:parse_pubid, "invalid") }.to output(/Failed to parse pubid/).to_stderr_from_any_process
        result = subject.send(:parse_pubid, "invalid")
        expect(result).to be_nil
      end
    end
  end
end
