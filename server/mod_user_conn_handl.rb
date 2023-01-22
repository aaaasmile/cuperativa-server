#file mod_user_conn_handl.rb
# Implementation of connection command handler part

module UserConnCmdHanler

  # version (protocol and program)
  # This two values force the version check when the client make a login
  VER_MAJ = 16 #please increment this value also for a little update
  VER_MIN = 0
  # used als information
  PRG_VERSION = "srv_0.23.1 20230122"

  ##
  # handle command CHATLOBBY
  def cmdh_chatlobby(msg_details)
    @log.debug "CHATLOBBY handler #{msg_details}"
    # send the chat message to all players in the lobby but not the sender
    cmd_for_all = build_cmd(:chat_lobby, "#{@user_name}>#{msg_details}")
    @main_my_srv.send_cmd_to_all(cmd_for_all)
  end

  ##
  # handle command CHATTAVOLO
  def cmdh_chattavolo(msg_details)
    log_table "CHAT_T:#{@user_name}> #{msg_details}"
    # send the chat message to all on the table
    cmd_chat = build_cmd(:chat_tavolo, "#{@user_name}>#{msg_details}")
    # TO DO: filter fuck words
    if @game_in_pro
      @main_my_srv.send_cmd_to_gameinpro(@game_in_pro.ix_game, cmd_chat)
    end
  end

  ##
  # handle command LOGIN
  def cmdh_login(msg_details)
    @log.debug "LOGIN handler"
    if @state_con != :logged_in
      code_err = 0
      name, password64 = msg_details.split(",")
      unless name
        send_data(build_cmd(:login_error,
                            YAML.dump(:code => 4, :info => "username invalido")))
        send_data(build_cmd(:info, "Login fallito, username invalido."))
        @log.error "login of with name nil failed"
        # close connection after writing data. Unbind callback is than called
        close_connection_after_writing
        return
      end
      # avoid funny characters on name
      name = name.slice(/\A\w[\w\.\-_@]+\z/)
      # if guest add id
      name_guest = @main_my_srv.analyze_guest(name)

      if name_guest != name
        # guest login
        @log.debug "Guest login with assigned name #{name_guest}"
        name = name_guest
        @is_guest = true
        code_err = @main_my_srv.set_guest_connected(name, self)
      else
        # usual login of registered player
        password = ""
        password = Base64::decode64(password64) if password64
        code_err = @main_my_srv.accept_name?(name, password, self)
      end
      log "player name to log is: #{name}"

      if code_err == 0
        # login OK
        @user_name = name
        if @main_my_srv.game_inprog_player_reconnect?(self)
          str_cmd = YAML.dump({ :cmd => :game_in_progress })
          send_data(build_cmd(:player_reconnect, str_cmd))
          log "Player #{name} reconnect to a game in progress"
        else
          send_data(build_cmd(:login_ok, "#{name}"))
          log "Player #{name} logged in"
        end
        # when a new player is logged in, inform also other players
        @state_con = :logged_in
        @main_my_srv.inform_all_about_newuser(self)
      else
        # player login failed
        send_data(build_cmd(:login_error, YAML.dump(:code => code_err, :info => "Login fallito, password oppure login non validi")))
        @log.error "login of #{name} failed"
        send_data(build_cmd(:info, "Login fallito, password oppure login non validi."))
        # close connection after writing data. Unbind callback is than called
        close_connection_after_writing
      end
    end
  rescue => detail
    @log.error "cmdh_login error(#{$!})"
    error(detail)
  end

  ##
  # Handle command PENDINGGAMESREQ2
  def cmdh_pendig_games_req2(msg_details)
    @log.debug "PENDINGGAMESREQ2 handler"
    @main_my_srv.pending_games_req_list2(self)
  end

  def cmdh_player_reconnect(msg_details)
  end

  ##
  # Handle command USERSCONNECTREQ
  def cmdh_users_connect_req(msg_details)
    @log.debug "USERSCONNECTREQ handler"
    @main_my_srv.user_req_list(self)
  end

  ##
  # Handle command USERLISTUNSUB
  def cmdh_user_list_unsub(msg_details)
    @log.debug "USERLISTUNSUB handler"
    @main_my_srv.unsubscribe_user_userdatalist(self.user_name)
  end

  ##
  # Handle command PGCREATE2
  def cmdh_pg_create2(msg_details)
    info = YAML::load(msg_details)
    @log.debug "PGCREATE2: #{ObjTos.stringify(info)}"
    @main_my_srv.pending_game_create2(self, info)
  end

  ##
  # Handle command PGREMOVEREQ
  def cmdh_pg_remove_req(msg_details)
    @log.debug "PGREMOVEREQ handler"
    @main_my_srv.pending_game_removereq(self, msg_details)
  end

  ##
  # Handle command PGJOIN
  def cmdh_pg_join(msg_details)
    @log.debug "PGJOIN: #{msg_details}"
    @main_my_srv.join_request(self, msg_details)
  end

  def cmdh_game_view(msg_details)
    info = YAML::load(msg_details)
    @log.debug "GAMEVIEW: #{info[:cmd]}"
    @main_my_srv.game_view_parse_cmd(self, info)
  end

  ##
  # Handle command PGJOINPIN
  def cmdh_pg_join_pin(msg_details)
    @log.debug "PGJOINPIN handler"
    tmp = msg_details.split(",")
    if tmp.size == 2
      pg_ix = tmp[0]
      pin = tmp[1]
      @main_my_srv.join_req_private(self, pg_ix, pin)
    else
      # format error
      send_data build_cmd(:pg_join_reject, "PGJOINPIN Message format error")
    end
  end

  ##
  # Handle command PGJOINOK
  def cmdh_pg_join_ok(msg_details)
    @log.debug "PGJOINOK handler"
    tmp = msg_details.split(",")
    if tmp.size == 2
      tender_user_name = tmp[0]
      pg_index = tmp[1]
      @main_my_srv.joinok(self, tender_user_name, pg_index)
    else
      @log.error("Client PGJOINOK fomat error")
    end
  end

  ##
  # Handle command ALGPLAYERCHANGEBRISCOLA
  def cmdh_alg_player_change_briscola(msg_details)
    #@log.debug "ALGPLAYERCHANGEBRISCOLA handler"
    tmp = msg_details.split(",")
    if tmp.size == 3
      user_name = tmp[0]
      card_briscola = tmp[1].to_sym
      card_on_hand = tmp[2].to_sym
      if @game_in_pro
        @game_in_pro.nal_server.alg_player_change_briscola(user_name, card_briscola, card_on_hand)
      else
        @log.warn("cmdh_alg_player_change_briscola called without game_in_pro object")
      end
    else
      @log.error("Client ALGPLAYERCHANGEBRISCOLA format error")
    end
  end

  ##
  # Handle command ALGPLAYERDECLARE
  def cmdh_alg_player_declare(msg_details)
    #@log.debug "ALGPLAYERDECLARE handler"
    tmp = msg_details.split(",")
    if tmp.size == 2
      user_name = tmp[0]
      name_decl = tmp[1].to_sym
      if @game_in_pro
        @game_in_pro.nal_server.alg_player_declare(user_name, name_decl)
      else
        @log.warn("cmdh_alg_player_declare called without game_in_pro object")
      end
    else
      @log.error("Client ALGPLAYERDECLARE fomat error")
    end
  end

  ##
  # Handle command ALGPLAYERCARDPLAYED
  def cmdh_alg_player_cardplayed(msg_details)
    #@log.debug "ALGPLAYERCARDPLAYED handler"
    tmp = msg_details.split(",")
    if tmp.size == 2
      user_name = tmp[0]
      card = tmp[1].to_sym
      if @game_in_pro
        @game_in_pro.nal_server.alg_player_cardplayed(user_name, card)
      else
        @log.warn("cmdh_alg_player_cardplayed called without game_in_pro object")
      end
    else
      @log.error("Client ALGPLAYERCARDPLAYED format error")
    end
  end

  ##
  # Handle command ALGPLAYERCARDPLAYEDARR
  # Expect the first element the player, then the array of played cards
  def cmdh_alg_player_cardplayed_arr(msg_details)
    tmp = msg_details.split(",")
    if tmp.size >= 2
      user_name = tmp[0]
      card_arr = []
      tmp[1..-1].each { |e| card_arr << e.to_sym }
      if @game_in_pro
        @game_in_pro.nal_server.alg_player_cardplayed_arr(user_name, card_arr)
      else
        @log.warn("cmdh_alg_player_cardplayed_arr called without game_in_pro object")
      end
    else
      @log.error("Client ALGPLAYERCARDPLAYED format error")
    end
  end

  ##
  # Handle command GUINEWSEGNO
  def cmdh_gui_new_segno(msg_details)
    @log.debug "GUINEWSEGNO handler"
    if @game_in_pro
      @game_in_pro.nal_server.gui_new_segno(@user_name)
    else
      @log.warn("cmdh_gui_new_segno called without game_in_pro object")
    end
  end

  ##
  # Handle command LEAVETABLE
  def cmdh_leave_table(msg_details)
    @log.debug "LEAVETABLE handler"
    ix_game = msg_details
    if @game_in_pro and ix_game == @game_in_pro.ix_game
      # when the player intentionaly leave the table it is an abandon
      @main_my_srv.game_inprog_playerleave(@user_name, @game_in_pro.ix_game, @game_in_pro)
      @game_in_pro = nil
    else
      @log.warn("Player leave a game in progress not recognized as current. Expected #{@game_in_pro.ix_game}, but received #{ix_game}") if @game_in_pro
    end
  end

  ##
  # Handle command RESIGNGAME
  def cmdh_resign_game(msg_details)
    @log.debug "RESIGNGAME handler"
    ix_game = msg_details
    if @game_in_pro and ix_game == @game_in_pro.ix_game
      @game_in_pro.player_abandon(@user_name)
    else
      @log.warn("Player resign a game in progress not recognized as current. Expected #{@game_in_pro.ix_game}, but received #{ix_game}") if @game_in_pro
      @log.warn("Game in progress is  null, impossible to leave") if @game_in_pro == nil
    end
  end

  ##
  # Handle command RESTARTGAME
  def cmdh_restart_game(msg_details)
    @log.debug "RESTARTGAME handler #{msg_details}"
    ix_game = msg_details
    if @game_in_pro and ix_game == @game_in_pro.ix_game
      @game_in_pro.restart_this_game_req(@user_name, ix_game)
    else
      @log.warn("Player restart a game in progress not recognized as current. Expected #{@game_in_pro.ix_game}, but received #{ix_game}") if @game_in_pro
    end
  end

  def cmdh_restart_withanewgame(msg_details)
    info = YAML::load(msg_details)
    @log.debug "RESTARTWITHNEWGAME #{info[:type_req]}"
    case info[:type_req]
    when :create
      @game_in_pro.create_restart_another_req(self, info[:detail]) if @game_in_pro
    when :join
      @game_in_pro.join_restart_another_req(self, info[:detail]) if @game_in_pro
    when :decline
      @game_in_pro.decline_restart_another_req(self, info[:detail]) if @game_in_pro
    end
  end

  ##
  # Handle command PINGRESP
  def cmdh_ping_resp(msg_details)
    #@log.debug "PINGRESP #{@user_name}"
  end

  ##
  # Log function for warning messages
  def log_warn(str)
    @log.warn(str)
  end
end # module UserConnCmdHanler
