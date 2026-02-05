module RelatonIec
  class DocumentIdentifier < RelatonBib::DocumentIdentifier
    def id
      return @id unless @id.is_a?(Pubid::Iec::Base)

      if @all_parts
        if type == "URN"
          return "#{@id.urn}:ser"
        else
          return "#{@id} (all parts)"
        end
      end
      type == "URN" ? @id.urn.to_s : @id.to_s
    end

    def remove_part
      return super unless @id.respond_to?(:part=)

      @id.part = nil
    end

    def remove_date
      return super unless @id.respond_to?(:year=)

      @id.year = nil
    end

    def all_parts
      return super unless @id.is_a?(Pubid::Iec::Base)

      @all_parts = true
    end
  end
end
