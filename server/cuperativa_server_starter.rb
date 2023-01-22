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
require "err_logger"

include Log4r

module MyGameServer
  class CupServRunner
    include MyErr

    def initialize
      @serv_settings = {}
      @settings_default = {
        :ip => "127.0.0.1", :port => 20606,
        :email_crash => {
          :email_to => "",
          :email_relayfrom => "",
          :relay_user => "",
          :relay_secret => "",
          :relay_host => "",
          :send_email => false,
        },
        :logpath => "../../logs",
        :database => {
          :user_db => "",
          :pasw_db => "",
          :mod_type => "pg",
          :db_name => "cupuserdatadb",
        },
        :autorestart_on_err => false,
      }
      @settings_filename = File.dirname(__FILE__) + "/options.yaml"
      # server core instance. The instance is set after initializing the logger
      @main_my_srv = nil #CuperativaServer.instance
      @send_email_on_err = @settings_default[:email_crash][:send_email]
    end

    def initlog(target)
      begin
        #p @serv_settings
        @log = Log4r::Logger.new("serv_main")
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
          :trunc => true, # with true a new file is created, otherwise append
          :formatter => myApacheLikeFormat,
        })

        Log4r::Logger["serv_main"].add "serv_main"
        # open a file for standard error, usefull to cache emachine errors
        STDERR.reopen(mystderr_file, "w")
        #@log.outputters =  mybaseApacheLikeLog
        if target == :test
          @log.outputters << Outputter.stdout
        else
          @log.level = INFO
        end
        # now we can get the server beacuse logger is initiated
        @main_my_srv = CuperativaServer.instance
        @main_my_srv.set_dir_log(logpath_abs)
        @log.debug "Init log dir #{logpath_abs} ok"
      rescue
        str_err = "Server crashed error: #{$!}"
        error_msg(str_err, "Server Crash (Init Log)", @log, @send_email_on_err)
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
      @send_email_on_err = @serv_settings[:email_crash][:send_email]
    end

    def run
      @log.info "Run the server"
      @main_my_srv.set_settings(@serv_settings)
      stopped_by_shutdown = false

      trap(:INT) {
        #shutdown with ctr-c
        p "Shutdown the server" # do not use @log in trap
        EventMachine::stop
        stopped_by_shutdown = true
      }

      while true
        # when the server crash because an error, then restart it
        # dont' restart it only if it was :INT trap
        begin
          server_loop # blocking call, exit only when server is stopped for some other reason like a crash
          @log.info "Server is now OFF"
        rescue => detail
          error_trace(detail, "Server Crash", @log, @send_email_on_err)
          #p "error #{detail}"
        rescue Exception
          msg = "Server run exception (#{$!})"
          error_msg(msg, "Server Crash", @log, @send_email_on_err)
        ensure
          if stopped_by_shutdown or not @serv_settings[:autorestart_on_err]
            break
          else
            @log.info "Restarting the server..."
          end
        end
      end
      @log.info "Server turning off because run terminated"
    end

    def server_loop
      @log.debug "Enter into the server loop"
      @main_my_srv.create_connector(@serv_settings[:database])

      EventMachine::run {
        host = @serv_settings[:ip]
        port = @serv_settings[:port]
        # start the game server
        EventMachine::start_server(host, port, MyGameServer::CuperativaUserConn)
        @log.info("*** Now accepting connections on address #{host}:#{port}")
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
