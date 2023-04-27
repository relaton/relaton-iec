# describe RelatonIec::Index do
#   context "initialize" do
#     let(:path) { "#{Dir.home}/.relaton/iec/index.yaml" }

#     it "read local index file" do
#       expect(File).to receive(:exist?).with(path).and_return true
#       expect(File).to receive(:ctime).with(path).and_return Time.now
#       expect(File).to receive(:read).with(path, encoding: "UTF-8").and_return "--- []\n"
#       expect(subject.instance_variable_get(:@index)).to eq []
#       expect(subject.instance_variable_get(:@path)).to eq path
#     end

#     it "read index from github" do
#       expect(File).to receive(:exist?).with(path).and_return false
#       url = "https://raw.githubusercontent.com/relaton/relaton-data-iec/main/index.zip"
#       uri = double "uri"
#       resp = double "resp"
#       zip_entry = double "zip_entry"
#       expect(zip_entry).to receive(:get_input_stream).and_return StringIO.new("--- []\n")
#       expect(resp).to receive(:get_next_entry).and_return zip_entry
#       expect(uri).to receive(:open).with(no_args).and_return :archive
#       expect(URI).to receive(:parse).with(url).and_return uri
#       expect(Zip::InputStream).to receive(:new).with(:archive).and_return resp
#       expect(File).to receive(:write).with(path, "--- []\n", encoding: "UTF-8")
#       expect(subject.instance_variable_get(:@index)).to eq []
#       expect(subject.instance_variable_get(:@path)).to eq path
#     end

#     it "read GH repo index file" do
#       expect(File).to receive(:exist?).with("index.yaml").and_return true
#       expect(File).to receive(:read).with("index.yaml", encoding: "UTF-8").and_return "--- []\n"
#       subj = described_class.new "index.yaml"
#       expect(subj.instance_variable_get(:@index)).to eq []
#       expect(subj.instance_variable_get(:@path)).to eq "index.yaml"
#     end
#   end

#   context "instance methods" do
#     subject { RelatonIec::Index.new "index.yaml" }

#     it "#last_change" do
#       subj = described_class.new "index.yaml"
#       expect(subj.last_change).to be_nil
#       subj.instance_variable_set :@index, [{ last_change: "2018-01-01" }]
#       expect(subj.last_change).to eq "2018-01-01"
#     end

#     it "#save" do
#       expect(File).to receive(:write).with("index.yaml", "--- []\n", encoding: "UTF-8")
#       subject.save
#     end

#     context "#add" do
#       it "update existing entry" do
#         subject.instance_variable_set :@index, [{
#           pubid: "IEC 123", file: "iec_123.yaml", last_change: "2018-01-01"
#         }]
#         subject.add "IEC 123", "iec_123.yaml", "2019-01-01"
#         expect(subject.instance_variable_get(:@index)).to eq [{
#           pubid: "IEC 123", file: "iec_123.yaml", last_change: "2019-01-01"
#         }]
#       end
#     end

#     it "#clear" do
#       subject.instance_variable_set :@index, [1, 2, 3]
#       subject.clear
#       expect(subject.instance_variable_get(:@index)).to eq []
#     end
#   end
# end
