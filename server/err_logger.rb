$:.unshift File.dirname(__FILE__)

require "rubygems"

module MyErr
  def error_trace(detail, comp, log, send_email_on_err)
    log.error("ERROR -  #{comp}:")
    detail_joined = detail.backtrace.join("\n")
    log.error(detail)
    if send_email_on_err
      sender = EmailErrorSender.new(log)
      sender.send_email("#{$!}\n" + detail_joined)
    end
  end

  def error_msg(msg, comp, log, send_email_on_err)
    rep_msg = "ERROR -  #{comp}: #{msg}"
    log.error(rep_msg)
    if send_email_on_err
      sender = EmailErrorSender.new(log)
      sender.send_email(rep_msg)
    end
  end
end
