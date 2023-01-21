# file: cup_server_runner.rb
# on production server start the server using daemon_cup.rb

$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + "/.."

require "rubygems"
require "lib/log4r"
require "eventmachine"
require "cuperativa_user_conn"
require "singleton"
require "pg_item"
require "game_in_prog_item"
require "nal_srv_algorithm"
require "cuperativa_server"
require "database/sendemail_errors"

$g_os_type = :win32_system
begin
  require "win32/sound"
rescue LoadError
  $g_os_type = :linux
end

include Log4r

module MyGameServer

  ##
  # Class used to run the server
  class CupServRunner
    def initialize
      @serv_settings = {}
      @settings_default = {
        :ip => "127.0.0.1", :port => 20606, :login_email => "",
        :password_email => "", :publickey_server => "00000", :secret_server => "00",
        :test_local_service => true, :logpath => "../logs",
        :database => {
          :user_db => "",
          :pasw_db => "",
          :use_sqlite3 => false,
          :db_name => "cupuserdatadb",
        },
        :connhandler_opt => {},
      }
      @settings_filename = File.dirname(__FILE__) + "/options.yaml"
      # server core instance. The instance is set after initializing the logger
      @main_my_srv = nil #CuperativaServer.instance
    end

    def initlog(target)
      begin
        #p @serv_settings
        @logger = Log4r::Logger.new("serv_main")
        logpath_abs = File.expand_path(@serv_settings[:logpath], __FILE__)
        out_log_name = File.join(logpath_abs, "#{Time.now.strftime("%Y_%m_%d_%H_%M_%S")}cup_server.log")
        mystderr_file = File.join(logpath_abs, "cup_stderr#{Time.now.strftime("%Y_%m_%d_%H_%M_%S")}.log")
        #FileOutputter.new('coregame_log', :filename=> out_log_name)
        myApacheLikeFormat = PatternFormatter.new(:pattern => "[%d] %m") # questo usa [data] <testo>
        mybaseApacheLikeLog = RollingFileOutputter.new("serv_main", {
          :maxsize => 999999999,
          :maxtime => 86400, # tempo in secondi (1 * 14 giorni). Dopo 14 giorni avviene il rollout e
          # quindi viene creato un nuovo file
          :filename => out_log_name,
          :trunc => true, # se true viene usato 'w' in File.open, altrimenti con false 'a'
          # voglio 'a' in quanto ogni volta che viene chiamato lo script, devo avere un append
          :formatter => myApacheLikeFormat,
        })

        Log4r::Logger["serv_main"].add "serv_main"
        # open a file for standard error, usefull to cache emachine errors
        STDERR.reopen(mystderr_file, "w")
        #@logger.outputters =  mybaseApacheLikeLog
        if target == :test
          @logger.outputters << Outputter.stdout
        else
          @logger.level = INFO
        end
        # now we can get the server beacuse logger is initiated
        @main_my_srv = CuperativaServer.instance
        @main_my_srv.set_dir_log(logpath_abs)
        @logger.debug "Init #{logpath_abs} log ok"
      rescue
        str_err = "Server crashed error: #{$!}"
        str_err += detail.backtrace.join("\n")
        p "error #{str_err}"
        @logger.error "error #{str_err}"
        exit
      end
    end

    def load_settings
      p "Load settings..."
      yamloptions = {}
      prop_options = {}
      yamloptions = YAML::load_file(@settings_filename) if File.exist?(@settings_filename)
      prop_options = yamloptions if yamloptions.class == Hash
      @settings_default.each do |k, v|
        if prop_options[k] != nil
          # use settings from yaml
          @serv_settings[k] = prop_options[k]
        else
          # use default settings
          @serv_settings[k] = v
        end
      end
      #p @serv_settings
    end

    def run
      @main_my_srv.set_settings(@serv_settings)
      stopped_by_shutdown = false

      # avoid brutal shutdown with ctr-c
      trap(:INT) {
        @logger.info("Shutdown the server")
        EventMachine::stop
        stopped_by_shutdown = true
        # set server info for OFFLINE modus
      }
      if $g_os_type == :win32_system
        stopped_by_shutdown = true #on windows trap doesn't work
      end

      while true
        # when the server crash because an error, then restart it
        # dont' restart it only if it was :INT trap
        begin
          go_server_go() # blocking call, exit only when server is stopped for some reason
          @logger.info "Server is now OFF"
        rescue => detail
          @logger.error "Server crashed error(#{$!})"
          @logger.error(detail)
          str_err = "Server crashed error: #{$!}"
          str_err += detail.backtrace.join("\n")
          sender = EmailErrorSender.new(@logger)
          sender.send_email("Match server error:\n" + ("#{str_err}\n"))
        ensure
          break if stopped_by_shutdown
          @logger.info "Restarting the server..."
        end
      end
    end

    def go_server_go
      EventMachine::run {
        host = @serv_settings[:ip]
        port = @serv_settings[:port]

        # connect to the db
        @main_my_srv.connect_to_db(@serv_settings[:database][:user_db],
                                   @serv_settings[:database][:pasw_db],
                                   @serv_settings[:database][:db_name],
                                   @serv_settings[:database][:use_sqlite3])

        #
        # start the game server
        EventMachine::start_server(host, port, MyGameServer::CuperativaUserConn)
        #p a.class # class is string
        #p a # something like "efa022d6-dd65-41b7-b84f-d4afeec0b5392"
        @logger.info("*** Now accepting connections on address #{host}:#{port}")
        #EventMachine::add_periodic_timer( 10 ) { $stderr.write "*" }
        EventMachine::add_periodic_timer(300) { @main_my_srv.ping_clients() }
        EventMachine::add_periodic_timer(0.03) { @main_my_srv.process_game_in_progress }
      }
    end
  end #end class CupServRunner
end #end module

if $0 == __FILE__
  p "WARNING: Do nothing, instead  use: ruby daemon_cup.rb run"
  # Vale a dire lancia daemon_cup.rb come target e run come opzione
end
###################
## PART used when the server is started using daemon
###################
runner = MyGameServer::CupServRunner.new
runner.load_settings
runner.initlog(:test)
runner.run
