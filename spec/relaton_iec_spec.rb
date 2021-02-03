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
    expect { RelatonIec::IecBibliography.search "60050", "2020" }
      .to raise_error RelatonBib::RequestError
  end

  it "fetch hits of page" do
    VCR.use_cassette "60050_102_2007" do
      hit_collection = RelatonIec::IecBibliography.search("60050", "2020")
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of RelatonIec::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of RelatonIec::Hit
      expect(hit_collection.to_s).to eq(
        "<RelatonIec::HitCollection:"\
        "#{format('%<id>#.14x', id: hit_collection.object_id << 1)} "\
        "@ref=60050 @fetched=true>"
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
    it "a code" do
      VCR.use_cassette "get_a_code" do
        results = RelatonIec::IecBibliography.get("IEC 60050-102").to_xml
        expect(results).to include '<bibitem id="IEC60050-102" type="standard">'
        expect(results).to include %(<on>2007-08-27</on>)
        expect(results.gsub(/<relation.*<\/relation>/m, "")).not_to include(
          %(<on>2007-08-27</on>)
        )
        expect(results).to include '<docidentifier type="IEC">'\
        "IEC 60050-102:2007</docidentifier>"
        expect(results).not_to include '<docidentifier type="IEC">'\
        "IEC 60050</docidentifier>"
      end
    end

    it "a reference with an year in a code" do
      VCR.use_cassette "get_a_code_with_year" do
        results = RelatonIec::IecBibliography.get("IEC 60050-102:2007").to_xml
        expect(results).to include %(<on>2007-08-27</on>)
        expect(results).to include(
          '<title type="title-part" format="text/plain" language="en" '\
          'script="Latn">Part 102: Mathematics -- General concepts and '\
          "linear algebra</title>"
        )
      end
    end

    it "a reference with an incorrect year" do
      VCR.use_cassette "get_a_code_with_incorrect_year" do
        expect do
          RelatonIec::IecBibliography.get("IEC 60050:2005")
        end.to output(/There was no match for 2005, though there were matches found for 1996/).to_stderr
      end
    end

    context "all parts" do
      it "by reference" do
        VCR.use_cassette "iec_80000_all_parts" do
          results = RelatonIec::IecBibliography.get "IEC 80000 (all parts)"
          expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
          expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:80000:::ser"
        end
      end

      it "by options" do
        VCR.use_cassette "iec_80000_all_parts" do
          results = RelatonIec::IecBibliography.get("IEC 80000", nil, { all_parts: true })
          expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
          expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:80000:::ser"
        end
      end

      it "IEC 61326:2020" do
        VCR.use_cassette "iec_61326_2020_all_parts" do
          result = RelatonIec::IecBibliography.get "IEC 61326:2020 (all parts)"
          expect(result.docidentifier[0].id).to eq "IEC 61326 RLV (all parts)"
          expect(result.relation.last.type).to eq "partOf"
          expect(result.relation.last.bibitem.formattedref.content).to eq "IEC 61326-2-6:2020"
        end
      end

      it "hint" do
        VCR.use_cassette "iec_61326" do
          expect do
            result = RelatonIec::IecBibliography.get "IEC 61326"
            expect(result.docidentifier[0].id).to eq "IEC 61326"
          end.to output(/WARNING: IEC 61326 found as IEC 61326:2002 but also contain parts/).to_stderr
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

    it "packaged standard" do
      VCR.use_cassette "packaged_standard" do
        results = RelatonIec::IecBibliography.get "IEC 60050-311"
        expect(results.docidentifier.first.id).to eq "IEC 60050-300"
      end
    end

    it "IEC 60027-1" do
      VCR.use_cassette "iec_60027_1" do
        result = RelatonIec::IecBibliography.get "IEC 60027-1"
        expect(result.docidentifier[0].id).to eq "IEC 60027-1"
      end
    end

    it "gets amendment" do
      VCR.use_cassette "iec_60050_102_amd_1" do
        bib = RelatonIec::IecBibliography.get "IEC 60050-102/Amd 1"
        expect(bib.docidentifier[0].id).to eq "IEC 60050-102/AMD1:2017"
      end
    end
  end

  context "covert" do
    context "to URN reference" do
      it "amedment" do
        urn = RelatonIec.code_to_urn "IEC 60050-102:2007/AMD1:2017"
        expect(urn).to eq "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
      end

      it "consolidation of amedments & deliverable" do
        urn = RelatonIec.code_to_urn "IEC 60034-1:1969+AMD1:1977+AMD2:1979+AMD3:1980 CSV", "en-fr"
        expect(urn).to eq "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:plus:amd:2:1979:plus:amd:3:1980"
      end

      it "with type" do
        urn = RelatonIec.code_to_urn "IEC TS 60034-16-3:1996", "fr"
        expect(urn).to eq "urn:iec:std:iec:60034-16-3:1996:ts::fr"
      end
    end

    context "to reference form URN" do
      it "amendment" do
        ref = RelatonIec.urn_to_code "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
        expect(ref).to eq ["IEC 60050-102:2007/AMD1:2017", ""]
      end

      it "consolidation of amedments & deliverable" do
        ref = RelatonIec.urn_to_code "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:"\
          "plus:amd:2:1979:plus:amd:3:1980"
        expect(ref).to eq ["IEC 60034-1:1969+AMD1:1977+AMD2:1979+AMD3:1980 CSV", "en-fr"]
      end

      it "with type" do
        ref = RelatonIec.urn_to_code "urn:iec:std:iec:60034-16-3:1996:ts::fr"
        expect(ref).to eq ["IEC TS 60034-16-3:1996", "fr"]
      end
    end
  end
end
