module Relaton
  module Iec
    class Docidentifier < Bib::Docidentifier
      def remove_date!
        if type == "URN"
          # URN format: urn:iec:std:iec:60050-102:2007:::::amd:1:2017
          # Remove the year portion (5th segment) which may include month
          self.content = content.sub(/^(urn:iec:std:[^:]+:[^:]+):\d{4}(?:-\d{2})?/, '\1')
        else
          self.content = content.sub(/:\d{4}(?=\s|$)/, "")
        end
      end

      def remove_part!
        if type == "URN"
          # URN format: urn:iec:std:iec:60050-102:2007:::
          # Remove the part number(s) from the document number segment (4th segment)
          self.content = content.sub(/^(urn:iec:std:[^:]+:[^:-]+)-\d+(?:-\d+)*/, '\1')
        else
          self.content = content.sub(/-\d+(?:-\d+)*/, "")
        end
      end

      def remove_stage!
        # IEC IDs don't have stage indicators - no-op
      end

      def to_all_parts!
        remove_part!
        remove_date!
        remove_stage!
        if type == "URN"
          self.content += "ser" unless content.end_with?(":ser")
        elsif type == "IEC" && !content.include?(" (all parts)")
          self.content += " (all parts)"
        end
      end
    end
  end
end
