describe Relaton::Iec::Docidentifier do
  def build_docid(content)
    described_class.new(content: content, type: "IEC")
  end

  describe "#remove_date!" do
    it "removes date at end of simple ID" do
      docid = build_docid("IEC 60050-102:2007")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60050-102"
    end

    it "removes date from ID with part" do
      docid = build_docid("IEC 60027-1:1992")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60027-1"
    end

    it "does not change ID without date" do
      docid = build_docid("IEC 60050-102")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60050-102"
    end

    it "removes last date from amendment ID" do
      docid = build_docid("IEC 60027-1:1992/AMD1:1997")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60027-1:1992/AMD1"
    end

    it "removes date before CSV suffix" do
      docid = build_docid("CISPR 14-1:2005+AMD1:2008 CSV")
      docid.remove_date!
      expect(docid.content).to eq "CISPR 14-1:2005+AMD1 CSV"
    end

    it "removes date before SER suffix" do
      docid = build_docid("IEC 60060:2025 SER")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60060 SER"
    end

    it "removes date before DB suffix" do
      docid = build_docid("IEC 60061:2025 DB")
      docid.remove_date!
      expect(docid.content).to eq "IEC 60061 DB"
    end
  end

  describe "#remove_part!" do
    it "removes single part number" do
      docid = build_docid("IEC 60027-1:1992")
      docid.remove_part!
      expect(docid.content).to eq "IEC 60027:1992"
    end

    it "removes nested part numbers" do
      docid = build_docid("CISPR 16-1-1:2010")
      docid.remove_part!
      expect(docid.content).to eq "CISPR 16:2010"
    end

    it "removes double-digit nested parts" do
      docid = build_docid("IEC 60034-18-21:2012")
      docid.remove_part!
      expect(docid.content).to eq "IEC 60034:2012"
    end

    it "removes three-level part numbers" do
      docid = build_docid("IEC 60050-716-1:1995")
      docid.remove_part!
      expect(docid.content).to eq "IEC 60050:1995"
    end

    it "removes part from Technical Report ID" do
      docid = build_docid("IEC TR 60034-16-2:1991")
      docid.remove_part!
      expect(docid.content).to eq "IEC TR 60034:1991"
    end

    it "does not change ID without part" do
      docid = build_docid("IEC 60050:2007")
      docid.remove_part!
      expect(docid.content).to eq "IEC 60050:2007"
    end

    it "removes part from ID with amendment" do
      docid = build_docid("IEC 60027-1:1992/AMD1:1997")
      docid.remove_part!
      expect(docid.content).to eq "IEC 60027:1992/AMD1:1997"
    end
  end

  describe "#remove_stage!" do
    it "does not change simple ID (no stages in IEC)" do
      docid = build_docid("IEC 60027-1:1992")
      docid.remove_stage!
      expect(docid.content).to eq "IEC 60027-1:1992"
    end

    it "does not change ID with amendment" do
      docid = build_docid("IEC 60027-1:1992/AMD1:1997")
      docid.remove_stage!
      expect(docid.content).to eq "IEC 60027-1:1992/AMD1:1997"
    end

    it "does not change ID with CSV suffix" do
      docid = build_docid("CISPR 14-1:2005+AMD1:2008 CSV")
      docid.remove_stage!
      expect(docid.content).to eq "CISPR 14-1:2005+AMD1:2008 CSV"
    end
  end

  describe "#to_all_parts!" do
    it "removes part and date from simple ID" do
      docid = build_docid("IEC 60027-1:1992")
      docid.to_all_parts!
      expect(docid.content).to eq "IEC 60027 (all parts)"
    end

    it "removes nested parts and date" do
      docid = build_docid("CISPR 16-1-1:2010")
      docid.to_all_parts!
      expect(docid.content).to eq "CISPR 16 (all parts)"
    end

    it "removes part and date from chapter ID" do
      docid = build_docid("IEC 60050-102:2007")
      docid.to_all_parts!
      expect(docid.content).to eq "IEC 60050 (all parts)"
    end

    it "removes part and date preserving TR prefix" do
      docid = build_docid("IEC TR 60034-16-2:1991")
      docid.to_all_parts!
      expect(docid.content).to eq "IEC TR 60034 (all parts)"
    end
  end
end
