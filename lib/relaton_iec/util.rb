module RelatonIec
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonIec.configuration.logger
    end
  end
end
