module RelatonIec
  class DataFetcher
    ENTRYPOINT = "https://api.iec.ch/harmonized/publications?size=100&sortBy=urn&page=".freeze
    CREDENTIAL = "https://api.iec.ch/oauth/client_credential/accesstoken?grant_type=client_credentials".freeze

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
      @index = Index.new "index.yaml"
      @all = source == "iec-harmonised-all"
    end

    #
    # Fetch data from IEC.
    #
    def fetch # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      t1 = Time.now
      puts "Started at: #{t1}"

      FileUtils.mkdir_p @output
      if @all
        FileUtils.rm Dir[File.join(@output, "*.#{@ext}")]
        @index.clear
      end
      fetch_all
      add_static_files_to_index
      @index.save

      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    rescue StandardError => e
      warn e.message
      warn e.backtrace.join("\n")
    end

    #
    # Add static files to index.
    #
    # @return [void]
    #
    def add_static_files_to_index
      Dir["static/*.yaml"].each do |file|
        pub = RelatonBib.parse_yaml File.read(file, encoding: "UTF-8")
        pubid = pub["docidentifier"].detect { |id| id["primary"] == true }["id"]
        @index.add pubid, file
      end
    end

    #
    # Fetch documents from IEC API.
    #
    # @return [void]
    #
    def fetch_all # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      page = 0
      next_page = true
      while next_page
        res = fetch_page page
        if res.code == "401"
          @access_token = nil
          res = fetch_page page
        end
        unless res.code == "200"
          warn "[relaton-iec] #{res.body}"
          break
        end
        json = JSON.parse res.body
        json["publication"].each { |pub| fetch_pub pub }
        page += 1
        next_page = res["link"]&.include? "rel=\"last\""
      end
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
      if !@all && @index.last_change
        url += "&lastChangeTimestampFrom=#{@index.last_change}"
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
      if @files.include? file then warn "File #{file} exists."
      else
        @files << file
        @index.add did.id, file, pub["lastChangeTimestamp"]
      end
      content = case @format
                when "xml" then bib.to_xml bibdata: true
                when "yaml", "yml" then bib.to_hash.to_yaml
                when "bibxml" then bib.to_bibxml
                end
      File.write file, content, encoding: "UTF-8"
    end
  end
end
