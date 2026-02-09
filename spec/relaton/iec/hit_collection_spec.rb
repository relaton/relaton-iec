require "relaton/iec/hit_collection"

describe Relaton::Iec::HitCollection do
  context "#pubid_matches?" do
    let(:pubid) { Pubid::Iec::Identifier.parse("IEC 61058-2-4:1995") }

    context "with default exclude [:year]" do
      subject { described_class.new(pubid) }

      it "returns false for nil row_pubid" do
        expect(subject.send(:pubid_matches?, nil)).to be false
      end

      it "matches same document with different year" do
        row_pubid = Pubid::Iec::Identifier.parse("IEC 61058-2-4:2003")
        expect(subject.send(:pubid_matches?, row_pubid)).to be true
      end

      it "does not match different document" do
        row_pubid = Pubid::Iec::Identifier.parse("IEC 60050-311:2001")
        expect(subject.send(:pubid_matches?, row_pubid)).to be false
      end
    end

    context "with exclude [:year, :type]" do
      let(:ts_pubid) { Pubid::Iec::Identifier.parse("IEC TS 61058-2-4:1995") }
      subject { described_class.new(ts_pubid, exclude: [:year, :type]) }

      it "matches different type with same number and part" do
        row_pubid = Pubid::Iec::Identifier.parse("IEC 61058-2-4:2003")
        expect(subject.send(:pubid_matches?, row_pubid)).to be true
      end

      it "does not match different document" do
        row_pubid = Pubid::Iec::Identifier.parse("IEC 60050-311:2001")
        expect(subject.send(:pubid_matches?, row_pubid)).to be false
      end
    end
  end
end
