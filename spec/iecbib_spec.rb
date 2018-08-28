require 'open-uri'

RSpec.describe Iecbib do
  it "has a version number" do
    expect(Iecbib::VERSION).not_to be nil
  end

  it 'fetch hits of page' do
    open_uri_stub
    hit_collection = Iecbib::IecBibliography.search('60050-102', '2007')
    expect(hit_collection.fetched).to be_falsy
    expect(hit_collection.fetch).to be_instance_of Iecbib::HitCollection
    expect(hit_collection.fetched).to be_truthy
    expect(hit_collection.first).to be_instance_of Iecbib::Hit
  end

  private

  def open_uri_stub(ext = 'html', count: 1)
    expect(OpenURI).to receive(:open_uri).and_wrap_original do |m, *args|
      nbr_year = args[0].match /(?<=RefNbr=)(?<nbr>[^&]+).+(?<=From=)(?<year>\d*)/
      ref = nbr_year[:nbr]
      ref += "_#{nbr_year[:year]}" unless nbr_year[:year].empty?
      expect(args[0]).to be_instance_of String
      fetch_data(ref, ext) { m.call(*args).read }
    end.exactly(count).times
  end

  def file_path(ref, ext)
    file_name = ref.downcase.delete('/').gsub(/[\s-]/, '_')
    "spec/examples/#{file_name}.#{ext}"
  end

  def fetch_data(ref, ext)
    decoded_ref = URI.decode_www_form_component(ref).tr([8212].pack('U'), '-')
    file = file_path decoded_ref, ext
    File.write file, yield unless File.exist? file
    File.open file
  end
end
