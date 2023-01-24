class MsgIncoming
  attr_accessor :data

  def initialize(args = {})
    @decoded = args[:decoded] || false
    @data = args[:data] || []
  end

  def decoded?
    @decoded
  end

  def <<(data)
    @data << data
  end

  def next
    unless decoded?
      return if @data.size.zero?
      if @data.size > 1 && @data[@data.size - 1] == '"'
        msg = data.join
        return MsgIncoming.new(type: :text, data: msg, decoded: true)
      end
    end
  end

  def clear
    @data = []
  end
end
