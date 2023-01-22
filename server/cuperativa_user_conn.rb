$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + "/.."

require "rubygems"
require "eventmachine"
require "base64"

require "src/network/prot_parsmsg"
require "src/network/prot_buildcmd"
require "mod_user_conn_handl"
require "database/sendemail_errors"
require "src/base/core/cup_strings"

module MyGameServer
  $conn_counter = 0

  ##
  # class CuperativaUserConn
  # Instance for each player, because each connection is associated to one player
  class CuperativaUserConn < EventMachine::Connection
    attr_reader :user_name
    attr_accessor :game_in_pro, :user_lag, :user_type, :user_stat

    include ParserCmdDef
    include ProtBuildCmd

    def initialize(*args)
      super
    rescue Exception
      @log.error "initialize error(#{$!})"
      error(detail)
    end

    # part adapted from protocol LineText2 - start
    MaxLineLength = 16 * 1024
    MaxBinaryLength = 32 * 1024 * 1024

    def is_guest?
      return @is_guest
    end

    #--
    # Will be called recursively until there's no data to read.
    # That way the user-defined handlers we call can modify the
    # handling characteristics on a per-token basis.
    #
    def receive_data(data)
      return unless (data and data.length > 0)

      if @lt2_mode == :lines
        if ix = data.index(@lt2_delimiter)
          @lt2_linebuffer << data[0...ix]
          ln = @lt2_linebuffer.join
          @lt2_linebuffer.clear
          if @lt2_delimiter == "\n"
            ln.chomp!
          end
          receive_line ln
          receive_data data[(ix + @lt2_delimiter.length)..-1]
        else
          @lt2_linebuffer << data
        end
      elsif @lt2_mode == :text
        if @lt2_textsize
          needed = @lt2_textsize - @lt2_textpos
          will_take = if data.length > needed
              needed
            else
              data.length
            end

          @lt2_textbuffer << data[0...will_take]
          tail = data[will_take..-1]

          @lt2_textpos += will_take
          if @lt2_textpos >= @lt2_textsize
            receive_binary_data @lt2_textbuffer.join
            set_line_mode
          end

          receive_data tail
        else
          receive_binary_data data
        end
      end
    end

    def set_delimiter(delim)
      @lt2_delimiter = delim.to_s
    end

    # Called internally but also exposed to user code, for the case in which
    # processing of binary data creates a need to transition back to line mode.
    # We support an optional parameter to "throw back" some data, which might
    # be an umprocessed chunk of the transmitted binary data, or something else
    # entirely.
    def set_line_mode(data = "")
      @lt2_mode = :lines
      (@lt2_linebuffer ||= []).clear
      receive_data data.to_s
    end

    def set_text_mode(size = nil)
      if size == 0
        set_line_mode
      else
        @lt2_mode = :text
        (@lt2_textbuffer ||= []).clear
        @lt2_textsize = size # which can be nil, signifying no limit
        @lt2_textpos = 0
      end
    end

    # part adapted from protocol LineText2 - end

    ##
    # Client is accepted, init stuff
    def post_init
      @log = Log4r::Logger["serv_main"]
      use_single_file_log = false
      if use_single_file_log
        @log = Log4r::Logger.new("connection_log")
        log_fnametime = Time.now.strftime("%Y_%m_%d_%H_%M_%S")
        $conn_counter += 1
        curr_day = Time.now.strftime("%Y_%m_%d")
        # put the log file into dayly destination folder
        base_dir_log = File.dirname(__FILE__) + "/logs/#{curr_day}"
        FileUtils.mkdir_p(base_dir_log)
        log_file_conn = File.join(base_dir_log, "/#{$conn_counter}_conn_#{log_fnametime}.log")
        FileOutputter.new("connection_log", :filename => log_file_conn)
        Log4r::Logger["connection_log"].add "connection_log"
        Log4r::Logger["connection_log"].level = INFO
      end

      @is_guest = false
      @ping_request = false
      @lt2_mode ||= :lines
      @lt2_delimiter ||= ProtCommandConstants::CRLF #defined in ParserCmdDef
      @lt2_linebuffer ||= []
      @start_time = Time.now
      @user_name = ""
      @state_con = :created
      @main_my_srv = CuperativaServer.instance
      @conh_settings = @main_my_srv.serv_settings[:connhandler_opt]
      @version_to_package = @conh_settings[:version_to_package]
      # send server version
      send_data(build_cmd(:ver, "#{VER_MAJ}.#{VER_MIN}"))
      # send welcome message
      send_data(build_cmd(:info, "Benvenuto sul server - Cuperativa - (#{PRG_VERSION}) "))
      send_data(build_cmd(:info, "Per ogni evenienza controlla il sito: http://cup.invido.it"))
      @main_my_srv.add_conn(self)
      #log "Player online #{@clients.size}"

      # game in progress
      @game_in_pro = nil
      # user lag (1 = poor, 5 good)
      @user_lag = 5
      # user type (G)uest, (P)layer registered, (A)dmin
      @user_type = "G"
      # user info (staistic, status.....)
      @user_stat = "-"
      # peer information
      begin
        # read ip info using EventMachine function
        data_peername = get_peername
        if data_peername != nil
          sender_info = data_peername[2, 6].unpack("nC4")
          port = sender_info[0]
          if sender_info[1..4]
            ip = sender_info[1..4].join(".").to_s
            @log.info("Peer information: #{ip}:#{port}")
          else
            @log.info("Peer information: ipnotfound:#{port}")
          end
        end
      rescue => detail
        @log.error "post_init error(#{$!})"
        error(detail)
      end
    rescue Exception
      @log.error "post_init error(#{$!})"
      error(detail)
    end

    def has_leaved?
      @state_con == :logged_out ? true : false
    end

    def receive_line(line)
      #p line
      @ping_request = false # client is alive
      pl_message = line
      arr_cmd_msg = pl_message.split(":")
      @log.debug "Line is #{line}"
      unless arr_cmd_msg
        @log.warn "receives a malformed line error (#{line})"
        return
      end
      cmd = arr_cmd_msg.first
      cmd_details = ""
      # details of command
      if arr_cmd_msg[1..-1]
        cmd_details = arr_cmd_msg[1..-1].join(":")
      end
      #retreive the symbol of the command handler
      meth_parsed = nil
      ProtCommandConstants::SUPP_COMMANDS.each do |k, v|
        meth_parsed = v[:cmdh] if v[:liter] == cmd
      end
      # call the command handler
      if meth_parsed != :cmdh_login && @state_con != :logged_in
        # player not logged in, ignore message
        @log.warn "[#{@user_name}]: not logged in, ignore msg \"#{pl_message.chomp}\""
      else
        if meth_parsed
          # method accepted, because player is already logged in
          send meth_parsed, cmd_details.chomp
        else
          @log.error("Line recived is not recognized and ignored #{line}")
        end
      end
    rescue => detail
      @log.error "receive_line error(#{$!})"
      error(detail)
    end

    ##
    # Closing connection notification
    def unbind
      #elapsed = (Time.now - @start_time).strftime("%H:%M:%S") # questo NON VA
      elapsed = (Time.now - @start_time)
      if @lt2_mode == :text and @lt2_textpos > 0
        receive_binary_data @lt2_textbuffer.join
      end

      if @game_in_pro
        @log.warn "Player #{@user_name} disconnect a game in progress without leaving table"
        # TODO: when you implement a game serializer you can use accidental disconnect
        #@main_my_srv.game_inprog_player_accidental_disconnect(@user_name, @game_in_pro.ix_game, @game_in_pro, :player_accident_disconnect)
        @main_my_srv.game_inprog_playerleave(@user_name, @game_in_pro.ix_game, @game_in_pro)
      end

      @main_my_srv.remove_connection(self)
      @log.info("#{@user_name} Connection closed, time connected: #{elapsed}")
    end

    def send_ping()
      @ping_request = true
      cmd_ping = build_cmd(:ping_req, "")
      send_data(cmd_ping)
    end

    ##
    # Provides the status of a ping request. Request is turned off when data
    # are received
    def ping_is_pending?
      return @ping_request
    end

    def log(str)
      @log.info(str)
    end

    def log_debug(str)
      @log.debug(str)
    end

    ##
    # Log chat message in the current table log channel
    def log_table(str)
      @game_in_pro.nal_server.log_table_comm(str) if @game_in_pro
    end

    def error(detail)
      @log.error("ERROR connection:")
      @log.error(detail.backtrace.join("\n"))
      # send also an email for this kind of errors
      sender = EmailErrorSender.new(@log)
      sender.send_email("#{$!}\n" + detail.backtrace.join("\n"))
    end

    ##
    # default logger for prot_parmsg.rb
    def log_sometext(str)
      log str
    end

    def send_data(data)
      # for TEST if you want to put some delay before data are sent
      #sleep rand
      # Guardando il codice in cpp sembra che send_data scriva i dati
      # in una coda di output. Quindi un'ulteriore code non dovrebbe servire
      super(data)
    end

    #
    # COMMAND HANDLER
    #

    include UserConnCmdHanler
  end #end CuperativaUserConn
end #module
