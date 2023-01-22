# usage: ruby daemon_cup.rb start
#        ruby daemon_cup.rb stop

$:.unshift File.dirname(__FILE__)

require "rubygems"
require "daemons"

Daemons.run(File.dirname(__FILE__) + "/cuperativa_server_starter.rb")
