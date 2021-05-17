module RelatonIec
  class Eref < RelatonIec::ErefType
    #
    # @param [Nokogiri::XML::Builder] builder
    #
    def to_xml(builder)
      builder.eref { super }
    end
  end
end
