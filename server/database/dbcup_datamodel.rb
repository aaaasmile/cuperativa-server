#file: dbcup_datamodel.rb
$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + "/.."

require "rubygems"
require "active_record"
require "digest"

module CupUserDataModel
  class CupUsers < ActiveRecord::Base
    self.table_name = "users"

    def secure_digest(*args)
      digest_str = args.flatten.join("--")
      #p digest_str
      Digest::SHA1.hexdigest(digest_str)
    end

    def password_digest(password, salt, digest)
      # p salt, here salt is nil
      10.times do
        digest = secure_digest(digest, salt, password, digest)
      end
      digest
    end

    def authenticated?(password, salt, digest)
      crypted_password == password_digest(password, salt, digest)
    end

    def self.authenticate(login, password, digest)
      return nil if login.blank? || password.blank?
      u = find :first, :conditions => { :login => login, :state => "active" }
      u && u.authenticated?(password, u.salt, digest) ? u : nil
    end
  end #end users

  class ClassificaBri2 < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.segni_won = 0
      self.segni_losed = 0
      self.segni_deuced = 0
      self.score = 0
    end
  end

  class ClassificaBriscolone < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.segni_won = 0
      self.segni_losed = 0
      self.segni_deuced = 0
      self.score = 0
    end
  end

  class ClassificaMariazza < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.segni_won = 0
      self.segni_losed = 0
      self.segni_deuced = 0
      self.score = 0
    end
  end

  class ClassificaTressette < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.tot_matchpoints = 0
      self.score = 0
    end
  end

  class ClassificaScopetta < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.tot_matchpoints = 0
      self.score = 0
    end
  end

  class ClassificaSpazzino < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.tot_matchpoints = 0
      self.score = 0
    end
  end

  class ClassificaTombolon < ActiveRecord::Base
    def default_classifica()
      self.match_percent = 0
      self.match_won = 0
      self.match_losed = 0
      self.tot_matchpoints = 0
      self.score = 0
    end
  end
end #end module

if $0 == __FILE__
  require "rubygems"
  require "log4r"
  require "pg_list"
  include Log4r

  log = Log4r::Logger.new("serv_main").add "stdout"

  pg_list = MyGameServer::PendingGameList.new
  connector = pg_list.init_from_setting("options.yaml") # connect to the db
  options = pg_list.options

  p res = connector.finduser("Luzzo")

  #p user = CupUserDataModel::CupUsers.new

  #enc = user.encrypt("123456")
  #log.debug "Pasw: #{enc}"
end
