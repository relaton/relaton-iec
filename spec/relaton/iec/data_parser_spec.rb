require "relaton/iec/data_parser"

describe Relaton::Iec::DataParser do
  let(:pub) { JSON.parse File.read("spec/fixtures/pub.json", encoding: "UTF-8") }
  subject { described_class.new(pub) }

  it "initialize" do
    expect(subject.instance_variable_get(:@pub)).to be pub
  end

  context "instance methods" do
    it "#parse" do
      resp = double "response", body: "<RES></RES>"
      allow(Net::HTTP).to receive(:get_response).and_return(resp)

      item = subject.parse

      expect(item).to be_instance_of Relaton::Iec::ItemData
      expect(item.type).to eq "standard"
      expect(item.docidentifier.size).to eq 2
      expect(item.docidentifier[0].content).to eq "IEC/ISO 1234-1-2"
      expect(item.docidentifier[0].type).to eq "IEC"
      expect(item.docidentifier[1].content).to eq "urn:urnId"
      expect(item.docidentifier[1].type).to eq "URN"
      expect(item.language).to eq ["en", "fr"]
      expect(item.script).to eq ["Latn"]
      expect(item.title.size).to eq 6
      expect(item.title[0].content).to eq "Title"
      expect(item.title[0].type).to eq "title-intro"
      expect(item.status.stage.content).to eq "PUBLISHED"
      expect(item.edition.content).to eq "1"
      expect(item.date.size).to eq 4
      expect(item.date[0].at.to_s).to eq "2019-03-04"
      expect(item.date[0].type).to eq "published"
      expect(item.abstract.size).to eq 2
      expect(item.abstract[0].content).to eq "Abstract"
      expect(item.copyright.size).to eq 1
      expect(item.copyright[0].from).to eq "2019"
      expect(item.source.size).to eq 2
      expect(item.source[0].content.to_s).to eq "https://webstore.iec.ch/publication/64772"
      expect(item.place[0].city).to eq "Geneva"
      expect(item.ext.doctype.content).to eq "international-standard"
      expect(item.ext.structuredidentifier.project_number.content).to eq "1234"
      expect(item.ext.ics.size).to eq 2
      expect(item.ext.flavor).to eq "iec"
      expect(item.ext.ics[0].code).to eq "01.040.35"
      expect(item.ext.price_code).to eq "PC"
    end

    it "#docid" do
      id = subject.send :docidentifier
      expect(id).to be_instance_of Array
      expect(id.size).to eq 2
      expect(id[0]).to be_instance_of Relaton::Iec::Docidentifier
      expect(id[0].content).to eq "IEC/ISO 1234-1-2"
      expect(id[0].type).to eq "IEC"
      expect(id[0].primary).to be true
      expect(id[1]).to be_instance_of Relaton::Iec::Docidentifier
      expect(id[1].content).to eq "urn:urnId"
      expect(id[1].type).to eq "URN"
      expect(id[1].primary).to be_nil
    end

    it "#structuredidentifier" do
      str_id = subject.send :structuredidentifier
      expect(str_id).to be_instance_of Relaton::Iso::StructuredIdentifier
      expect(str_id.project_number.content).to eq "1234"
      expect(str_id.type).to eq "IEC"
    end

    it "#language" do
      expect(subject.send :language).to eq ["en", "fr"]
    end

    it "#script" do
      expect(subject.send :script).to eq ["Latn"]
    end

    it "#title" do
      title = subject.send :title
      expect(title).to be_instance_of Array
      expect(title.size).to eq 6
      expect(title[0].content).to eq "Title"
      expect(title[0].language).to eq "en"
      expect(title[0].script).to eq "Latn"
      expect(title[0].type).to eq "title-intro"
      expect(title[1].content).to eq "Part 05"
      expect(title[1].language).to eq "en"
      expect(title[1].script).to eq "Latn"
      expect(title[1].type).to eq "title-main"
      expect(title[2].content).to eq "Title - Part 05"
      expect(title[2].language).to eq "en"
      expect(title[2].script).to eq "Latn"
      expect(title[2].type).to eq "main"
      expect(title[3].content).to eq "Titre"
      expect(title[3].language).to eq "fr"
      expect(title[3].script).to eq "Latn"
      expect(title[3].type).to eq "title-intro"
      expect(title[4].content).to eq "Partie 05"
      expect(title[4].language).to eq "fr"
      expect(title[4].script).to eq "Latn"
      expect(title[4].type).to eq "title-main"
      expect(title[5].content).to eq "Titre - Partie 05"
      expect(title[5].language).to eq "fr"
      expect(title[5].script).to eq "Latn"
      expect(title[5].type).to eq "main"
    end

    it "#abstract" do
      abstract = subject.send :abstract
      expect(abstract).to be_instance_of Array
      expect(abstract.size).to eq 2
      expect(abstract[0]).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
      expect(abstract[0].content).to eq "Abstract"
      expect(abstract[0].language).to eq "en"
      expect(abstract[0].script).to eq "Latn"
      expect(abstract[1]).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
      expect(abstract[1].content).to eq "Résumé"
      expect(abstract[1].language).to eq "fr"
      expect(abstract[1].script).to eq "Latn"
    end

    it "#copyright" do
      c = subject.send :copyright
      expect(c).to be_instance_of Array
      expect(c.size).to eq 1
      expect(c[0]).to be_instance_of Relaton::Bib::Copyright
      expect(c[0].from).to eq "2019"
      expect(c[0].owner.size).to eq 2
      expect(c[0].owner[0]).to be_instance_of Relaton::Bib::ContributionInfo
      expect(c[0].owner[0].organization.abbreviation.content).to eq "IEC"
      expect(c[0].owner[0].organization.name.first.content).to eq "International Electrotechnical Commission"
      expect(c[0].owner[0].organization.uri[0].content).to eq "www.iec.ch"
      expect(c[0].owner[1].organization.abbreviation.content).to eq "ISO"
      expect(c[0].owner[1].organization.name.first.content).to eq "International Organization for Standardization"
      expect(c[0].owner[1].organization.uri[0].content).to eq "www.iso.org"
    end

    # it "#docstatus" do
    #   st = subject.docstatus
    #   expect(st).to be_instance_of Relaton::Bib::Status
    #   expect(st.stage).to be_instance_of Relaton::Bib::Status::Stage
    #   expect(st.stage.value).to eq "PUBLISHED"
    # end

    it "#ics" do
      ics = subject.send :ics
      expect(ics).to be_instance_of Array
      expect(ics.size).to eq 2
      expect(ics[0]).to be_instance_of Relaton::Bib::ICS
      expect(ics[0].code).to eq "01.040.35"
      expect(ics[1]).to be_instance_of Relaton::Bib::ICS
      expect(ics[1].code).to eq "35.020"
    end

    it "#date" do
      d = subject.send :date
      expect(d).to be_instance_of Array
      expect(d.size).to eq 4
      expect(d[0]).to be_instance_of Relaton::Bib::Date
      expect(d[0].at.to_s).to eq "2019-03-04"
      expect(d[0].type).to eq "published"
      expect(d[1]).to be_instance_of Relaton::Bib::Date
      expect(d[1].at.to_s).to eq "2021-12-31"
      expect(d[1].type).to eq "stable-until"
      expect(d[2]).to be_instance_of Relaton::Bib::Date
      expect(d[2].at.to_s).to eq "2020-02-03"
      expect(d[2].type).to eq "confirmed"
      expect(d[3]).to be_instance_of Relaton::Bib::Date
      expect(d[3].at.to_s).to eq "2022-11-21"
      expect(d[3].type).to eq "obsoleted"
    end

    it "#contributor" do
      cntrib = subject.send :contributor
      expect(cntrib).to be_instance_of Array
      expect(cntrib.size).to eq 3
      expect(cntrib[0]).to be_instance_of Relaton::Bib::Contributor
      expect(cntrib[0].organization.abbreviation.content).to eq "IEC"
      expect(cntrib[0].organization.name.first.content).to eq "International Electrotechnical Commission"
      expect(cntrib[0].organization.uri[0].content).to eq "www.iec.ch"
      expect(cntrib[0].role[0].type).to eq "publisher"
      expect(cntrib[1]).to be_instance_of Relaton::Bib::Contributor
      expect(cntrib[1].organization.abbreviation.content).to eq "ISO"
      expect(cntrib[1].organization.name.first.content).to eq "International Organization for Standardization"
      expect(cntrib[1].organization.uri[0].content).to eq "www.iso.org"
      expect(cntrib[1].role[0].type).to eq "publisher"
      expect(cntrib[2]).to be_instance_of Relaton::Bib::Contributor
      expect(cntrib[2].organization.abbreviation.content).to eq "IEC"
      expect(cntrib[2].organization.name.first.content).to eq "International Electrotechnical Commission"
      expect(cntrib[2].organization.subdivision[0].name.first.content).to eq "WG1"
      expect(cntrib[2].organization.subdivision[0].identifier.first.content).to eq "1"
      expect(cntrib[2].role[0].type).to eq "author"
      expect(cntrib[2].role[0].description[0].content).to eq "committee"
    end

    it "#source" do
      source = subject.send :source
      expect(source).to be_instance_of Array
      expect(source.size).to eq 2
      expect(source[0]).to be_instance_of Relaton::Bib::Uri
      expect(source[0].content.to_s).to eq "https://webstore.iec.ch/publication/64772"
      expect(source[0].type).to eq "src"
      expect(source[1]).to be_instance_of Relaton::Bib::Uri
      expect(source[1].content.to_s).to eq "https://webstore.iec.ch/preview/file.pdf"
      expect(source[1].type).to eq "obp"
    end

    context "#doctype" do
      let(:doctype) { subject.send(:ext).doctype }

      it "IS" do
        expect(doctype.content).to eq "international-standard"
      end

      it "TR" do
        subject.instance_variable_get(:@pub)["stdType"] = "TR"
        expect(doctype).to be_instance_of Relaton::Iec::Doctype
        expect(doctype.content).to eq "technical-report"
      end

      it "TS" do
        subject.instance_variable_get(:@pub)["stdType"] = "TS"
        expect(doctype.content).to eq "technical-specification"
      end

      it "PAS" do
        subject.instance_variable_get(:@pub)["stdType"] = "PAS"
        expect(doctype.content).to eq "publicly-available-specification"
      end

      it "SRD" do
        subject.instance_variable_get(:@pub)["stdType"] = "SRD"
        expect(doctype.content).to eq "system-reference-deliverable"
      end

      it "other" do
        subject.instance_variable_get(:@pub)["stdType"] = "GUIDE"
        expect(doctype.content).to eq "guide"
      end
    end

    context "#relation" do
      it do
        resp = double "responce", body: <<~XML
          <RES>
            <ROW>
              <FULL_NAME>IEC 1234-1-1:2019</FULL_NAME>
              <STATUS>REPLACED</STATUS>
            </ROW>
            <ROW>
              <FULL_NAME>IEC 1234-1-2:2019</FULL_NAME>
              <STATUS>PREPARING</STATUS>
            </ROW>
            <ROW>
              <FULL_NAME>IEC 1234-1-3:2019</FULL_NAME>
              <STATUS>PUBLISHED</STATUS>
            </ROW>
            <ROW>
              <FULL_NAME>IEC 1234-1-4:2019</FULL_NAME>
              <STATUS>REVISED</STATUS>
            </ROW>
            <ROW>
              <FULL_NAME>IEC 1234-1-5:2019</FULL_NAME>
              <STATUS>WITHDRAWN</STATUS>
            </ROW>
            <ROW>
              <FULL_NAME>IEC 1234-1-6:2019</FULL_NAME>
              <STATUS>DRAFT</STATUS>
            </ROW>
          </RES>
        XML
        expect(Net::HTTP).to receive(:get_response)
          .with(URI("https://webstore.iec.ch/webstore/webstore.nsf/AjaxRequestXML?Openagent&url=64772"))
          .and_return resp
        rel = subject.send :relation
        expect(rel).to be_instance_of Array
        expect(rel.size).to eq 4
        expect(rel[0]).to be_instance_of Relaton::Iec::Relation
        expect(rel[0].type).to eq "updates"
        expect(rel[0].bibitem).to be_instance_of Relaton::Iec::ItemData
        expect(rel[0].bibitem.docidentifier[0].content).to eq "IEC 1234-1-1:2019"
        expect(rel[1].type).to eq "updates"
        expect(rel[1].bibitem.docidentifier[0].content).to eq "IEC 1234-1-4:2019"
        expect(rel[2].type).to eq "obsoletes"
        expect(rel[2].bibitem.docidentifier[0].content).to eq "IEC 1234-1-5:2019"
        expect(rel[3].type).to eq "draft"
        expect(rel[3].bibitem.docidentifier[0].content).to eq "IEC 1234-1-6:2019"
      end

      it "retry" do
        expect(Net::HTTP).to receive(:get_response).and_raise(StandardError).exactly(3).times
        expect { subject.send :relation }.to raise_error StandardError
      end
    end
  end
end
