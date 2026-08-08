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
      expect(docid.to_s).to eq "IEC 60027-1/AMD1:1997"
    end

    it "removes date before CSV suffix" do
      docid = build_docid("CISPR 14-1:2005+AMD1:2008 CSV")
      docid.remove_date!
      expect(docid.to_s).to eq "CISPR 14-1+AMD1:2008 CSV"
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

  describe "URN content" do
    def build_urn(content)
      described_class.new(content: content, type: "URN")
    end

    # metanorma-pdfa#77: an amendment URN cannot be parsed by pubid-iec, but it
    # is already canonical, so it must be kept verbatim without a parse warning.
    it "keeps an amendment URN verbatim without warning" do
      docid = nil
      expect { docid = build_urn("urn:iec:std:iec:61966-2-1:1999:::::amd:1:2003") }
        .not_to output(/Failed to parse Pubid/).to_stderr_from_any_process
      expect(docid.to_s).to eq "urn:iec:std:iec:61966-2-1:1999:::::amd:1:2003"
    end

    it "keeps a series URN without warning" do
      docid = nil
      expect { docid = build_urn("urn:iec:std:iec:80000:::ser") }
        .not_to output(/Failed to parse Pubid/).to_stderr_from_any_process
      # Exact rendering is pubid-iec's concern and differs across versions
      # (1.15.20 re-emits a trailing colon); the fix only guarantees no warning.
      expect(docid.to_s).to start_with "urn:iec:std:iec:80000:::ser"
    end

    it "keeps a consolidated (CSV) URN verbatim without warning" do
      urn = "urn:iec:std:iec:60034-1:1969::csv:en-fr:plus:amd:1:1977:plus:amd:2:1979"
      docid = nil
      expect { docid = build_urn(urn) }
        .not_to output(/Failed to parse Pubid/).to_stderr_from_any_process
      expect(docid.to_s).to eq urn
    end

    it "parses a simple URN without warning" do
      docid = nil
      expect { docid = build_urn("urn:iec:std:iec:61058-2-4:1995") }
        .not_to output(/Failed to parse Pubid/).to_stderr_from_any_process
      expect(docid.pubid).not_to be_nil
    end

    it "warns and falls back to raw content for unparseable input" do
      docid = nil
      expect { docid = build_urn("this is not a valid id") }
        .to output(/Failed to parse Pubid/).to_stderr_from_any_process
      expect(docid.to_s).to eq "this is not a valid id"
    end

    # Regression for metanorma/metanorma-pdfa#77: deserializing a fetched
    # bibitem with an amendment URN must not emit a parse warning.
    it "does not warn when deserialized from XML (metanorma-pdfa#77)" do
      xml = <<~XML
        <bibitem type="standard" id="IEC61966-2-1">
          <docidentifier type="IEC" primary="true">IEC 61966-2-1:1999/AMD1:2003</docidentifier>
          <docidentifier type="URN">urn:iec:std:iec:61966-2-1:1999:::::amd:1:2003</docidentifier>
        </bibitem>
      XML
      item = nil
      expect { item = Relaton::Iec::Item.from_xml(xml) }
        .not_to output(/Failed to parse Pubid/).to_stderr_from_any_process
      urn = item.docidentifier.detect { |d| d.type == "URN" }
      expect(urn.to_s).to eq "urn:iec:std:iec:61966-2-1:1999:::::amd:1:2003"
    end
  end

  describe "#to_all_parts!" do
    it "removes part and date from simple ID" do
      docid = build_docid("IEC 60027-1:1992")
      docid.to_all_parts!
      expect(docid.to_s).to eq "IEC 60027 (all parts)"
      expect(docid.pubid.all_parts).to be true
    end

    it "removes nested parts and date" do
      docid = build_docid("CISPR 16-1-1:2010")
      docid.to_all_parts!
      expect(docid.to_s).to eq "CISPR 16 (all parts)"
      expect(docid.pubid.all_parts).to be true
    end

    it "removes part and date from chapter ID" do
      docid = build_docid("IEC 60050-102:2007")
      docid.to_all_parts!
      expect(docid.to_s).to eq "IEC 60050 (all parts)"
      expect(docid.pubid.all_parts).to be true
    end

    it "removes part and date preserving TR prefix" do
      docid = build_docid("IEC TR 60034-16-2:1991")
      docid.to_all_parts!
      expect(docid.to_s).to eq "IEC TR 60034 (all parts)"
      expect(docid.pubid.all_parts).to be true
    end
  end
end
