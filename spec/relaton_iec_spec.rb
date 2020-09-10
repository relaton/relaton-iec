# frozen_string_literal: true

require "open-uri"
require "jing"

RSpec.describe RelatonIec do
  it "has a version number" do
    expect(RelatonIec::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonIec.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  it "raise access error" do
    exception_io = double("io")
    expect(OpenURI).to receive(:open_uri).and_raise(
      OpenURI::HTTPError.new("", exception_io)
    )
    expect { RelatonIec::IecBibliography.search "60050-102", "2007" }
      .to raise_error RelatonBib::RequestError
  end

  it "fetch hits of page" do
    VCR.use_cassette "60050_102_2007" do
      hit_collection = RelatonIec::IecBibliography.search("60050-102", "2007")
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of RelatonIec::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of RelatonIec::Hit
      expect(hit_collection.to_s).to eq(
        "<RelatonIec::HitCollection:"\
        "#{format('%<id>#.14x', id: hit_collection.object_id << 1)} "\
        "@ref=60050-102 @fetched=true>"
      )
    end
  end

  it "return xml of hit" do
    VCR.use_cassette "61058_2_4_2003" do
      hits = RelatonIec::IecBibliography.search("61058-2-4", "2003")
      result = hits.first.to_xml(bibdata: true)
      file_path = "spec/examples/hit.xml"
      unless File.exist? file_path
        File.open(file_path, "w:UTF-8") do |f|
          f.write result
        end
      end
      expect(result).to be_equivalent_to File.read(file_path, encoding: "utf-8")
        .sub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      schema = Jing.new "spec/examples/isobib.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end
  end

  it "return string of hit" do
    VCR.use_cassette "60050_101_1998" do
      hits = RelatonIec::IecBibliography.search("60050-101", "1998").fetch
      expect(hits.first.to_s).to eq "<RelatonIec::Hit:"\
        "#{format('%<id>#.14x', id: hits.first.object_id << 1)} "\
        '@text="60050-101" @fetched="true" '\
        '@fullIdentifier="IEC60050-101-1998:1998" @title="IEC 60050-101:1998">'
    end
  end

  describe "get" do
    it "gets a code" do
      VCR.use_cassette "get_a_code" do
        results = RelatonIec::IecBibliography.get("IEC 60050-102").to_xml
        expect(results).to include '<bibitem id="IEC60050-102" type="standard">'
        expect(results).to include %(<on>2007</on>)
        expect(results.gsub(/<relation.*<\/relation>/m, "")).not_to include(
          %(<on>2007</on>)
        )
        expect(results).to include '<docidentifier type="IEC">'\
        "IEC 60050-102:2007</docidentifier>"
        expect(results).not_to include '<docidentifier type="IEC">'\
        "IEC 60050</docidentifier>"
      end
    end

    it "gets a reference with an year in a code" do
      VCR.use_cassette "get_a_code_with_year" do
        results = RelatonIec::IecBibliography.get("IEC 60050-102:2007").to_xml
        expect(results).to include %(<on>2007</on>)
        expect(results).to include(
          '<title type="title-part" format="text/plain" language="en" '\
          'script="Latn">Part 102: Mathematics -- General concepts and '\
          "linear algebra</title>"
        )
      end
    end

    context "gets all parts" do
      it "by reference" do
        VCR.use_cassette "iec_80000_all_parts" do
          results = RelatonIec::IecBibliography.get "IEC 80000 (all parts)"
          expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
          expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:"\
          "80000:::ser"
        end
      end

      it "by options" do
        VCR.use_cassette "iec_80000_all_parts" do
          results = RelatonIec::IecBibliography.get(
            "IEC 80000", nil, { all_parts: true }
          )
          expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
          expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:"\
          "80000:::ser"
        end
      end
    end

    it "warns when resource with part number not found on IEC website" do
      VCR.use_cassette "varn_part_num_not_found" do
        expect { RelatonIec::IecBibliography.get("IEC 60050-103", "207", {}) }
          .to output(
            /The provided document part may not exist, or the document may no |
            longer be published in parts/
          ).to_stderr
      end
    end

    it "gets a frozen reference for IEV" do
      results = RelatonIec::IecBibliography.get("IEV", nil, {})
      expect(results.to_xml).to include '<bibitem id="IEC60050-2011" '\
      'type="standard">'
    end
  end
end
