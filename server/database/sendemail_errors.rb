#file: sendemail_errors.rb
# Use to send an email when an error occours.

# TODO:
# E-Mail should be sent using the relay with tls and authentication.
# The pseudo code is:
#   ms.emailTo = ms.secret.Email
# 	ms.emailFrom = ms.secret.RelayMail
# 	servername := ms.secret.RelayHost

# 	host, _, _ := net.SplitHostPort(servername)

# 	auth := smtp.PlainAuth("", ms.secret.RelayUser, ms.secret.RelaySecret, host)

# 	tlsconfig := &tls.Config{
# 		InsecureSkipVerify: true,
# 		ServerName:         host,
# 	}

# 	log.Println("Dial server ", servername)
# 	conn, err := tls.Dial("tcp", servername, tlsconfig)
# 	if err != nil {
# 		return err
# 	}

# 	c, err := smtp.NewClient(conn, host)
# 	if err != nil {
# 		return err
# 	}

# 	log.Println("Send smtp Auth")
# 	if err = c.Auth(auth); err != nil {
# 		return err
# 	}

require "rubygems"
require "net/smtp"

class EmailErrorSender
  def initialize(log, dest_email, from_email)
    @log = log
    @destination = dest_email
    @from = from_email
    @uniq = 0
  end

  def send_email(detail)
    msgstr = <<END_OF_MESSAGE
From: Cuperativa <#{@from}>
Subject: Errore (#{Time.now}) da Cup.invido.it
Date: #{Time.now}
Mime-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Message-Id: <#{random_tag()}@invido.it>

Ciao Igor,

se ti interessa un nuovo errore:

#{detail}

fai come vuoi,

Cuperativa Server

END_OF_MESSAGE

    #p msgstr
    Net::SMTP.start("localhost", 25) do |smtp|
      smtp.send_message msgstr,
                        @from,
                        @destination
    end

    @log.debug("Email with log report was sent OK.")
  rescue
    # send error
    @log.error("send_email error detail is failed. Reason #{$!}")
  end

  ##
  # Provides a random tag
  def random_tag
    @uniq += 1
    t = Time.now
    sprintf("%x%x_%x%x%d%x",
            t.to_i, t.tv_usec,
            $$, Thread.current.object_id, @uniq, rand(255))
  end
end

if $0 == __FILE__
  require "log4r"
  include Log4r

  mylog = Log4r::Logger.new("email_log_notifier")
  mylog.add "stdout"

  sender = EmailErrorSender.new(mylog)
  sender.send_email("Un error grave nel file aa.eb linea 123.")
end
