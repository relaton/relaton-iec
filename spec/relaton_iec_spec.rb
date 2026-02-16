# frozen_string_literal: true

RSpec.describe RelatonIec do
    before do |example|
    next if example.metadata[:skip_before]

    # Force to download index file
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  it "has a version number" do
    expect(RelatonIec::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonIec.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  it "raise access error" do
    expect(RelatonIec::HitCollection).to receive(:new).and_raise(
      SocketError.new("Connection refused"),
    )
    pubid = Pubid::Iec::Identifier.parse("IEC 60050")
    expect { RelatonIec::IecBibliography.search pubid }
      .to raise_error RelatonBib::RequestError
  end

  it "fetch hits of page" do
    VCR.use_cassette "60050_102_2007" do
      pubid = Pubid::Iec::Identifier.parse("IEC 60050-102")
      hit_collection = RelatonIec::IecBibliography.search(pubid)
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of RelatonIec::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of RelatonIec::Hit
      expect(hit_collection.to_s).to eq(
        "<RelatonIec::HitCollection:"\
        "#{format('%<id>#.14x', id: hit_collection.object_id << 1)} " \
        "@ref=IEC 60050-102 @fetched=true>",
      )
    end
  end

  it "return xml of hit" do
    VCR.use_cassette "61058_2_4_2018" do
      pubid = Pubid::Iec::Identifier.parse("IEC 61058-2-4:2018")
      hits = RelatonIec::IecBibliography.search(pubid, exclude: [])
      result = hits.first.to_xml(bibdata: true)
      file_path = "spec/examples/hit.xml"
      unless File.exist? file_path
        File.open(file_path, "w:UTF-8") do |f|
          f.write result
        end
      end
      expect(result).to be_equivalent_to File.read(file_path, encoding: "utf-8")
        .sub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      schema = Jing.new "grammars/relaton-iec-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end
  end

  it "return string of hit" do
    VCR.use_cassette "60050_101_1998" do
      pubid = Pubid::Iec::Identifier.parse("IEC 60050-101:1998")
      hits = RelatonIec::IecBibliography.search(pubid, exclude: []).fetch
      expect(hits.first.to_s).to eq(
        "<RelatonIec::Hit:" \
        "#{format('%<id>#.14x', id: hits.first.object_id << 1)} " \
        '@text="IEC 60050-101:1998" @fetched="true" ' \
        '@fullIdentifier="IEC60050-101-1998" @title="IEC 60050-101:1998">',
      )
    end
  end

  describe "get" do
    it "a code", vcr: "get_a_code" do
      expect do
        results = RelatonIec::IecBibliography.get("IEC 60050-102:2007").to_xml
        expect(results).to include '<bibitem id="IEC60050-102-2007" type="standard" schema-version="v1.2.9">'
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
        results = RelatonIec::IecBibliography.get("IEC 60050-102:2007").to_xml
        expect(results).to include(
          '<title type="main" format="text/plain" language="en" ' \
          'script="Latn">International Electrotechnical Vocabulary (IEV) - ' \
          "Part 102: Mathematics -- General concepts and linear algebra</title>",
        )
      end
    end

    it "a reference with an incorrect year" do
      VCR.use_cassette "get_a_code_with_incorrect_year" do
        expect do
          RelatonIec::IecBibliography.get("IEC 60050-111:2005")
        end.to output(
          /TIP: No match for edition year `2005`, but matches exist for `1996`/
        ).to_stderr_from_any_process
      end
    end

    it "latest year when year is not specified", vcr: "get_last_year" do
      result = RelatonIec::IecBibliography.get("IEC 61332")
      expect(result.docidentifier.first.id).to eq "IEC 61332"
      istance = result.relation.detect { |r| r.type == "instanceOf" }
      expect(istance.bibitem.docidentifier.first.id).to eq "IEC 61332:2026"
    end

    context "all parts" do
      it "by reference", vcr: "iec_80000_all_parts" do
        results = RelatonIec::IecBibliography.get "IEC 80000 (all parts)"
        expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
        expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:80000:::ser"
      end

      it "by options", vcr: "iec_80000_all_parts" do
        results = RelatonIec::IecBibliography.get("IEC 80000", nil, { all_parts: true })
        expect(results.docidentifier.first.id).to eq "IEC 80000 (all parts)"
        expect(results.docidentifier.last.id).to eq "urn:iec:std:iec:80000:::ser"
      end

      it "IEC 61326:2020" do
        VCR.use_cassette "iec_61326_2020_all_parts" do
          result = RelatonIec::IecBibliography.get "IEC 61326:2020 (all parts)"
          expect(result.docidentifier[0].id).to eq "IEC 61326 (all parts)"
          expect(result.relation.last.type).to eq "partOf"
          expect(result.relation.last.bibitem.formattedref.content).to eq "IEC 61326-2-6:2020"
        end
      end

      it "reference without year", vcr: "without_year" do
        bib = RelatonIec::IecBibliography.get "IEC PAS 62596"
        expect(bib.docidentifier.first.id).to eq "IEC PAS 62596"
      end
    end

    it "IEC 61326 without parts" do
      VCR.use_cassette "iec_61326" do
        result = RelatonIec::IecBibliography.get "IEC 61326"
        expect(result.docidentifier[0].id).to eq "IEC 61326"
      end
    end

    it "gets a frozen reference for IEV" do
      results = RelatonIec::IecBibliography.get("IEV", nil, {})
      expect(results.to_xml).to include '<bibitem id="IEC60050-2011" ' \
                                        'type="standard" schema-version="v1.2.9">'
    end

    it "IEC 60027-1" do
      VCR.use_cassette "iec_60027_1" do
        result = RelatonIec::IecBibliography.get "IEC 60027-1:1992"
        expect(result.docidentifier[0].id).to eq "IEC 60027-1:1992"
      end
    end

    it "gets amendment" do
      VCR.use_cassette "iec_60050_102_amd_1" do
        bib = RelatonIec::IecBibliography.get "IEC 60050-102:2007/Amd1:2017"
        expect(bib.docidentifier[0].id).to eq "IEC 60050-102:2007/AMD1:2017"
      end
    end

    it "CISPR" do
      VCR.use_cassette "cispr_32_2015" do
        bib = RelatonIec::IecBibliography.get "CISPR 32:2015"
        expect(bib.docidentifier[0].id).to eq "CISPR 32:2015"
      end
    end

    it "IEC TR 62547" do
      VCR.use_cassette "iec_tr_62547" do
        bib = RelatonIec::IecBibliography.get "IEC TR 62547"
        expect(bib.docidentifier[0].id).to eq "IEC TR 62547"
      end
    end

    it "IEC 61360-4 DB" do
      VCR.use_cassette "iec_61360_4_db" do
        bib = RelatonIec::IecBibliography.get "IEC 61360-4 DB"
        expect(bib.docidentifier[0].id).to eq "IEC 61360-4 DB"
      end
    end

    it "ISO/IEC DIR 1 IEC SUP" do
      VCR.use_cassette "iso_iec_dir_1_sup" do
        bib = RelatonIec::IecBibliography.get "ISO/IEC DIR 1 IEC SUP"
        expect(bib.docidentifier[0].id).to eq "ISO/IEC DIR 1 IEC SUP"
      end
    end

    it "ISO/IEC DIR 2 IEC" do
      VCR.use_cassette "iso_iec_dir_2_iec" do
        bib = RelatonIec::IecBibliography.get "ISO/IEC DIR 2 IEC"
        expect(bib.docidentifier[0].id).to eq "ISO/IEC DIR 2 IEC"
      end
    end

    it "ISO/IEC DIR IEC SUP" do
      VCR.use_cassette "iso_iec_dir_iec_sup" do
        bib = RelatonIec::IecBibliography.get "ISO/IEC DIR IEC SUP"
        expect(bib.docidentifier[0].id).to eq "ISO/IEC DIR IEC SUP"
      end
    end

    describe "get with date filters", :skip_before do
      let(:pubid_1998) { Pubid::Iec::Identifier.parse("IEC 61332:1998") }
      let(:pubid_2005) { Pubid::Iec::Identifier.parse("IEC 61332:2005") }
      let(:pubid_2020) { Pubid::Iec::Identifier.parse("IEC 61332:2020") }

      let(:item_1998) do
        RelatonIec::IecBibliographicItem.new(
          docid: [RelatonIec::DocumentIdentifier.new(id: pubid_1998, type: "IEC", primary: true)],
          date: [RelatonBib::BibliographicDate.new(type: "published", on: "1998-05-01")],
        )
      end
      let(:item_2005) do
        RelatonIec::IecBibliographicItem.new(
          docid: [RelatonIec::DocumentIdentifier.new(id: pubid_2005, type: "IEC", primary: true)],
          date: [RelatonBib::BibliographicDate.new(type: "published", on: "2005-03-15")],
        )
      end
      let(:item_2020) do
        RelatonIec::IecBibliographicItem.new(
          docid: [RelatonIec::DocumentIdentifier.new(id: pubid_2020, type: "IEC", primary: true)],
          date: [RelatonBib::BibliographicDate.new(type: "published", on: "2020-11-10")],
        )
      end

      let(:hit_1998) do
        instance_double(RelatonIec::Hit, hit: { pubid: pubid_1998 }, part: nil, fetch: item_1998)
      end
      let(:hit_2005) do
        instance_double(RelatonIec::Hit, hit: { pubid: pubid_2005 }, part: nil, fetch: item_2005)
      end
      let(:hit_2020) do
        instance_double(RelatonIec::Hit, hit: { pubid: pubid_2020 }, part: nil, fetch: item_2020)
      end

      let(:hits) { [hit_1998, hit_2005, hit_2020] }

      before do
        collection = instance_double(RelatonIec::HitCollection)
        allow(collection).to receive(:detect) { |&block| hits.detect(&block) }
        allow(collection).to receive(:select) { |&block| hits.select(&block) }
        allow(collection).to receive(:max_by) { |&block| hits.max_by(&block) }
        allow(collection).to receive(:any?).and_return(hits.any?)
        allow(collection).to receive(:map) { |&block| hits.map(&block) }
        allow(RelatonIec::HitCollection).to receive(:new).and_return(collection)
      end

      it "returns most recent edition before the given date" do
        result = RelatonIec::IecBibliography.get("IEC 61332", nil, publication_date_before: Date.new(2006, 1, 1))
        expect(result.docidentifier.first.id).to eq "IEC 61332:2005"
      end

      it "returns most recent edition on or after the given date" do
        result = RelatonIec::IecBibliography.get("IEC 61332", nil, publication_date_after: Date.new(2006, 1, 1))
        expect(result.docidentifier.first.id).to eq "IEC 61332:2020"
      end

      it "filters with combined before and after" do
        result = RelatonIec::IecBibliography.get(
          "IEC 61332", nil,
          publication_date_after: Date.new(2000, 1, 1), publication_date_before: Date.new(2010, 1, 1),
        )
        expect(result.docidentifier.first.id).to eq "IEC 61332:2005"
      end

      it "returns nil when no editions match the date filter" do
        expect do
          expect(RelatonIec::IecBibliography.get(
            "IEC 61332", nil, publication_date_before: Date.new(1990, 1, 1),
          )).to be_nil
        end.to output(/Not found/).to_stderr_from_any_process
      end

      it "returns nil when year matches but exact date fails filter" do
        expect do
          expect(RelatonIec::IecBibliography.get(
            "IEC 61332:2005", nil, publication_date_before: Date.new(2005, 1, 1),
          )).to be_nil
        end.to output(/Not found/).to_stderr_from_any_process
      end

      it "respects >= semantics for publication_date_after" do
        result = RelatonIec::IecBibliography.get(
          "IEC 61332", nil,
          publication_date_after: Date.new(2005, 3, 15), publication_date_before: Date.new(2006, 1, 1),
        )
        expect(result.docidentifier.first.id).to eq "IEC 61332:2005"
      end
    end

    describe "provide_tips" do
      it "tips about year mismatch when year is wrong" do
        VCR.use_cassette "tips_year_mismatch" do
          expect do
            expect(RelatonIec::IecBibliography.get("IEC 60050-111:2005")).to be_nil
          end.to output(
            /TIP: No match for edition year `2005`, but matches exist for `1996`/
          ).to_stderr_from_any_process
        end
      end

      it "tips about available parts when no part given but parts exist" do
        VCR.use_cassette "tips_available_parts" do
          expect do
            expect(RelatonIec::IecBibliography.get("IEC 62443")).to be_nil
          end.to output(
            /TIP: If you wish to cite all document parts.*IEC 62443 \(all parts\)/
          ).to_stderr_from_any_process
        end
      end

      it "tips about doctype mismatch when type is wrong" do
        VCR.use_cassette "tips_doctype_mismatch" do
          expect do
            expect(RelatonIec::IecBibliography.get("IEC 62547")).to be_nil
          end.to output(
            /TIP: No match for type, but matches exist: `IEC TR 62547:2009`, `IEC TR 62547:2013`/
          ).to_stderr_from_any_process
        end
      end
    end
  end

  context "convert" do
    context "form reference to URN" do
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

    context "form URN to reference" do
      it "amendment" do
        ref = RelatonIec.urn_to_code "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
        expect(ref).to eq ["IEC 60050-102:2007/AMD1:2017", ""]
      end

      it "consolidation of amedments & deliverable" do
        ref = RelatonIec.urn_to_code "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:" \
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
