module RelatonIec
  class DataFetcher
    ENTRYPOINT = "https://api.iec.ch/harmonized/publications?size=100&sortBy=urn&page=".freeze
    CREDENTIAL = "https://api.iec.ch/oauth/client_credential/accesstoken?grant_type=client_credentials".freeze
    LAST_CHANGE_FILE = "last_change.txt".freeze

    #
    # Initialize new instance.
    #
    # @param [String] source source name (iec-harmonized-all, iec-harmonized-latest)
    # @param [String] output output directory
    # @param [String] format format of output files (xml, bibxml, yaml)
    #
    def initialize(source = "iec-harmonised-latest", output: "data", format: "yaml")
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
      # @index = Index.new "index.yaml"
      @last_change = File.read(LAST_CHANGE_FILE, encoding: "UTF-8") if File.exist? LAST_CHANGE_FILE
      @last_change_max = @last_change.to_s
      @all = source == "iec-harmonised-all"
    end

    def last_change_max(date)
      @last_change_max = date if @last_change_max < date
    end

    def save_last_change
      return if @last_change_max.empty?

      File.write LAST_CHANGE_FILE, @last_change_max, encoding: "UTF-8"
    end

    #
    # Fetch data from IEC.
    #
    def fetch # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      t1 = Time.now
      puts "Started at: #{t1}"

      if @all
        FileUtils.rm_rf @output
      end
      FileUtils.mkdir_p @output
      fetch_all
      create_index
      save_last_change

      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    rescue StandardError => e
      Util.error do
        "#{e.message}\n#{e.backtrace.join("\n")}"
      end
    end

    def create_index
      index = Relaton::Index.find_or_create :IEC, file: "index1.yaml"
      index.remove_all
      Dir["{#{@output},static}/*.yaml"].each do |file|
        item = YAML.load_file file
        id = item["docid"].detect { |i| i["primary"] }["id"]
        index.add_or_update id, file
      end
      index.save
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
      if !@all && @last_change
        url += "&lastChangeTimestampFrom=#{@last_change}"
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
      file = File.join(@output, "#{did.id.downcase.gsub(/[:\s\/]/, '_')}.#{@ext}")
      if @files.include? file then Util.warn "File #{file} exists."
      else
        @files << file
        # @index.add index_id(pub), file, pub["lastChangeTimestamp"]
      end
      last_change_max pub["lastChangeTimestamp"]
      content = case @format
                when "xml" then bib.to_xml bibdata: true
                when "yaml", "yml" then bib.to_hash.to_yaml
                when "bibxml" then bib.to_bibxml
                end
      File.write file, content, encoding: "UTF-8"
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
  end
end
