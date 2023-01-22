# file: dbconnector.rb
#file used to establish the connection with the user mysql db

$:.unshift File.dirname(__FILE__)

require "rubygems"
require "active_record"
require "dbcup_datamodel"
#require 'benchmark'

#include Benchmark

module MyGameServer
  class DbDataConn
    attr_accessor :use_sqlite3

    def initialize(log, user, password, name_db, mod_type)
      @log = log
      @user = user
      @password = password
      @database_name = name_db
      @mod_type = mod_type
    end

    def connect_sqlite3
      ActiveRecord::Base.establish_connection(
        :adapter => "sqlite3",
        :database => @database_name,
      )
      @log.debug "Connect using local sqlite3 database, name: #{@database_name}"
    end

    def connect
      case @mod_type
      when "sqlite3"
        connect_sqlite3
      when "pg"
        connect_pg
      else
        @log.error "Connection type #{@mod_type} not supported"
      end
    end

    def connect_pg
      ActiveRecord::Base.establish_connection(
        :adapter => "pg",
        :database => @database_name,
        :username => @user,
        :password => @password,
        :host => "localhost",
      )
      @log.debug "Connected to the database #{@database_name} using user: #{@user} and password: #{@password}"
    end

    def is_login_authorized?(user, password)
      @log.debug "Checking credential for user #{user}"
      res = try_to_authenticate(user, password)
      if res.nil?
        @log.debug "retry check in db"
        res = try_to_authenticate(user, password)
      end
      return res ? true : false
    end

    def try_to_authenticate(user, password)
      begin
        user = CupUserDataModel::CupUsers.authenticate(user, password)
        if user
          user.lastlogin = Time.now
          user.save
          return true
        end
        #return user ? true : false
        return false
      rescue
        # error, try to connect
        @log.error "authenticate is failed with error #{$!}"
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
      rescue
        @log.error "finduser is failed with error #{$!}"
        connect
        return nil
      end
    end

    # Find or create an item using userd_id field into table named str_table
    # str_table: e.g.: CupUserDataModel::ClassificaBri2
    def generic_find_or_create_classifica(str_table, user_id)
      class_item = (eval(str_table)).find_by_user_id(user_id)
      unless class_item
        # create a new item
        class_item = (eval(str_table)).new
        class_item.default_classifica
        class_item.user_id = user_id
        class_item.save
      end
      return class_item
    end

    ##
    # Find or create an item in the classment table
    # gioco_name : string sent in pg_create2 as gioco_name field
    def find_or_create_classifica(gioco_name, user_id)
      res_class_item = nil
      case gioco_name
      when "Briscola"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaBri2", user_id
        )
      when "Mariazza"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaMariazza", user_id
        )
      when "Spazzino"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaSpazzino", user_id
        )
      when "Tombolon"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaTombolon", user_id
        )
      when "Scopetta"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaScopetta", user_id
        )
      when "Briscolone"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaBriscolone", user_id
        )
      when "Tressette"
        res_class_item = generic_find_or_create_classifica(
          "CupUserDataModel::ClassificaTressette", user_id
        )
      end
      return res_class_item
    end

    def create_dummyusers()
      create_dummy_user("luzzo")
      create_dummy_user("marco")
      create_dummy_user("marta")
    end

    def test_encry(login_name)
      user = CupUserDataModel::CupUsers.find :first, :conditions => { :login => login_name }
      puts "test_encry on #{login_name}: " + user.encrypt("123456")
    end

    def create_robot_players
      create_dummy_user("robot_player2")
      create_dummy_user("robot_player3")
      create_dummy_user("robot_player4")
      create_dummy_user("robot_player5")
    end

    def create_dummy_user(login_name)
      olduser = CupUserDataModel::CupUsers.find :first, :conditions => { :login => login_name }
      if olduser
        @log.debug "User #{login_name} already in the db, uncomment below if you want to remove it"
        #olduser.delete
        #olduser.save
        return
      end
      newuser = CupUserDataModel::CupUsers.new
      newuser.login = login_name
      newuser.crypted_password = newuser.encrypt("123456")
      newuser.state = "active"
      newuser.save
      @log.debug "dummy user #{login_name} created"
    end

    def create_admin_user()
      login_name = "aaaasmile"
      olduser = CupUserDataModel::CupUsers.find :first, :conditions => { :login => login_name }
      if olduser
        @log.debug "User #{login_name} already in the db."
        return
      end
      newuser = CupUserDataModel::CupUsers.new
      newuser.login = login_name
      newuser.crypted_password = newuser.encrypt("123456")
      newuser.state = "active"
      newuser.save
      @log.debug "admin user #{login_name} created"
    end
  end

  module Connector
    def connect_to_db(log, db_options)
      @db_connector = MyGameServer::DbDataConn.new(log,
                                                   db_options[:user_db],
                                                   db_options[:pasw_db],
                                                   db_options[:name_db],
                                                   db_options[:mod_type])
      @db_connector.connect
    end
  end
end #module

if $0 == __FILE__
  require "rubygems"
  require "log4r"
  include Log4r

  log = Log4r::Logger.new("myuserctrl").add "stdout"

  # admin is a user add on local database instance for testing purpose
  ctrl = MyGameServer::DbDataConn.new(Log4r::Logger["myuserctrl"], "root", "rambo78", "cupuserdatadb")
  #ctrl.use_sqlite3 = true
  ctrl.connect
  ctrl.create_dummyusers
  #ctrl.create_admin_user
  #ctrl.create_robot_players
  #p res = ctrl.is_login_authorized?('luzzo', '123456')
  #ctrl.connect
  #p res = ctrl.finduser("Luzzo")
  #user_id = 7
  #p res = ctrl.find_or_create_classifica('Briscola', user_id)
  #res.score += 10
  #res.save
  #ctrl.test_encry('luzzo')
end
