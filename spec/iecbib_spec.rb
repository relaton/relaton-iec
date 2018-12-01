# frozen_string_literal: true

require 'open-uri'

RSpec.describe Iecbib do
  it 'has a version number' do
    expect(Iecbib::VERSION).not_to be nil
  end

  it 'fetch hits of page' do
    VCR.use_cassette '60050_102_2007' do
      hit_collection = Iecbib::IecBibliography.search('60050-102', '2007')
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of Iecbib::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of Iecbib::Hit
    end
  end

  it 'return xml of hit' do
    VCR.use_cassette '61058_2_4_2003' do
      hits = Iecbib::IecBibliography.search('61058-2-4', '2003')
      file_path = 'spec/examples/hit.xml'
      File.write file_path, hits.first.to_xml unless File.exist? file_path
      expect(hits.first.to_xml).to be_equivalent_to File.read(file_path).sub(/2018-10-26/, Date.today.to_s)
    end
  end

  it 'return string of hit' do
    VCR.use_cassette '60050_101_1998' do
      hits = Iecbib::IecBibliography.search('60050-101', '1998').fetch
      expect(hits.first.to_s).to eq '<Iecbib::Hit:'\
        "#{format('%#.14x', hits.first.object_id << 1)} "\
        '@text="60050-101" @fetched="true" @fullIdentifier="IEC 60050-101-1998:1998" '\
        '@title="IEC 60050-101:1998">'
    end
  end

  describe 'get' do
    it 'gets a code' do
      VCR.use_cassette 'get_a_code' do
        results = Iecbib::IecBibliography.get('IEC 60050-102', nil, {}).to_xml
        expect(results).to include %(<bibitem type="international-standard" id="IEC60050-102">)
        expect(results).to include %(<on>2007</on>)
        expect(results.gsub(/<relation.*<\/relation>/m, '')).not_to include %(<on>2007</on>)
        expect(results).to include %(<docidentifier type="IEC">IEC 60050-102</docidentifier>)
        expect(results).not_to include %(<docidentifier type="IEC">IEC 60050</docidentifier>)
      end
    end
  end

  it 'gets a frozen reference for IEV' do
    results = Iecbib::IecBibliography.get('IEV', nil, {})
    expect(results.to_xml).to include %(<bibitem type="international-standard" id="IEC60050-2011">)
  end

  it 'warns when resource with part number not found on IEC website' do
    VCR.use_cassette 'varn_part_num_not_found' do
      expect { Iecbib::IecBibliography.get('IEC 60050-103', '207', {}) }
        .to output(/The provided document part may not exist, or the document may no longer be published in parts/).to_stderr 
    end
  end

  it "gets a frozen reference for IEV" do
    results = Iecbib::IecBibliography.get('IEV', nil, {})
    expect(results.to_xml).to include %(<bibitem type="international-standard" id="IEC60050-2011">)
  end

end
