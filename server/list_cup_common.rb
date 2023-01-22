require "rubygems"
require "database/dbconnector"

module MyGameServer
  class ListCupCommon
    include MyGameServer::Connector

    def initialize
      @log = Log4r::Logger["serv_main"]
      @dir_log = File.dirname(__FILE__) + "/../../logs"
      @db_connector = nil
    end

    def set_dir_log(dirlog)
      @dir_log = dirlog
    end

    ##
    # Create an hash for pg_list2 message
    def create_hash_forlist2(type_list, slice_nr, slice_state, arr_pgs)
      return { :type => type_list,
               :slice => slice_nr,
               :slice_state => slice_state,
               :detail => arr_pgs }
    end

    def create_hash_forlist2addremove(type_list, detail_list)
      return { :type => type_list, :detail => detail_list }
    end

    def init_from_setting(file_name)
      yamloptions = YAML::load_file(file_name)
      set_dir_log(yamloptions[:logpath])
      connect_to_db(@log, yamloptions[:database])
    end

    def set_db_connector(db_connector)
      @db_connector = db_connector
    end
  end #end ListCupCommon
end
