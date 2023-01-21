#file: dbcup_datamodel.rb

require 'rubygems'
require 'active_record'
require 'digest'


module CupUserDataModel
  
  class CupUsers < ActiveRecord::Base
    set_table_name "users"
    # values are to find into the rails application
    # This value must be the same as in config/initializers/site_keys.rb
    # otherwise passwords check failed always.
    REST_AUTH_SITE_KEY         = '' # TODO get it from option
    REST_AUTH_DIGEST_STRETCHES = 10
    
    def secure_digest(*args)
      digest_str = args.flatten.join('--')
      #p digest_str
      Digest::SHA1.hexdigest(digest_str)
    end
    
    def password_digest(password, salt)
      digest = REST_AUTH_SITE_KEY
      # p salt, here salt is nil
      REST_AUTH_DIGEST_STRETCHES.times do
        digest = secure_digest(digest, salt, password, REST_AUTH_SITE_KEY)
      end
      digest
    end
      
    def encrypt(password)
      password_digest(password, salt)
    end
  
    def authenticated?(password)
      crypted_password == encrypt(password)
    end
    
    def self.authenticate(login, password)
      return nil if login.blank? || password.blank?
      u = find :first, :conditions => {:login => login, :state => 'active'} # need to get the salt
      u && u.authenticated?(password) ? u : nil
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
  require 'rubygems'
  require 'log4r'
  include Log4r
  
  log = Log4r::Logger.new("myuserctrl").add 'stdout'
  
  enc = CupUserDataModel::CupUsers.encrypt('123456')
  log.debug "Pasw: #{enc}"
end
