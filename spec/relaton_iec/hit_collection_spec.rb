# frozen_string_literal: true

describe RelatonIec::HitCollection do
  def make_row(ref_string, file_path)
    { id: Pubid::Iec::Identifier.parse(ref_string), file: file_path }
  end

  def build_index_mock(rows)
    index = instance_double(Relaton::Index::Type)
    allow(index).to receive(:search) { |&block| rows.select(&block) }
    allow(Relaton::Index).to receive(:find_or_create).and_return(index)
    index
  end

  describe "#fetch_from_index" do
    context "Branch A - nil pubid" do
      it "returns empty collection" do
        index = build_index_mock([])
        collection = described_class.new(nil)
        expect(collection.size).to eq(0)
        expect(index).not_to have_received(:search)
      end
    end

    context "Branch C - default exclude: [:year]" do
      it "matches documents ignoring year" do
        rows = [
          make_row("IEC 60050-102:2007", "data/iec_60050-102_2007.yaml"),
          make_row("IEC 60050-102:2010", "data/iec_60050-102_2010.yaml"),
          make_row("IEC 60050-101:1998", "data/iec_60050-101_1998.yaml"),
          make_row("IEC 61058-2-4:2018", "data/iec_61058-2-4_2018.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 60050-102:2007")
        collection = described_class.new(pubid)

        expect(collection.size).to eq(2)
        expect(collection.map { |h| h.hit[:pubid].to_s }).to eq(
          ["IEC 60050-102:2007", "IEC 60050-102:2010"]
        )
      end
    end

    context "Branch C - exclude: [:year, :part] (all_parts)" do
      it "matches all parts of a document" do
        rows = [
          make_row("IEC 80000-1:2009", "data/iec_80000-1_2009.yaml"),
          make_row("IEC 80000-6:2008", "data/iec_80000-6_2008.yaml"),
          make_row("IEC 80000-13:2008", "data/iec_80000-13_2008.yaml"),
          make_row("IEC 80000-6:2022", "data/iec_80000-6_2022.yaml"),
          make_row("IEC 60050-102:2007", "data/iec_60050-102_2007.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 80000")
        collection = described_class.new(pubid, exclude: [:year, :part])

        expect(collection.size).to eq(4)
        pubids = collection.map { |h| h.hit[:pubid].to_s }
        expect(pubids).to eq([
          "IEC 80000-6:2008",
          "IEC 80000-13:2008",
          "IEC 80000-1:2009",
          "IEC 80000-6:2022",
        ])
      end
    end

    context "Branch B - exclude: [:year, :type] (cross-type matching)" do
      it "matches documents across different types" do
        rows = [
          make_row("IEC TR 62547:2013", "data/iec_tr_62547_2013.yaml"),
          make_row("IEC TR 62547:2024", "data/iec_tr_62547_2024.yaml"),
          make_row("IEC 62547:2020", "data/iec_62547_2020.yaml"),
          make_row("IEC TR 60050-102:2007", "data/iec_tr_60050-102_2007.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 62547")
        collection = described_class.new(pubid, exclude: [:year, :type])

        expect(collection.size).to eq(3)
        pubids = collection.map { |h| h.hit[:pubid].to_s }
        expect(pubids).to eq([
          "IEC TR 62547:2013",
          "IEC 62547:2020",
          "IEC TR 62547:2024",
        ])
      end
    end

    context "sort verification - year ascending, nil years first" do
      it "sorts by year with nil first" do
        rows = [
          make_row("IEC 60050-102:2015", "data/iec_60050-102_2015.yaml"),
          make_row("IEC 60050-102", "data/iec_60050-102.yaml"),
          make_row("IEC 60050-102:2007", "data/iec_60050-102_2007.yaml"),
          make_row("IEC 60050-102:2010", "data/iec_60050-102_2010.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 60050-102")
        collection = described_class.new(pubid)

        years = collection.map { |h| h.hit[:pubid].year }
        expect(years).to eq([nil, 2007, 2010, 2015])
      end
    end

    context "Hit structure verification" do
      it "creates Hit instances with correct attributes" do
        rows = [
          make_row("IEC 60050-102:2007", "data/iec_60050-102_2007.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 60050-102:2007")
        collection = described_class.new(pubid, exclude: [])

        expect(collection.size).to eq(1)
        hit = collection.first
        expect(hit).to be_a(RelatonIec::Hit)
        expect(hit.hit[:pubid].to_s).to eq("IEC 60050-102:2007")
        expect(hit.hit[:file]).to eq("data/iec_60050-102_2007.yaml")
      end
    end

    context "edge case - no matches" do
      it "returns empty collection when no documents match" do
        rows = [
          make_row("IEC 60050-102:2007", "data/iec_60050-102_2007.yaml"),
          make_row("IEC 61058-2-4:2018", "data/iec_61058-2-4_2018.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 99999")
        collection = described_class.new(pubid)

        expect(collection.size).to eq(0)
      end
    end

    context "filtering accuracy - precise structural matching" do
      it "matches only documents with same structure" do
        rows = [
          make_row("IEC 61326-1:2020", "data/iec_61326-1_2020.yaml"),
          make_row("IEC 61326-1:2012", "data/iec_61326-1_2012.yaml"),
          make_row("IEC 61326-2-1:2020", "data/iec_61326-2-1_2020.yaml"),
          make_row("IEC 61326:2020", "data/iec_61326_2020.yaml"),
          make_row("ISO/IEC 61326-1:2020", "data/iso_iec_61326-1_2020.yaml"),
          make_row("IEC 61327-1:2020", "data/iec_61327-1_2020.yaml"),
        ]
        build_index_mock(rows)

        pubid = Pubid::Iec::Identifier.parse("IEC 61326-1:2020")
        collection = described_class.new(pubid)

        expect(collection.size).to eq(2)
        pubids = collection.map { |h| h.hit[:pubid].to_s }
        expect(pubids).to eq(["IEC 61326-1:2012", "IEC 61326-1:2020"])
      end
    end
  end
end
