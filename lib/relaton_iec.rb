require "relaton_iec/version"
require "relaton_iec/iec_bibliography"
if defined? Relaton
  require_relative "relaton/processor"
  Relaton::Registry.instance.register(Relaton::RelatonIec::Processor)
end

module RelatonIec
  # Your code goes here...
end
