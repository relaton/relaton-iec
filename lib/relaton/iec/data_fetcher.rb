require "relaton/core"
require_relative "../iec"
require_relative "data_parser"

module Relaton
  module Iec
    class DataFetcher < Relaton::Core::DataFetcher
      ENTRYPOINT = "https://api.iec.ch/harmonized/publications?size=100&sortBy=urn&page=".freeze
      CREDENTIAL = "https://api.iec.ch/oauth/client_credential/accesstoken?grant_type=client_credentials".freeze
      LAST_CHANGE_FILE = "last_change.txt".freeze

      #
      # Fetch data from IEC.
      #
      def fetch(source = "iec-harmonised-latest") # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        @all = source == "iec-harmonised-all"

        if @all
          FileUtils.rm_rf @output
        end
        FileUtils.mkdir_p @output
        fetch_all
        index.save
        save_last_change
      rescue StandardError => e
        Util.error do
          "#{e.message}\n#{e.backtrace.join("\n")}"
        end
      end

      private

      def last_change
        return @last_change if defined? @last_change

        @last_change = File.read(LAST_CHANGE_FILE, encoding: "UTF-8") if File.exist? LAST_CHANGE_FILE
      end

      def last_change_max
        @last_change_max ||= last_change.to_s
      end

      # def last_change_max(date)
      #   @last_change_max = date if last_change_max < date
      # end

      def save_last_change
        return if last_change_max.empty?

        File.write LAST_CHANGE_FILE, last_change_max, encoding: "UTF-8"
      end

      def index
        @index ||= Relaton::Index.find_or_create :iec, file: "#{INDEXFILE}.yaml"
      end

      #
      # Add static files to index.
      #
      # @return [void]
      #
      # def add_static_files_to_index
      #   Dir["static/*.yaml"].each do |file|
      #     pub = RelatonBib.parse_yaml File.read(file, encoding: "UTF-8")
      #     pubid = RelatonBib.array(pub["docid"]).detect { |id| id["primary"] }["id"]
      #     @index.add pubid, file
      #   end
      # end

      #
      # Fetch documents from IEC API.
      #
      # @return [void]
      #
      def fetch_all # rubocop:disable Metrics/MethodLength
        page = 0
        next_page = true
        while next_page
          res = fetch_page_token page
          unless res.code == "200"
            Util.warn "#{res.body}"
            break
          end
          json = JSON.parse res.body
          json["publication"].each { |pub| fetch_pub pub }
          page += 1
          next_page = res["link"]&.include? "rel=\"last\""
        end
      end

      #
      # Fetch page. If response code is 401, then get new access token and try
      #
      # @param [Integer] page page number
      #
      # @return [Net::HTTP::Response] response
      #
      def fetch_page_token(page)
        res = fetch_page page
        if res.code == "401"
          @access_token = nil
          res = fetch_page page
        end
        res
      end

      #
      # Fetch page from IEC API.
      #
      # @param [Integer] page page number
      #
      # @return [Net::HTTP::Response] response
      #
      def fetch_page(page)
        url = "#{ENTRYPOINT}#{page}"
        if !@all && last_change
          url += "&lastChangeTimestampFrom=#{last_change}"
        end
        uri = URI url
        req = Net::HTTP::Get.new uri
        req["Authorization"] = "Bearer #{access_token}"
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request req
        end
      end

      #
      # Get access token.
      #
      # @return [String] access token
      #
      def access_token # rubocop:disable Metrics/AbcSize
        @access_token ||= begin
          uri = URI CREDENTIAL
          req = Net::HTTP::Get.new uri
          req.basic_auth ENV.fetch("IEC_HAPI_PROJ_PUBS_KEY"), ENV.fetch("IEC_HAPI_PROJ_PUBS_SECRET")
          res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request req
          end
          JSON.parse(res.body)["access_token"]
        end
      end

      #
      # Fetch publication and save it to file.
      #
      # @param [Hash] pub publication
      #
      def fetch_pub(pub) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        bib = DataParser.new(pub).parse
        did = bib.docidentifier.detect &:primary
        file = output_file(did.content)
        if @files.include? file then Util.warn "File #{file} exists."
        else
          @files << file
          index.add_or_update index_id(pub), file # , pub["lastChangeTimestamp"]
        end
        @last_change_max = pub["lastChangeTimestamp"] if last_change_max < pub["lastChangeTimestamp"]
        File.write file, serialize(bib), encoding: "UTF-8"
      end

      def index_id(pub)
        /-(?<part>\d+)/ =~ pub["reference"]
        title = pub.dig("title", 0, "value")
        return pub["reference"] unless part && title

        ids = title.scan(/(?<=-\sPart\s)#{part[0]}\d+(?=:)/).map do |m|
          pub["reference"].sub(/-#{part}/, "-#{m}")
        end
        ids.size > 1 ? ids : pub["reference"]
      end

      def to_xml(bib)
        bib.to_xml bibdata: true
      end

      def to_yaml(bib)
        bib.to_yaml
      end
    end
  end
end
