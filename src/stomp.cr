require "http"
require "log"

module STOMP
  Log = ::Log.for("stomp")

  class ResponseError < Exception
    def initialize(frame : Frame)
      super(frame.headers["message"]? || frame.body_text)
      @frame = frame
    end

    property frame : Frame
  end

  class ProtocolError < Exception
  end

  enum Version
    V1_0
    V1_1
    V1_2
  end

  enum Command
    # client-command
    Send
    Subscribe
    Unsubscribe
    Begin
    Commit
    Abort
    Ack
    Nack
    Disconnect
    Connect
    Stomp

    # server-command
    Connected
    Message
    Receipt
    Error

    # special case
    HeartBeat
  end

  enum AckMode
    Auto
    Client
    ClientIndividual
  end

  HEAD_ENCODE = [
    {'\\', "\\\\"},
    {'\r', "\\r"},
    {'\n', "\\n"},
    {':', "\\c"},
  ]
  HEAD_DECODE = HEAD_ENCODE.reverse

  def self.decode_header(value : String) : String
    HEAD_DECODE.each { |(char, encoded)| value = value.gsub(encoded, char) }
    value
  end

  def self.encode_header(value) : String
    str = value.to_s
    HEAD_ENCODE.each { |(char, encoded)| str = str.gsub(char, encoded) }
    str
  end
end

require "./stomp/frame"
require "./stomp/*"
