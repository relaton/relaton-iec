# frozen_string_literal: true

RSpec.describe Relaton::Iec do
  before do
    # Force to download index file
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  it "has a version number" do
    expect(described_class::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = described_class.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  it "raise access error" do
    exception_io = double("io")
    expect(Relaton::Iec::HitCollection).to receive(:new).and_raise(
      SocketError.new("Connection failed"),
    )
    pubid = Pubid::Iec::Identifier.parse("IEC 60050:2020")
    expect { Relaton::Iec::Bibliography.search pubid }
      .to raise_error Relaton::RequestError
  end

  it "fetch hits of page" do
    VCR.use_cassette "60050_102_2007" do
      pubid = Pubid::Iec::Identifier.parse("IEC 60050-102:2007")
      hit_collection = Relaton::Iec::Bibliography.search(pubid)
      expect(hit_collection.fetched).to be false
      expect(hit_collection.fetch).to be_instance_of Relaton::Iec::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of Relaton::Iec::Hit
      expect(hit_collection.to_s).to eq(
        "<Relaton::Iec::HitCollection:"\
        "#{format('%<id>#.14x', id: hit_collection.object_id << 1)} " \
        "@ref=IEC 60050-102:2007 @fetched=true>",
      )
    end
  end

  it "return xml of hit" do
    VCR.use_cassette "61058_2_4_2018" do
      pubid = Pubid::Iec::Identifier.parse("IEC 61058-2-4:2018")
      # Search with exclude: [] to match exact year
      hits = Relaton::Iec::Bibliography.search(pubid, exclude: [])
      expect(hits.first).to be_instance_of Relaton::Iec::Hit
      file = "spec/fixtures/iec_61058_2_4_2018.xml"
      xml = hits.first.item.to_xml(bibdata: true)
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to include '<docidentifier type="IEC" primary="true">IEC 61058-2-4:2018</docidentifier>'
      schema = Jing.new "grammars/relaton-iec-compile.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end
  end

  it "return string of hit" do
    VCR.use_cassette "60050_101_1998" do
      pubid = Pubid::Iec::Identifier.parse("IEC 60050-101:1998")
      # Search with exclude: [] to match exact year
      hits = Relaton::Iec::Bibliography.search(pubid, exclude: []).fetch
      expect(hits.first).to be_instance_of Relaton::Iec::Hit
      expect(hits.first.hit[:id].to_s).to eq "IEC 60050-101:1998"
    end
  end

  describe "get" do
    it "a code", vcr: "get_a_code" do
      expect do
        results = Relaton::Iec::Bibliography.get("IEC 60050-102:2007").to_xml
        expect(results).to include '<bibitem id="IEC600501022007" type="standard" schema-version="v1.4.1">'
        expect(results).to include(
          '<docidentifier type="IEC" primary="true">IEC 60050-102:2007</docidentifier>',
        )
        expect(results).not_to include(
          '<docidentifier type="IEC" primary="true">IEC 60050</docidentifier>',
        )
      end.to output(
        /\[relaton-iec\] INFO: \(IEC 60050-102:2007\) Fetching from Relaton repsitory .../,
      ).to_stderr_from_any_process
    end

    it "a reference with an year in a code" do
      VCR.use_cassette "get_a_code_with_year" do
        item = Relaton::Iec::Bibliography.get("IEC 60050-102:2007")
        expect(item.docidentifier.first.content).to eq "IEC 60050-102:2007"
      end
    end

    it "a reference with an incorrect year" do
      VCR.use_cassette "get_a_code_with_incorrect_year" do
        expect do
          Relaton::Iec::Bibliography.get("IEC 60050-111:2005")
        end.to output(
          /TIP: No match for edition year `2005`, but matches exist for/
        ).to_stderr_from_any_process
      end
    end

    it "latest year when year is not specified", vcr: "get_last_year" do
      result = Relaton::Iec::Bibliography.get("IEC 61332")
      expect(result.docidentifier.first.content).to eq "IEC 61332"
      istance = result.relation.detect { |r| r.type == "instanceOf" }
      expect(istance.bibitem.docidentifier.first.content).to eq "IEC 61332:2026"
    end

    context "all parts" do
      it "by reference", vcr: "iec_80000_all_parts" do
        results = Relaton::Iec::Bibliography.get "IEC 80000 (all parts)"
        expect(results.docidentifier.first.content).to eq "IEC 80000 (all parts)"
        expect(results.docidentifier.last.content).to eq "urn:iec:std:iec:80000:::ser"
      end

      it "by options", vcr: "iec_80000_all_parts" do
        results = Relaton::Iec::Bibliography.get("IEC 80000", nil, { all_parts: true })
        expect(results.docidentifier.first.content).to eq "IEC 80000 (all parts)"
        expect(results.docidentifier.last.content).to eq "urn:iec:std:iec:80000:::ser"
      end

      it "IEC 61326:2020" do
        VCR.use_cassette "iec_61326_2020_all_parts" do
          result = Relaton::Iec::Bibliography.get "IEC 61326:2020 (all parts)"
          expect(result.docidentifier[0].content).to eq "IEC 61326 (all parts)"
          expect(result.relation.last.type).to eq "partOf"
          # Note: pubid serialization doesn't include delivery format (RLV)
          expect(result.relation.last.bibitem.formattedref).to include "IEC 61326-2-6:2020"
        end
      end

      it "reference without year", vcr: "without_year" do
        bib = Relaton::Iec::Bibliography.get "IEC PAS 62596"
        expect(bib.docidentifier.first.content).to eq "IEC PAS 62596"
      end

      it "hint" do
        VCR.use_cassette "iec_61326" do
          # With pubid-based search, IEC 61326 is found (as IEC 61326:2002)
          # The tip about all parts would only show if no match is found
          result = Relaton::Iec::Bibliography.get "IEC 61326"
          expect(result).not_to be_nil
          expect(result.docidentifier[0].content).to include "IEC 61326"
        end
      end
    end

    it "warns when resource with part number not found on IEC website" do
      VCR.use_cassette "varn_part_num_not_found" do
        expect { Relaton::Iec::Bibliography.get("IEC 60050-103", "207", {}) }
          .to output(
            /TIP: No match for edition year `207`, but matches exist for/,
          ).to_stderr_from_any_process
      end
    end

    it "suggests all parts when reference without part number not found" do
      VCR.use_cassette "code_without_part_not_found" do
        result = Relaton::Iec::Bibliography.get("IEC 99999", "2020", {})
        expect(result).to be_nil
      end
    end

    it "suggests doctype abbreviations when reference not found" do
      VCR.use_cassette "code_without_part_not_found" do
        result = Relaton::Iec::Bibliography.get("IEC 99999", "2020", {})
        expect(result).to be_nil
      end
    end

    it "gets a frozen reference for IEV" do
      results = Relaton::Iec::Bibliography.get("IEV", nil, {})
      expect(results.to_xml).to include '<bibitem id="IEC600502011" ' \
                                        'type="standard" schema-version="v1.4.1">'
    end

    it "IEC 60027-1" do
      VCR.use_cassette "iec_60027_1" do
        result = Relaton::Iec::Bibliography.get "IEC 60027-1:1992"
        expect(result.docidentifier[0].content).to eq "IEC 60027-1:1992"
      end
    end

    it "gets amendment" do
      VCR.use_cassette "iec_60050_102_amd_1" do
        bib = Relaton::Iec::Bibliography.get "IEC 60050-102:2007/Amd1:2017"
        expect(bib.docidentifier[0].content).to eq "IEC 60050-102:2007/AMD1:2017"
      end
    end

    it "CISPR" do
      VCR.use_cassette "cispr_32_2015" do
        bib = Relaton::Iec::Bibliography.get "CISPR 32:2015"
        expect(bib.docidentifier[0].content).to eq "CISPR 32:2015"
      end
    end

    it "IEC TR 62547" do
      VCR.use_cassette "iec_tr_62547" do
        bib = Relaton::Iec::Bibliography.get "IEC TR 62547"
        expect(bib.docidentifier[0].content).to eq "IEC TR 62547"
      end
    end

    it "IEC 61360-4 DB" do
      VCR.use_cassette "iec_61360_4_db" do
        bib = Relaton::Iec::Bibliography.get "IEC 61360-4 DB"
        expect(bib.docidentifier[0].content).to eq "IEC 61360-4 DB"
      end
    end

    it "ISO/IEC DIR 1 IEC SUP" do
      VCR.use_cassette "iso_iec_dir_1_sup" do
        bib = Relaton::Iec::Bibliography.get "ISO/IEC DIR 1 IEC SUP"
        expect(bib.docidentifier[0].content).to eq "ISO/IEC DIR 1 IEC SUP"
      end
    end

    it "ISO/IEC DIR 2 IEC" do
      VCR.use_cassette "iso_iec_dir_2_iec" do
        bib = Relaton::Iec::Bibliography.get "ISO/IEC DIR 2 IEC"
        expect(bib.docidentifier[0].content).to eq "ISO/IEC DIR 2 IEC"
      end
    end

    it "ISO/IEC DIR IEC SUP" do
      VCR.use_cassette "iso_iec_dir_iec_sup" do
        bib = Relaton::Iec::Bibliography.get "ISO/IEC DIR IEC SUP"
        expect(bib.docidentifier[0].content).to eq "ISO/IEC DIR IEC SUP"
      end
    end
  end

  context "#provide_tips" do
    def make_hit(pubid_str)
      id = Pubid::Iec::Identifier.parse(pubid_str)
      double("hit", hit: { id: id })
    end

    it "tips about year mismatch" do
      pubid = Pubid::Iec::Identifier.parse("IEC 60050-102:2005")
      result = [make_hit("IEC 60050-102:2007"), make_hit("IEC 60050-102:2017")]
      expect { Relaton::Iec::Bibliography.send(:provide_tips, pubid, result) }.to output(
        /TIP: No match for edition year `2005`, but matches exist for `2007`, `2017`/
      ).to_stderr_from_any_process
    end

    it "tips about available parts" do
      pubid = Pubid::Iec::Identifier.parse("IEC 61326")
      result = []
      broad = [make_hit("IEC 61326-1:2020"), make_hit("IEC 61326-2-1:2020")]
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year part]).and_return(broad)
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year type]).and_return([])
      expect { Relaton::Iec::Bibliography.send(:provide_tips, pubid, result) }.to output(
        /TIP: If you wish to cite all document parts/
      ).to_stderr_from_any_process
    end

    it "tips about type mismatch" do
      pubid = Pubid::Iec::Identifier.parse("IEC TS 61058-2-4:1995")
      result = []
      broad_part = []
      type_broad = [make_hit("IEC 61058-2-4:1995")]
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year part]).and_return(broad_part)
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year type]).and_return(type_broad)
      expect { Relaton::Iec::Bibliography.send(:provide_tips, pubid, result) }.to output(
        /TIP: No match for type, but matches exist/
      ).to_stderr_from_any_process
    end

    it "outputs only 'Not found' when no tips apply" do
      pubid = Pubid::Iec::Identifier.parse("IEC 99999-1:2020")
      result = []
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year part]).and_return([])
      allow(Relaton::Iec::Bibliography).to receive(:search)
        .with(pubid, exclude: %i[year type]).and_return([])
      expect { Relaton::Iec::Bibliography.send(:provide_tips, pubid, result) }.to output(
        /Not found/
      ).to_stderr_from_any_process
    end
  end

  context "convert" do
    context "form reference to URN" do
      it "amedment" do
        urn = Relaton::Iec.code_to_urn "IEC 60050-102:2007/AMD1:2017"
        expect(urn).to eq "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
      end

      it "consolidation of amedments & deliverable" do
        urn = Relaton::Iec.code_to_urn "IEC 60034-1:1969+AMD1:1977+AMD2:1979+AMD3:1980 CSV", "en-fr"
        expect(urn).to eq "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:plus:amd:2:1979:plus:amd:3:1980"
      end

      it "with type" do
        urn = Relaton::Iec.code_to_urn "IEC TS 60034-16-3:1996", "fr"
        expect(urn).to eq "urn:iec:std:iec:60034-16-3:1996:ts::fr"
      end
    end

    context "form URN to reference" do
      it "amendment" do
        ref = Relaton::Iec.urn_to_code "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
        expect(ref).to eq ["IEC 60050-102:2007/AMD1:2017", ""]
      end

      it "consolidation of amedments & deliverable" do
        ref = Relaton::Iec.urn_to_code "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:" \
                                     "plus:amd:2:1979:plus:amd:3:1980"
        expect(ref).to eq ["IEC 60034-1:1969+AMD1:1977+AMD2:1979+AMD3:1980 CSV", "en-fr"]
      end

      it "with type" do
        ref = Relaton::Iec.urn_to_code "urn:iec:std:iec:60034-16-3:1996:ts::fr"
        expect(ref).to eq ["IEC TS 60034-16-3:1996", "fr"]
      end
    end
  end
end
