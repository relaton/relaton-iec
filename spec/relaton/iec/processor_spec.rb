# frozen_string_literal: true

require "relaton/iec/processor"

RSpec.describe Relaton::Iec::Processor do
  subject(:processor) { described_class.new }

  describe "#initialize" do
    it "sets short" do
      expect(processor.short).to eq :relaton_iec
    end

    it "sets prefix" do
      expect(processor.prefix).to eq "IEC"
    end

    it "sets defaultprefix" do
      expect(processor.defaultprefix).to eq %r{^(IEC\s|CISPR\s|IEV($|\s))}
    end

    it "sets idtype" do
      expect(processor.idtype).to eq "IEC"
    end

    it "sets datasets" do
      expect(processor.datasets).to eq %w[iec-harmonized-all iec-harmonized-latest]
    end
  end

  describe "#get" do
    it "delegates to Bibliography.get" do
      expect(Relaton::Iec::Bibliography).to receive(:get).with("IEC 60050-102", "2007", {}).and_return(nil)
      processor.get("IEC 60050-102", "2007", {})
    end
  end

  describe "#fetch_data" do
    before { require "relaton/iec/data_fetcher" }

    it "delegates to DataFetcher.fetch" do
      expect(Relaton::Iec::DataFetcher).to receive(:fetch).with("iec-harmonized-all", output: "data", format: "yaml")
      processor.fetch_data("iec-harmonized-all", output: "data", format: "yaml")
    end
  end

  describe "#from_xml" do
    it "delegates to Item.from_xml" do
      xml = File.read("spec/fixtures/hit.xml", encoding: "UTF-8")
      expect(Relaton::Iec::Item).to receive(:from_xml).with(xml).and_call_original
      result = processor.from_xml(xml)
      expect(result).to be_instance_of Relaton::Iec::ItemData
    end
  end

  describe "#from_yaml" do
    it "delegates to Item.from_yaml" do
      yaml = File.read("spec/fixtures/item.yaml", encoding: "UTF-8")
      expect(Relaton::Iec::Item).to receive(:from_yaml).with(yaml).and_call_original
      result = processor.from_yaml(yaml)
      expect(result).to be_instance_of Relaton::Iec::ItemData
    end
  end

  describe "#grammar_hash" do
    it "returns grammar hash" do
      expect(processor.grammar_hash).to be_instance_of String
      expect(processor.grammar_hash.size).to eq 32
    end

    it "delegates to Relaton::Iec.grammar_hash" do
      expect(Relaton::Iec).to receive(:grammar_hash).and_call_original
      processor.grammar_hash
    end
  end

  describe "#urn_to_code" do
    it "delegates to Relaton::Iec.urn_to_code" do
      urn = "urn:iec:std:iec:60050-102:2007:::::amd:1:2017"
      expect(Relaton::Iec).to receive(:urn_to_code).with(urn).and_call_original
      result = processor.urn_to_code(urn)
      expect(result).to eq ["IEC 60050-102:2007/AMD1:2017", ""]
    end
  end

  describe "#remove_index_file" do
    it "removes index file" do
      index = double("index")
      expect(Relaton::Index).to receive(:find_or_create).with(
        :iec, url: true, file: "#{Relaton::Iec::INDEXFILE}.yaml"
      ).and_return(index)
      expect(index).to receive(:remove_file)
      processor.remove_index_file
    end
  end
end
