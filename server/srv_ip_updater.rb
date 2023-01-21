#
# file: srv_ip_updater.rb

require 'rubygems'
require 'rest-open-uri'
require 'rexml/document'
require 'log4r'
require 'base64'
require 'openssl'

# scommenta le 3 linee seguenti per un debug usando la console
# usa: ruby srv_ip_updater.rb per lanciare il debugger. Vedi info ruby_install.txt
#require 'ruby-debug'
#Debugger.start
#debugger

##
# module used to update web service for cuperativa server
module Server_Cup_Webserv
  
  ##
  # Manage ip update to the service cuperativa
  class IpUpdateCup
    attr_accessor :remote_server_http, :server_name, :public_key, :private_key
    attr_accessor :service_news, :service_index, :log
  
    REMOTE_SERVER = "cuperativa.igor.railsplayground.com"
    URI_IP_GETTER_CUP = "/cuperativa/your_ip.xml"
    URI_DNS_SERVICE = "/cuperativa/srvhost456449447zt5.xml"
    SERVER_NAME = "ArmonicaSgab"
    PUBLIC_KEY = "44CF9590006BF252F706" #test publickey
    # we are using downcase
    INTERESTING_HEADERS = ['content-type', 'content-md5', 'date', 
                'cup_publickey', 'cup_ip', 'cup_port', 'cup_news', 
                'cup_index', 'cup_isaweb' ]
    
    def initialize
      @log = Log4r::Logger["serv_ip_update"] 
      @remote_server_http = REMOTE_SERVER
      @own_ip = ""
      # ip address sent to the remote service
      @external_ip = ""
      @server_name = SERVER_NAME
      @public_key = PUBLIC_KEY
      @private_key = ""
      @service_port = 20606
      @service_news = "Server ONLINE"
      @service_isaweb = false
      @service_index = 100
    end
    
    ##
    # Handle the process ip update on the web service
    def update_own_ip(opt)
      #read external ip
      @log.info("*** update_own_ip called on #{Time.now} *****")
      @server_name = opt[:server_name]
      @service_index = opt[:server_index]
      if opt[:ip_changing]
        @external_ip = provides_external_ip
        if @external_ip.empty?
          @log.error "update_own_ip terminate with error: can't get own ip"
          return
        end
      else
        @external_ip = opt[:ip_fix]
      end
      # read ip from web service inserted on db
      @own_ip = read_service_ip_indb
      if @own_ip == "ERROR"
        @log.error "update_own_ip ERROR, maybe you don't have server credential"
        return
      end
      
      if @own_ip == "" or @own_ip == nil
        @log.error "update_own_ip ERROR, we got an entry with unknown ip, delete it"
        delete_service_ip_indb
        return 
      end
      
      # check the value on the table
      if @own_ip == "0.0.0.0"
        # no entry found, create it
        create_new_ip_entry
        return
      end
      if @own_ip != @external_ip
        # ip has changed, update it
        remotely_update_myip
      else
        @log.debug "IP entry for this server is already present, don't need ip update"
      end
    end
    
    ##
    # Build update url
    def build_update_url(headers_opt)
      news_enc = Base64.encode64(@service_news).strip
      #url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}?publickey=#{@public_key}&servername=#{SERVER_NAME}"
      headers_opt['cup_publickey'] = "#{@public_key}"
      headers_opt['cup_servername'] = "#{@server_name}"
      headers_opt['cup_ip'] = "#{@external_ip}"
      headers_opt['cup_port'] = "#{@service_port}"
      headers_opt['cup_news'] = "#{news_enc}"
      headers_opt['cup_index'] = "#{@service_index}"
      headers_opt['cup_isaweb'] = "#{@service_isaweb}"
      url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}"
      #url += "&ip=#{@external_ip}&port=#{@service_port}&news=#{news_enc}"
      #url += "&index=#{@service_index}&isaweb=#{@service_isaweb}"
      return url
    end
    
    ##
    # Create a new ip entry on the server. As ip use the content of @external_ip
    def create_new_ip_entry
      # we are sending a string in news field, it should be encoded 
      @log.debug "Try to enter a new ip entry on the server"
      headers_opt = {}
      url = build_update_url(headers_opt)
      headers_opt[:method] = :post
      #headers_opt[:method] = :get
      uri = URI::parse(url)
      io_res = open_signed(uri, headers_opt)
      resp = io_res.read if io_res
        
      @log.info resp
    end
    
    ##
    # Time to update the entry on the web service
    def remotely_update_myip
      @log.debug "Update ip entry on the server"
      headers_opt = {}
      url = build_update_url(headers_opt)
      headers_opt[:method] = :put
      uri = URI::parse(url)
      #resp = open_signed(uri, headers_opt).read
      io_res = open_signed(uri, headers_opt)
      resp = io_res.read if io_res
      
      @log.info resp
    end
    
    ##
    # Put the current offline
    def server_offline
      @log.info("*** server_offline called on #{Time.now} *****")
      @log.debug("Change info of server tp OFFLINE")
      # set a dummy ip to make the entry valid
      # Don't use 0.0.0.0 because force creation of a new entry
      @external_ip = "127.0.0.1"
      @service_news = "Server OFFLINE"
      @service_index = 0
      remotely_update_myip
    end
    
    def delete_service_ip_indb
      @log.debug "Delete entry in remote service ip"
      #url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}?publickey=#{@public_key}&servername=#{SERVER_NAME}"
      url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}"
      headers_opt = {}
      headers_opt[:method] = :delete
      headers_opt['cup_publickey'] = "#{@public_key}"
      headers_opt['cup_servername'] = "#{@server_name}"
      
      uri = URI::parse(url)
      #resp = open_signed(uri, headers_opt).read
      io_res = open_signed(uri, headers_opt)
      resp = io_res.read if io_res
      
      @log.info resp
    end
    
    ##
    # Read the ip associated with the public key and name of the server
    def read_service_ip_indb
      @log.debug "Read remote service ip"
      #url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}?publickey=#{@public_key}&servername=#{SERVER_NAME}"
      url = "http://#{@remote_server_http}#{URI_DNS_SERVICE}"
      headers_opt = {}
      headers_opt[:method] = :get
      headers_opt['cup_publickey'] = "#{@public_key}"
      headers_opt['cup_servername'] = "#{@server_name}"
      
      @log.debug "Check url #{url}"
      uri = URI::parse(url)
      #resp = open_signed(uri, headers_opt).read
      io_res = open_signed(uri, headers_opt)
      resp = io_res.read if io_res
      
      @log.info resp
      info_hash = parse_ip_address_in_resp(resp)
      ip_str = info_hash ["ip"]
      return ip_str
    rescue
      @log.error("read_service_ip_indb: #{$!}")
      return "ERROR"
    end
    
    ##
    # Parse the http server xml response and give info as hash back
    # xml_res: xml response, like:
    #     <cupsrv>
    #       <ip>0.0.0.0</ip>
    #     </cupsrv>
    # we can also get something like <ip></ip>, it is still valid.
    # On authentication error we get nothing
    def parse_ip_address_in_resp(xml_res)
      info_serv = {}
      cupsrv  = REXML::Document.new(xml_res)
      cupsrv.elements.each("cupsrv")  do |content|
        # note: we have only one cupsrv tag
        content.each_element do |node|
          # iterate the content of <cupsrv>
          @log.debug "#{node.name}: #{node.text}"
          #if node.name == "ip" and node.text == nil
            #info_serv[node.name] = "0.0.0.0" # too much tricky, simply don'allow empty ip
          #else
            #info_serv[node.name] = node.text
          #end
          info_serv[node.name] = node.text
        end
      end
      return info_serv
    end #end parse_ip_address_in_resp
    
    ##
    # wrapper for rest-open-uri in order to add custom headers
    # Goal is to sign url and header so that only partner with the same shared
    # secret are availabe to exchange information
    def open_signed(uri, headers_and_options={}, *args, &block)
      headers_and_options=headers_and_options.dup
      headers_and_options['Date'] ||= Time.now.httpdate
      #headers_and_options['Date'] = "Tue, 21 Jan 2008 13:52:54 GMT" #test time expired
      headers_and_options['Content-Type'] ||= 'application'
      headers_and_options['Content-Length'] = "#{0}"
      signed = signature(uri, headers_and_options[:method] || :get, headers_and_options)
      headers_and_options['cup_auth'] = "#{signed}"
      headers_and_options['User-Agent'] = "Cuperativa Server"
      #headers_and_options['Accept'] = "text/plain"
      #headers_and_options['Accept-Encoding'] = "x-compress; x-zip"
      #headers_and_options['Accept-Language'] = "en;q=0.5"
      #headers_and_options['Accept-Charset'] = "ISO-8859-1"
      #headers_and_options['Host'] = "#{REMOTE_SERVER}"
      #url_path_complete = "http://#{@remote_server_http}#{URI_DNS_SERVICE}"
      #headers_and_options['Referer'] = url_path_complete
      begin
        Kernel::open(uri, headers_and_options, *args, &block)
      rescue
        @log.error("ERROR open_signed: #{$!}")
        return nil
      end
    end
    
    ##
    # sign an uri
    # uri: it could be an URI or a string
    def signature(uri, method=:get, headers={})
      unless uri.respond_to? :path # check if the object uri has a method path()
        # yet a string
        uri = URI.parse(uri)
      end
      # important to sign also the query part
      path = uri.path + (uri.query ? "?" + uri.query : "")
      # build canonical string, then sign it
      can_str = canonical_string(method,path,headers)
      signed_string = sign(can_str)
    end
    
    ##
    # Build canonical string to be signed
    def canonical_string(method,path,headers)
      sign_headers = {}
      INTERESTING_HEADERS.each{|h| sign_headers[h] = ''}
      headers.each do |h,v|
        if h.respond_to? :to_str
          h = h.downcase
          if INTERESTING_HEADERS.member?(h)
            sign_headers[h] = v.to_s.strip
          end
        end
      end
      
      canonical = method.to_s.upcase + "\n"
      # sort headers
      sign_headers.sort_by{|h| h[0]}.each do |hh, vv|
        canonical << hh << ":"
        canonical << vv << "\n"
      end
      canonical << path.gsub(/\?.*$/, '')
      @log.debug "Canonical string\n:#{canonical}"
      return canonical
    end
    
    ##
    # Sign a string
    # str: string to be signed
    def sign(str)
      #puts "private key: #{@private_key}"
      digest_generator = OpenSSL::Digest::Digest.new('sha1')
      digest = OpenSSL::HMAC.digest(digest_generator, @private_key, str )
      return Base64.encode64(digest).strip
    end
    
    ##
    # GET external IP
    def provides_external_ip
      info_serv = {}
      url = "http://#{@remote_server_http}#{URI_IP_GETTER_CUP}"
      @log.debug "Check url #{url}"
      uri = URI::parse(url)
      # now using openuri, if the server return an error code, e.g. 404 an exception is raised
      resp = open(uri).read
      @log.debug resp
      cupsrv  = REXML::Document.new(resp)
      cupsrv.elements.each("cupsrv")  do |content|
        # note: we have only one cupsrv tag
        content.each_element do |node|
          # iterate the content of <cupsrv>
          #p node.name
          #expect one element
          info_serv[node.name] = node.text 
          @log.debug "#{node.name}: #{node.text}"
        end
      end
      return info_serv["ip"]
    rescue
      @log.error("pick_info_fromremote_url: #{$!}")
      return ""
    end#end method pick_external_ip
  end #end class
  
  
