module RelatonIec
  class Index
    #
    # Initialize index.
    # If index argument is nil, read index from file or from GitHub.
    # If index argument is not nil, then read index from file or create new
    # empty index. (use this option for creating index for dataset)
    #
    # @param [String, nil] index to index file
    #
    def initialize(index = nil)
      if index
        @path = index
        @index = create_index_file
      else
        @index = read_index_file || get_index_from_gh
      end
    end

    #
    # Add document to index or update existing document
    #
    # @param [String] pubid document identifier
    # @param [String] file document file name
    # @param [String] change last change date time
    #
    # @return [void]
    #
    def add(pubid, file, change = nil)
      item = @index.find { |i| i[:pubid] == pubid }
      if item
        item[:file] = file
        item[:last_change] = change if change
      else
        item = { pubid: pubid, file: file }
        item[:last_change] = change if change
        @index << item
      end
    end

    #
    # Clear index
    #
    # @return [void]
    #
    def clear
      @index.clear
    end

    #
    # Last change date
    #
    # @return [String] <description>
    #
    def last_change
      return unless @index.any?

      @last_change ||= @index.max_by { |i| i[:last_change].to_s }[:last_change]
    end

    #
    # Save index to file
    #
    # @return [void]
    #
    def save
      File.write @path, @index.to_yaml, encoding: "UTF-8"
    end

    private

    #
    # Create dir if need and return path to index file
    #
    # @return [String] path to index file
    #
    def path
      @path ||= begin
        dir = File.join Dir.home, ".relaton", "iec"
        FileUtils.mkdir_p dir
        File.join dir, "index.yaml"
      end
    end

    #
    # Create index file for dataset
    #
    # @return [Array<Hash>] index content
    #
    def create_index_file
      return [] unless File.exist? path

      RelatonBib.parse_yaml File.read(path, encoding: "UTF-8"), [Symbol]
    end

    #
    # Read index from file if it exists and not outdated
    #
    # @return [Hash, nil] index content
    #
    def read_index_file
      return if !File.exist?(path) || File.ctime(path).to_date < Date.today

      RelatonBib.parse_yaml File.read(path, encoding: "UTF-8"), [Symbol]
    end

    #
    # Get index from a GitHub repository
    #
    # @return [Hash] index content
    #
    def get_index_from_gh # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      resp = Zip::InputStream.new URI("#{HitCollection::GHURL}index.zip").open
      zip = resp.get_next_entry
      index = RelatonBib.parse_yaml zip.get_input_stream.read
      File.write path, index.to_yaml, encoding: "UTF-8"
      index
    end
  end
end