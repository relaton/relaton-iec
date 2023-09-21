module RelatonIec
  module Config
    include RelatonBib::Config
  end
  extend Config

  class Configuration < RelatonBib::Configuration
    PROGNAME = "relaton-iec".freeze
  end
end
