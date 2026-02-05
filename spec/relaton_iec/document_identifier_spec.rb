describe RelatonIec::DocumentIdentifier do
  context "with Pubid::Iec::Identifier" do
    let(:pubid) { Pubid::Iec::Identifier.parse("IEC 80000-1:2022") }
    subject { described_class.new(id: pubid, type: "IEC", primary: true) }

    it "#id returns string from Pubid object" do
      expect(subject.id).to eq "IEC 80000-1:2022"
    end

    context "with URN type" do
      subject { described_class.new(id: pubid, type: "URN") }

      it "#id returns URN string" do
        expect(subject.id).to eq "urn:iec:std:iec:80000:-1:2022"
      end
    end

    it "#remove_part sets part to nil" do
      subject.remove_part
      expect(pubid.part).to be_nil
      expect(subject.id).to eq "IEC 80000:2022"
    end

    it "#remove_date sets year to nil" do
      subject.remove_date
      expect(pubid.year).to be_nil
      expect(subject.id).to eq "IEC 80000-1"
    end

    it "#all_parts sets internal flag and adds suffix" do
      subject.remove_part
      subject.all_parts
      expect(subject.id).to eq "IEC 80000:2022 (all parts)"
    end

    context "URN type with all_parts" do
      subject { described_class.new(id: pubid, type: "URN") }

      it "adds :ser suffix to URN" do
        subject.remove_part
        subject.all_parts
        expect(subject.id).to eq "urn:iec:std:iec:80000:2022:ser"
      end
    end
  end

  context "with string id (fallback)" do
    subject { described_class.new(id: "IEC 80000-1:2022", type: "IEC", primary: true) }

    it "#id returns the string directly" do
      expect(subject.id).to eq "IEC 80000-1:2022"
    end

    it "#remove_part does not raise error" do
      expect { subject.remove_part }.not_to raise_error
    end

    it "#remove_date does not raise error" do
      expect { subject.remove_date }.not_to raise_error
    end

    it "#all_parts does not raise error" do
      expect { subject.all_parts }.not_to raise_error
    end
  end
end
