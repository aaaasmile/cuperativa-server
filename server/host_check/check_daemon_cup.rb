#file: check_daemon_cup.rb
# serve per controllare se il daemon del server va

require 'rubygems'
require 'log4r'

include Log4r

##
# Class used to checkif cuperativa server process is active or not
class CupServerChecker
  
  def initialize
    @ruby_path = '/usr/local/bin/ruby'
    #@serv_path = '/home/igor/Projects/cuperativa0508/cuperativa0508/server'
    @serv_path = '/home/igor/Projects/ruby/cuperativa0508/server'
    @serv_pid_filename = 'em_cup_server.rb.pid'
    log_path = "#{@serv_path}/logs"
    logfname = File.join(log_path, 'srv_checker.log') 
    @log = Log4r::Logger.new("srvcheck")
    #RollingFileOutputter.new('srvcheck', {:filename => logfname, :maxsize => 16000, :trunc => true } )
    #myApacheLikeFormat = PatternFormatter.new(:pattern => '%M') # questo usa solo il testo
    myApacheLikeFormat = PatternFormatter.new(:pattern => "[%d] %m") # questo usa [data] <testo>
    mybaseApacheLikeLog = RollingFileOutputter.new 'srvcheck', 
          :maxsize => 999999999, 
          :maxtime => 86400 * 14, # tempo in secondi (1 * 14 giorni). Dopo 14 giorni avviene il rollout e 
                                  # quindi viene creato un nuovo file
          :filename => logfname, 
          :trunc => false, # se true viene usato 'w' in File.open, altrimenti con false 'a'  
                           # voglio 'a' in quanto ogni volta che viene chiamato lo script, devo avere un append
          :formatter => myApacheLikeFormat

    @log.add 'srvcheck'
    @log.outputters << Outputter.stdout
  end
  
  ##
  # Do check for the cuperativa server if it runs
  def do_check
     log "CupServerChecker check..."
     #system '/usr/local/bin/ruby /home/igor/Projects/ruby/cuperativa0508/server/daemon_cup.rb start'
     pid_srv_file = @serv_path + "/#{@serv_pid_filename}"
     pid_in_file = ""
     if File.exist?(pid_srv_file)
       File.open(pid_srv_file, 'r').each_line do |line|
         pid_in_file = line.chomp
         break if pid_in_file.length > 0 
       end 
       log "Pid of cuperativa is: #{pid_in_file}"
       if is_pid_running?(pid_in_file)
         log "Pid is on ps -A, server cuperativa runs!"
       else
         log "ERROR: server cuperativa process not found, start it"
         start_cup_server(pid_srv_file)
       end
     else
       # daemon not started
       log "ERROR: server pid file not found"
       log "Now start the server..."
       start_cup_server(pid_srv_file)
     end
  end
  
  ##
  # Provides true if the process pid pid_in_file is running
  def is_pid_running?(pid_in_file)
    cmd = "ps -A | grep #{pid_in_file}"
    result_ps = ""
    IO.popen(cmd, 'r') do |io|
      result_ps =  io.read
    end
    #res = system cmd
    result_ps.scan(/ruby/) do |w|
      log "ps check OK: #{result_ps}"
      return true
    end 
    return false
  end
  
  ##
  # Start cuperativa server
  # pid_srv_file: pid filename
  def start_cup_server(pid_srv_file)
    cmd = "#{@ruby_path} #{@serv_path}/daemon_cup.rb start"
    #system cmd 
    # NOTE: inside arachno starting the server don't works correctly
    IO.popen(cmd, 'r') do |io|
      result_ps =  io.read
      log "res(if empty is ok): #{result_ps}"
    end
    sleep(2)
    if File.exist?(pid_srv_file)
      log "Cuperativa started ok"
    end
  end

  ##
  # Log
  def log(str)
    #ts = Time.now.strftime("%Y.%m.%d-%H:%M")
    #@log.info "[#{ts}] #{str.chomp}"
    @log.info str.chomp
  end
end

# --- script  Run time stuff 
ck = CupServerChecker.new
ck.do_check


