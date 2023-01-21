#file: table_parser.rb

class TableReqParser
  
  def initialize
    Log4r::Logger.new("serv_main::TableReqParser")
  end
  
  def parse(msg_details)
      p info = YAML::load(msg_details)
  end
    
end


if $0 == __FILE__
  require 'rubygems'
  require 'log4r'
  require 'yaml'
  
  include Log4r
  log = Log4r::Logger.new("serv_main")
  log.outputters << Outputter.stdout
  
  parser = TableReqParser.new
  parser.parse("--- ")
  
end