#
#file: net_connect_dlg.rb
$:.unshift File.dirname(__FILE__) + '/../..'
  


require 'rubygems'
require 'fox16'
require 'base64'
require 'base/core/web_launcher'

include Fox

if $0 == __FILE__
  require 'log4r'
  include Log4r 
end


##
# Shows a dialogbox to connect to the game server
class DialogConnect < FXDialogBox
  attr_accessor :login_name, :password_login
  
  
  ##
  # owner: wnd owner
  # conn_type: type of connection (:simple or :advanced)
  # comment: windows title
  # proxy_params: hash app settings of proxy settings
  def initialize(owner, comment, info_conn_hash)
    super(owner, comment, DECOR_TITLE|DECOR_BORDER|DECOR_RESIZE,
      0, 0, 0, 0, 0, 0, 0, 0, 4, 4)
    
    @cup_gui = owner
    @log = Log4r::Logger.new("coregame_log::DialogConnect") 
    @comment = comment
    @info_conn_hash = info_conn_hash
    
    @main_vertical = FXVerticalFrame.new(self, 
                           LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    
    @password_saved = info_conn_hash[:password_saved]
    @use_guest_login = false 
    
    # user data section
    group2 = FXVerticalFrame.new(@main_vertical, FRAME_THICK|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    matrix = FXMatrix.new(group2, 2, MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
    FXLabel.new(matrix, "Giocatore:", nil, JUSTIFY_RIGHT|LAYOUT_FILL_X|LAYOUT_CENTER_Y)
    @login_name = FXTextField.new(matrix, 2, nil, 0, (FRAME_SUNKEN|FRAME_THICK|LAYOUT_FILL_X|LAYOUT_CENTER_Y|LAYOUT_FILL_COLUMN))
    FXLabel.new(matrix, "Password:", nil, JUSTIFY_RIGHT|LAYOUT_FILL_X|LAYOUT_CENTER_Y)
    @password_login = FXTextField.new(matrix, 2, nil, 0, (TEXTFIELD_PASSWD|FRAME_SUNKEN|FRAME_THICK|LAYOUT_FILL_X|LAYOUT_CENTER_Y|LAYOUT_FILL_COLUMN))
    @password_login.connect(SEL_CHANGED,method(:lbl_passw_changed))
    # saved password
    @chksaved_password = FXCheckButton.new(group2, "Ricorda password\tSalva la password sul computer")
    @chksaved_password.checkState = @password_saved
    @chksaved_password.connect(SEL_COMMAND) do |sender, sel, checked|
      if checked
        @password_saved = true
      else
        @password_saved = false
      end
    end
   
    #conn_type simple or advanced
    @advanced_conn = info_conn_hash[:connect_type] 
    
    
    # simple connection to a server
    group2 = FXVerticalFrame.new(@main_vertical, FRAME_THICK|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @lbl_srv_news = FXLabel.new(group2, "Info: ", nil, JUSTIFY_LEFT|LAYOUT_FILL_X|LAYOUT_CENTER_Y)
    # register command
    signup_bt = FXButton.new(group2, "Registra Giocatore", @cup_gui.icons_app[:home], self, 0,
            LAYOUT_RIGHT | FRAME_RAISED|FRAME_THICK , 0, 0, 0, 0, 30, 30, 4, 4)
    signup_bt.connect(SEL_COMMAND, method(:go_signup))
    signup_bt.iconPosition = (signup_bt.iconPosition|ICON_BEFORE_TEXT) & ~ICON_AFTER_TEXT
      
    # guest login
    @chkuse_guest_login = FXCheckButton.new(group2, "Entra come ospite\tConnecti come ospite")
    @chkuse_guest_login.checkState = @use_guest_login
    @chkuse_guest_login.connect(SEL_COMMAND) do |sender, sel, checked|
      if checked
        @use_guest_login = true
      else
        @use_guest_login = false
      end
    end
    
    
    # bottom part
    FXHorizontalSeparator.new(@main_vertical, SEPARATOR_RIDGE|LAYOUT_FILL_X)
    btframe = FXHorizontalFrame.new(@main_vertical, 
                                    LAYOUT_BOTTOM|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH )
    
    # connect commnad
    @conn_button = FXButton.new(btframe, "Collegati", @cup_gui.icons_app[:gonext], self, FXDialogBox::ID_ACCEPT,
      LAYOUT_LEFT | FRAME_RAISED|FRAME_THICK , 0, 0, 0, 0, 30, 30, 4, 4)
    @conn_button.iconPosition = (@conn_button.iconPosition|ICON_BEFORE_TEXT) & ~ICON_AFTER_TEXT
    
    # cancel command
    canc_bt = FXButton.new(btframe, "Cancella", @cup_gui.icons_app[:icon_close], self, FXDialogBox::ID_CANCEL,
      LAYOUT_RIGHT | FRAME_RAISED|FRAME_THICK, 0, 0, 0, 0, 30, 30, 4, 4)
    canc_bt.iconPosition = (canc_bt.iconPosition|ICON_BEFORE_TEXT) & ~ICON_AFTER_TEXT
    
    
    # TODO: crea i controlli che mancano con le infos del server
    # -- prima linea: combo server, combo: account --- (per versioni successive)
    # -- frame guest, con dentro il bottone [Login Ospite]
    # -- frame di fianco avanzato: server ip, porta
    # -- frame sotto utente con nome e password, checkbox ricorda password
    #     dentro al frame il bottone collegati, fuori dal frame il bottone cancella
    
    @conn_button.setDefault  
    @conn_button.setFocus
    @info_websrv = nil
    
    
    # flag of password changed
    @passw_is_changed = false
  end
  
  def go_signup(sender, sel, ptr)
    goto_generic_url("http://cuperativa.invido.it/signup")
  end
  
  def lbl_passw_changed(sender, sel, ptr)
    @passw_is_changed = true
  end
  
  ##
  # Set preconfigured server address on control.
  # Use last used information.
  def set_server_info
    host = @info_conn_hash[:host_server]
    port = @info_conn_hash[:port_server]
    @login_name.text = @info_conn_hash[:login_name]
    if @password_saved
      @password_login.text = @info_conn_hash[:password_login]
    else
      @password_login.text = ""
    end
    
    # simple connect, using last information or default
    @info_websrv = {
      "name" => "#{host}",
      "ipsrv" => host,
      'portsrv' => port,
      'news1' => "Puoi registrare gratuitamente un nuovo giocatore\n sul server della cuperativa.",
      'opti_index' => '10'
    }
    @log.debug("Selected server: #{@info_websrv["ipsrv"]}, port: #{@info_websrv["portsrv"]}, web: #{@info_websrv["use_web"]}, index: #{@info_websrv["opti_index"]}")
     
    self.title = @comment + ": #{@info_websrv["name"]}"
    @lbl_srv_news.text = "#{@lbl_srv_news.text} #{@info_websrv["news1"]}"
      

  end
  
  ##
  # Workaround for windows
  def goto_generic_url(url)
    if $g_os_type == :win32_system
      Thread.new{
        system "start \"test\" \"#{url}\""
      }
    else
      LanciaApp::Browser.run(url)
    end
  end
  
  def get_host_server
    return @info_websrv["ipsrv"]
  end
  
  def getconn_info_hash
    res = {}
    res[:host_server] = get_host_server
    res[:port_server] = get_port_server
    res[:login_name] = @login_name.text
    if @passw_is_changed
      # calculate md5 from text on the controlbox
      res[:password_login] = @password_login.text
      res[:password_login_md5] = Base64::encode64(@password_login.text.chomp)
    else
      # use initial md5 password
      res[:password_login_md5] = @info_conn_hash[:password_login_md5]
    end
    res[:password_saved] = @password_saved
    res[:use_guest_login] = @use_guest_login
    return res
  end
  
  def get_port_server
    return @info_websrv["portsrv"].to_i
  end
  
end

if $0 == __FILE__
  
  require '../../../test/gfx/test_dialogbox' 
  
  log = Log4r::Logger.new("coregame_log")
  log.outputters << Outputter.stdout 
  
  ##
  # Launcher of the dialogbox
  class TestMyDialogGfx

    def initialize(app)
      app.runner = self
      @dlg_box = DialogConnect.new(app, "Server", {
          :password_saved => true, 
          :host_server => 'localhost',
          :port_server => 20606,
          :password_login => "test", 
          :password_login_md5 => 'sXas', 
          :login_name => 'igor'})
      @dlg_box.set_server_info
    end
    
    ##
    # Method called from TestRunnerDialogBox when go button is pressed
    def run
      if @dlg_box.execute != 0
        p info_conn_hash = @dlg_box.getconn_info_hash
      end
    end
    
  end
  
  # create the runner: a window with one button that call runner.run
  theApp = FXApp.new("TestRunnerDialogBox", "FXRuby")
  mainwindow = TestRunnerDialogBox.new(theApp)
  mainwindow.set_position(0,0,300,300)
  
  tester = TestMyDialogGfx.new(mainwindow)
  theApp.create
  
  theApp.run
end
