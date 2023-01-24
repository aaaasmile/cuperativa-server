#file: bot_start.rb

require "cuperativa_bot"

###############
# Code executed when daemon is started

bot = CuperativaBot.new
bot.settings_filename = File.join(File.dirname(__FILE__), "robot.yaml")
bot.log_production
bot.load_settings
trap(:INT) {
  p "robot shutdown"
  bot.exit
}
bot.run
bot.join_run
###############
#END
###############
