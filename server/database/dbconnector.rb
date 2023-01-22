$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + "/../.."

require "rubygems"
require "cup_user"
require "cup_classifica"
require "pg"
require "yaml"

module MyGameServer
  class DbDataConn
    def initialize(log, user, password, name_db, mod_type, host, port, digest)
      @log = log
      @user = user
      @password = password
      @database_name = name_db
      @mod_type = mod_type
      @digest = digest
      @host = host
      @port = port
      @active_pg_conn = nil
    end

    def connect
      case @mod_type
      when "pg"
        connect_pg
      else
        @log.error "Connection type #{@mod_type} not supported"
      end
    end

    def connect_pg
      @active_pg_conn = PG::Connection.open(:dbname => @database_name, :user => @user, :password => @password, :host => @host, :port => @port)
      @log.debug "Connected to the database #{@database_name} using user: #{@user} and password: xxxx, host: #{@host}, port: #{@port}"
    end

    def get_user_by_auth(login, password, token)
      @log.debug "Checking credential for #{login}"
      res = try_to_authenticate(login, password, token)
      if res.nil?
        @log.debug "retry check in db"
        res = try_to_authenticate(login, password, token)
      end
      return res
    end

    def try_to_authenticate(user, password, token)
      begin
        user = CupUserDataModel::CupUser.authenticate(user, password, token, @digest, @active_pg_conn)
        if user
          user.lastlogin = Time.now
          if (user.remember_token == nil) || (Time.now > user.remember_token_expires_at)
            user.create_remember_token
          end
          user.save(@active_pg_conn)
          return user
        end
        return nil
      rescue => detail
        # error, try to connect
        @log.error "authenticate is failed with error #{$!}"
        @log.error detail.backtrace.join("\n")
        connect
        return nil
      end
    end

    ##
    # Find user using the login
    def finduser(username)
      begin
        user = CupUserDataModel::CupUsers.find_by_login(username)
        return user
      rescue => detail
        @log.error "finduser is failed with error #{$!}"
        @log.error detail.backtrace.join("\n")
        connect
        return nil
      end
    end

    ##
    # Find or create an item in the ranking table
    # game_name : string sent in pg_create2 as gioco_name field
    # user_id:
    def find_or_create_classifica(game_name, user_id)
      type = CupDbDataModel::CupClassifica.type_current
      class_item = CupDbDataModel::CupClassifica.find_by_user_id(game_name, user_id, type, @active_pg_conn)
      unless class_item
        # create a new item
        @log.debug "Create a new classifica #{game_name} for user #{user_id}"
        class_item = CupDbDataModel::CupClassifica.new
        class_item.name = game_name
        class_item.user_id = user_id
        class_item.type = type
        class_item.save(@active_pg_conn)
      end
      return class_item
    end

    def create_user(opt)
      if (opt[:login] == nil) || (opt[:password] == nil) || (opt[:password].length < 6 || opt[:login].length < 5)
        p opt
        raise "Wrong Login or password"
      end
      olduser = CupDbDataModel::CupUser.find_by_login(opt[:login], @active_pg_conn)
      if olduser
        raise "User #{opt[:login]} already in the db"
      end
      validate_captcha(opt[:token_captcha])

      @log.debug "Creating user #{opt[:login]}"
      newuser = CupDbDataModel::CupUser.new
      newuser.set_auth_key(@authkey)
      newuser.login = opt[:login]
      newuser.crypted_password = newuser.encrypt(opt[:password])
      newuser.state = opt[:state]
      newuser.email = opt[:email]
      newuser.deck_name = opt[:deck_name]
      newuser.gender = opt[:gender]
      newuser.fullname = opt[:fullname]
      newuser.save(@active_pg_conn)
      @log.debug "User  #{opt[:login]} in state #{opt[:state]} created"
      my_user = CupDbDataModel::CupUser.find_by_login(opt[:login], @active_pg_conn)
      return my_user.id
    end

    def user_exist?(loginname)
      return false if (loginname == nil) || (loginname.length < 5)
      user = CupDbDataModel::CupUser.find_by_login(loginname, @active_pg_conn)
      return user != nil
    end

    def remove_user(login)
      user = CupDbDataModel::CupUser.find_by_login(login, @active_pg_conn)
      if user
        user.delete(@active_pg_conn)
        @log.debug "User #{login} successfully deleted"
      else
        @log.warn "User #{login} not found"
      end
    end

    def simple_test_pg
      if !@active_pg_conn
        @log.error "simple_test_pg: PG is not connected"
        return
      end
      @log.debug "---" +
                   RUBY_DESCRIPTION +
                   PG.version_string(true) +
                   "Server version: #{@active_pg_conn.server_version}" +
                   "Client version: #{PG.respond_to?(:library_version) ? PG.library_version : "unknown"}" +
                   "---"

      result = @active_pg_conn.exec("SELECT * from users")

      @log.debug %Q{Expected this to return: ["select * from users"]}
      @log.debug result.field_values("login")
      #p result[0]
      p result[0]["login"], result[0]["crypted_password"], result[0]["email"]
    end

    def test_encry(login_name, password)
      user = CupDbDataModel::CupUser.find_by_login(login_name, @active_pg_conn)
      return @log.debug "User #{login_name} not found" if !user

      user.set_auth_key(@authkey)
      p encr = user.encrypt(password)
      p stored_enc = user.fields["crypted_password"]
      @log.debug "test_encry on #{login_name}: " + encr + " Email: #{user.fields["email"]}" + " Password-db: #{stored_enc}"
      @log.debug "Same? #{stored_enc == encr}"
    end
  end

  module Connector
    def connect_to_db(log, db_options)
      begin
        @db_connector = MyGameServer::DbDataConn.new(log,
                                                     db_options[:user_db],
                                                     db_options[:pasw_db],
                                                     db_options[:name_db],
                                                     db_options[:mod_type],
                                                     db_options[:host],
                                                     db_options[:port],
                                                     db_options[:digest])
        @db_connector.connect
        log.debug "DB connected"
        #p @db_connector
      rescue => detail
        log.error "Connector error(#{$!})"
        log.error detail.backtrace.join("\n")
      end
    end

    def connect_from_settingfile(log, file_name)
      file_name = File.dirname(__FILE__) + "/../" + file_name
      yamloptions = YAML::load_file(file_name)
      connect_to_db(log, yamloptions[:database])
      return @db_connector
    end
  end #module Connector
end #module MyGameServer

if $0 == __FILE__
  require "rubygems"
  require "lib/log4r"
  include Log4r
  include MyGameServer::Connector

  Log4r::Logger.new("DbConnector")
  Log4r::Logger["DbConnector"].outputters << Outputter.stdout
  log = Log4r::Logger["DbConnector"]

  conn = connect_from_settingfile(log, "options.yaml")
  conn.simple_test_pg
end
