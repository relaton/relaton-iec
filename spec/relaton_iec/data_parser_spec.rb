describe RelatonIec::DataParser do
  let(:pub) do
    {
      "urn" => "iec:pub:64772", "reference" => "IEC/ISO 1234-1-2", "edition" => "1",
      "urnAlt" => ["urnId"], "stdType" => "IS",
      "title" => [
        { "lang" => "en", "value" => "Title" },
        { "lang" => "fr", "value" => "Titre" },
      ],
      "priceInfo" => { "priceCode" => "PC" },
      "committee" => { "reference" => "WG1" },
      "abstract" => [
        { "lang" => "en", "content" => "Abstract", "format" => "text/html" },
        { "lang" => "fr", "content" => "Résumé", "format" => "text/html" },
      ],
      "releaseDate" => "2019-01-01", "status" => "PUBLISHED",
      "classifications" => [
        { "type" => "ICS", "value" => "01.040.35" },
        { "type" => "ICS", "value" => "35.020" },
      ],
      "publicationDate" => "2019-03-04", "confirmationDate" => "2020-02-03",
      "stabilityDate" => "2021-12-31", "dateOfWithdrawal" => "2022-11-21",
      "releaseItems" => [
        { "type" => "PREVIEW", "contentRef" => { "fileName" => "file.pdf" } },
      ]
    }
  end
  subject { RelatonIec::DataParser.new(pub) }

  it "initialize" do
    expect(subject.instance_variable_get(:@pub)).to be pub
  end

  context "instance methods" do
    it "#parse" do
      expect(subject).to receive(:docid).and_return :id
      expect(subject).to receive(:structuredidentifier).and_return :strid
      expect(subject).to receive(:language).and_return :lang
      expect(subject).to receive(:script).and_return :script
      expect(subject).to receive(:title).and_return :title
      expect(subject).to receive(:doctype).and_return :doctype
      expect(RelatonBib::DocumentStatus).to receive(:new).with(stage: "PUBLISHED").and_return(:status)
      expect(subject).to receive(:ics).and_return :ics
      expect(subject).to receive(:date).and_return :date
      expect(subject).to receive(:contributor).and_return :contributor
      expect(subject).to receive(:editorialgroup).and_return :editorialgroup
      expect(subject).to receive(:abstract).and_return :abstract
      expect(subject).to receive(:copyright).and_return :copyright
      expect(subject).to receive(:link).and_return :link
      expect(subject).to receive(:relation).and_return :relation
      expect(RelatonIec::IecBibliographicItem).to receive(:new).with(
        docid: :id, structuredidentifier: :strid,
        language: :lang, script: :script, title: :title, doctype: :doctype,
        docstatus: :status, ics: :ics, date: :date, contributor: :contributor,
        editorialgroup: :editorialgroup, abstract: :abstract,
        copyright: :copyright, link: :link, relation: :relation,
        edition: "1", price_code: "PC", place: ["Geneva"]
      ).and_return :item
      expect(subject.parse).to be :item
    end

    it "#docid" do
      id = subject.docid
      expect(id).to be_instance_of Array
      expect(id.size).to eq 2
      expect(id[0]).to be_instance_of RelatonBib::DocumentIdentifier
      expect(id[0].id).to eq "IEC/ISO 1234-1-2"
      expect(id[0].type).to eq "IEC"
      expect(id[0].primary).to be true
      expect(id[1]).to be_instance_of RelatonBib::DocumentIdentifier
      expect(id[1].id).to eq "urn:urnId"
      expect(id[1].type).to eq "URN"
      expect(id[1].primary).to be_nil
    end

    it "#structuredidentifier" do
      str_id = subject.structuredidentifier
      expect(str_id).to be_instance_of RelatonIsoBib::StructuredIdentifier
      expect(str_id.project_number).to eq "1234"
      expect(str_id.part).to eq "1"
      expect(str_id.subpart).to eq "2"
    end

    it "#language" do
      expect(subject.language).to eq ["en", "fr"]
    end

    it "#script" do
      expect(subject.script).to eq ["Latn"]
    end

    it "#title" do
      title = subject.title
      expect(title).to be_instance_of Array
      expect(title.size).to eq 2
      expect(title[0]).to be_instance_of RelatonBib::TypedTitleString
      expect(title[0].title.content).to eq "Title"
      expect(title[0].title.language).to eq ["en"]
      expect(title[0].title.script).to eq ["Latn"]
      expect(title[0].type).to eq "main"
      expect(title[1]).to be_instance_of RelatonBib::TypedTitleString
      expect(title[1].title.content).to eq "Titre"
      expect(title[1].title.language).to eq ["fr"]
      expect(title[1].title.script).to eq ["Latn"]
      expect(title[1].type).to eq "main"
    end

    it "#editorialgroup" do
      expect(subject.editorialgroup).to eq(
        technical_committee: [{
          name: "WG1", number: 1, type: "technicalCommittee"
        }],
      )
    end

    it "#abstract" do
      abstract = subject.abstract
      expect(abstract).to be_instance_of Array
      expect(abstract.size).to eq 2
      expect(abstract[0]).to be_instance_of RelatonBib::FormattedString
      expect(abstract[0].content).to eq "Abstract"
      expect(abstract[0].language).to eq ["en"]
      expect(abstract[0].script).to eq ["Latn"]
      expect(abstract[1]).to be_instance_of RelatonBib::FormattedString
      expect(abstract[1].content).to eq "Résumé"
      expect(abstract[1].language).to eq ["fr"]
      expect(abstract[1].script).to eq ["Latn"]
    end

    it "#copyright" do
      c = subject.copyright
      expect(c).to be_instance_of Array
      expect(c.size).to eq 1
      expect(c[0]).to eq(
        from: "2019", owner: [
          {
            abbreviation: "IEC",
            name: "International Electrotechnical Commission",
            url: "www.iec.ch",
          },
          {
            abbreviation: "ISO",
            name: "International Organization for Standardization",
            url: "www.iso.org",
          },
        ]
      )
    end

    # it "#docstatus" do
    #   st = subject.docstatus
    #   expect(st).to be_instance_of RelatonBib::DocumentStatus
    #   expect(st.stage).to be_instance_of RelatonBib::DocumentStatus::Stage
    #   expect(st.stage.value).to eq "PUBLISHED"
    # end

    it "#ics" do
      ics = subject.ics
      expect(ics).to be_instance_of Array
      expect(ics.size).to eq 2
      expect(ics[0]).to be_instance_of RelatonIsoBib::Ics
      expect(ics[0].code).to eq "01.040.35"
      expect(ics[1]).to be_instance_of RelatonIsoBib::Ics
      expect(ics[1].code).to eq "35.020"
    end

    it "#date" do
      d = subject.date
      expect(d).to be_instance_of Array
      expect(d.size).to eq 4
      expect(d[0]).to be_instance_of RelatonBib::BibliographicDate
      expect(d[0].on).to eq "2019-03-04"
      expect(d[0].type).to eq "published"
      expect(d[1]).to be_instance_of RelatonBib::BibliographicDate
      expect(d[1].on).to eq "2021-12-31"
      expect(d[1].type).to eq "stable-until"
      expect(d[2]).to be_instance_of RelatonBib::BibliographicDate
      expect(d[2].on).to eq "2020-02-03"
      expect(d[2].type).to eq "confirmed"
      expect(d[3]).to be_instance_of RelatonBib::BibliographicDate
      expect(d[3].on).to eq "2022-11-21"
      expect(d[3].type).to eq "obsoleted"
    end

    it "#contributor" do
      cntrib = subject.contributor
      expect(cntrib).to be_instance_of Array
      expect(cntrib.size).to eq 2
      expect(cntrib[0]).to eq(
        entity: {
          abbreviation: "IEC",
          name: "International Electrotechnical Commission",
          url: "www.iec.ch",
        },
        role: [{ type: "publisher" }],
      )
      expect(cntrib[1]).to eq(
        entity: {
          abbreviation: "ISO",
          name: "International Organization for Standardization",
          url: "www.iso.org",
        },
        role: [{ type: "publisher" }],
      )
    end

    it "#link" do
      link = subject.link
      expect(link).to be_instance_of Array
      expect(link.size).to eq 2
      expect(link[0]).to be_instance_of RelatonBib::TypedUri
      expect(link[0].content.to_s).to eq "https://webstore.iec.ch/publication/64772"
      expect(link[0].type).to eq "src"
      expect(link[1]).to be_instance_of RelatonBib::TypedUri
      expect(link[1].content.to_s).to eq "https://webstore.iec.ch/preview/file.pdf"
      expect(link[1].type).to eq "obp"
    end

    context "#doctype" do
      it "IS" do
        expect(subject.doctype).to eq "international-standard"
      end

      it "TR" do
        subject.instance_variable_get(:@pub)["stdType"] = "TR"
        expect(subject.doctype).to eq "technical-report"
      end

      it "TS" do
        subject.instance_variable_get(:@pub)["stdType"] = "TS"
        expect(subject.doctype).to eq "technical-specification"
      end

      it "PAS" do
        subject.instance_variable_get(:@pub)["stdType"] = "PAS"
        expect(subject.doctype).to eq "publicly-available-specification"
      end

      it "SRD" do
        subject.instance_variable_get(:@pub)["stdType"] = "SRD"
        expect(subject.doctype).to eq "system-reference-delivrable"
      end

      it "other" do
        subject.instance_variable_get(:@pub)["stdType"] = "GUIDE"
        expect(subject.doctype).to eq "guide"
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
        rel = subject.relation
        expect(rel).to be_instance_of Array
        expect(rel.size).to eq 4
        expect(rel[0]).to be_instance_of RelatonBib::DocumentRelation
        expect(rel[0].type).to eq "updates"
        expect(rel[0].bibitem).to be_instance_of RelatonIec::IecBibliographicItem
        expect(rel[0].bibitem.docidentifier[0].id).to eq "IEC 1234-1-1:2019"
        expect(rel[1].type).to eq "updates"
        expect(rel[1].bibitem.docidentifier[0].id).to eq "IEC 1234-1-4:2019"
        expect(rel[2].type).to eq "obsoletes"
        expect(rel[2].bibitem.docidentifier[0].id).to eq "IEC 1234-1-5:2019"
        expect(rel[3].type).to eq "draft"
        expect(rel[3].bibitem.docidentifier[0].id).to eq "IEC 1234-1-6:2019"
      end

      it "retry" do
        expect(Net::HTTP).to receive(:get_response).and_raise(StandardError).exactly(3).times
        expect { subject.relation }.to raise_error StandardError
      end
    end
  end
end
