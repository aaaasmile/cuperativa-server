#file: zero_classifica.rb
# used to change classificas. This script is used as standalone script.

require "rubygems"
require "dbconnector"
require "log4r"
require "dbcup_datamodel"

include Log4r

#This file is intended to be called as stand alone when leader boards need to be resetted

class ZeroScoreClassificas < MyGameServer::BasicDbConnector
  attr_accessor :all_score_tozero

  def initialize
    Log4r::Logger.new("connector").add "stdout"
    @log = Log4r::Logger.new("connector::ZeroScoreClassificas")
    @settings_filename = File.dirname(__FILE__) + "/../options.yaml"
    @options = YAML::load_file(@settings_filename)
    connect_to_db(@options[:database])

    # CAUTION: this if true force ALL records to the default value
    @all_score_tozero = false

    @tables_class = ["CupUserDataModel::ClassificaBri2", "CupUserDataModel::ClassificaMariazza",
                     "CupUserDataModel::ClassificaSpazzino", "CupUserDataModel::ClassificaTombolon",
                     "CupUserDataModel::ClassificaScopetta", "CupUserDataModel::ClassificaTressette", "CupUserDataModel::ClassificaBriscolone"]
  end

  def connect_to_db(db_options)
    @db_connector = MyGameServer::DbDataConn.new(@server_core_log,
                                                 db_options[:user_db],
                                                 db_options[:pasw_db],
                                                 db_options[:name_db],
                                                 db_options[:mod_type])
    @db_connector.connect
  end

  ##
  # Players that not have any match becomes a zero score
  def check_and_set_zeroscore
    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      allitems.each do |item|
        if item.match_losed == 0 and item.match_won == 0 and item.score == 1000 or
           @all_score_tozero
          item.default_classifica
          @log.debug "Set score to zero (default) for user #{item.user_id}"
          item.save
        end
      end
    end # end tables
  end

  ##
  # Recalculate percent score for all classificas
  def recalculate_percent
    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      allitems.each do |item|
        tot = item.match_won + item.match_losed
        next if tot <= 0
        old_val = item.match_percent
        item.match_percent = (item.match_won * 100) / tot
        @log.debug "Set percent: #{item.match_percent} %"
        if old_val != item.match_percent
          @log.debug "Calculation differ for user #{item.user_id}, old: #{old_val}"
        end
        item.save
      end
    end
  end

  ##
  # Save all classificas into a csv file
  def save_class_tofile
    curr_day = Time.now.strftime("%Y_%m_%d")
    base_dir_out = File.dirname(__FILE__) + "/csv/#{curr_day}"
    FileUtils.mkdir_p(base_dir_out)

    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      strdet = []
      strdet << "Table: #{str_table}"
      strdet << allitems[0].attributes.keys.join(",") if allitems.size > 0
      allitems.each do |item|
        strdet << item.attributes.values.join(",")
      end
      fname = File.join(base_dir_out, "#{str_table.split("::")[1]}.csv")
      File.open(fname, "w") do |out|
        out << strdet.join("\n")
      end
      @log.debug "File created: #{fname}"
    end
  end
end

if $0 == __FILE__
  zeros = ZeroScoreClassificas.new
  #zeros.check_and_set_zeroscore
  #zeros.save_class_tofile
  #zeros.recalculate_percent
end
