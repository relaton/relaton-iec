require "iecbib/version"
require 'iecbib/iec_bibliography'
if defined? Relaton
  require_relative 'relaton/processor'
  Relaton::Registry.instance.register(Relaton::Iecbib::Processor)
end

module Iecbib
  # Your code goes here...
end