end#end module

if $0 == __FILE__
  require 'yaml'
  #test stuff
  include Log4r

  logger = Log4r::Logger.new("serv_ip_update")
  logger.outputters << Outputter.stdout
  ipupdat = Server_Cup_Webserv::IpUpdateCup.new
  # use settings from yaml file
  optfilename = File.dirname(__FILE__)  + '/options.yaml'
  if File.exist?(optfilename)
    logger.info "Load settings from  #{optfilename}"
    opt = YAML.load_file(optfilename)
    logger.info "Options:"
    opt.each do |k,v|
      logger.info "#{k} = #{v}"
    end
    ipupdat.public_key = opt[:publickey_server]  if opt[:publickey_server]
    ipupdat.private_key = opt[:secret_server]  if opt[:secret_server]
  end
  
  #set local server for testing
  #ipupdat.public_key = "44CF9590006BF252F706" #localhost admin public key
  #ipupdat.remote_server_http =  "127.0.0.1:3303"
  #ipupdat.private_key = "OaxrzxIsfpFjA7SwPzILwy8Bw21TLhquhboDYROV" #localhost private key
  #ipupdat.provides_external_ip
  
  #ipupdat.update_own_ip
  ipupdat.update_own_ip(opt[:spec_server])
  ipupdat.server_offline
  #ipupdat.delete_service_ip_indb
end


