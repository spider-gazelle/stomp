require "../stomp"
require "math"

class STOMP::Client
  def initialize(@host)
  end

  getter host : String
  getter version : Version = Version::V1_0
  getter server : String? = nil
  getter session : String? = nil

  getter heart_beat_client : Tuple(UInt32, UInt32)? = nil
  getter heart_beat_server : Tuple(UInt32, UInt32)? = nil

  # Client => Server beat time, Server => Client beat time
  def heart_beat
    client = heart_beat_client
    server = heart_beat_server
    if client && server
      client_server = client[0].zero? || server[1].zero? ? 0 : Math.max(client[0], server[1])
      server_client = client[1].zero? || server[0].zero? ? 0 : Math.max(client[1], server[0])
      {client_server, server_client}
    else
      {0, 0}
    end
  end

  def connect
    Frame.new(:connect, HTTP::Headers{
      "accept-version" => "1.0,1.1,1.2",
      "host"           => @host,
    })
  end

  def stomp(username : String? = nil, password : String? = nil, heart_beat : Tuple(UInt32, UInt32)? = nil)
    @heart_beat_client = heart_beat
    headers = HTTP::Headers{
      "accept-version" => "1.1,1.2",
      "host"           => @host,
    }
    headers["login"] = username if username
    headers["passcode"] = password if password
    headers["heart-beat"] = "#{heart_beat[0]},#{heart_beat[1]}" if heart_beat
    Frame.new(:stomp, headers)
  end

  def negotiate(stream)
    frame = next_frame(stream)
    raise ProtocolError.new("unexpected frame '#{frame.command}'") unless frame.command.connected?
    if ver = frame.headers["version"]?
      @version = Version.parse("V#{ver.sub('.', '_')}")
    else
      @version = Version::V1_0
    end
    if server = frame.headers["server"]?
      @server = server
    end
    if session = frame.headers["session"]?
      @session = session
    end
    if beat = frame.headers["heart-beat"]?.try(&.split(','))
      @heart_beat_server = {beat[0].to_i, beat[1].to_i}
    end
    frame
  end

  def send(destination : String, headers : HTTP::Headers = HTTP::Headers.new, body : String = "", send_content_length : Bool = true)
    headers["destination"] = destination
    Frame.new(:send, headers, body, send_content_length)
  end

  def subscribe(id, destination : String, headers : HTTP::Headers = HTTP::Headers.new, ack : AckMode = AckMode::Auto)
    headers["id"] = id.to_s
    headers["destination"] = destination
    headers["ack"] = ack.to_s.underscore.sub('_', '-')
    Frame.new(:subscribe, headers)
  end

  def unsubscribe(id, headers : HTTP::Headers = HTTP::Headers.new)
    headers["id"] = id.to_s
    Frame.new(:subscribe, headers)
  end

  def ack(id, headers : HTTP::Headers = HTTP::Headers.new, transaction = nil)
    headers["id"] = id.to_s
    headers["transaction"] = transaction.to_s if transaction
    Frame.new(:ack, headers)
  end

  def nack(id, headers : HTTP::Headers = HTTP::Headers.new, transaction = nil)
    headers["id"] = id.to_s
    headers["transaction"] = transaction.to_s if transaction
    Frame.new(:nack, headers)
  end

  def begin(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(:begin, headers)
  end

  def commit(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(:commit, headers)
  end

  def abort(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(:abort, headers)
  end

  def disconnect(receipt, headers : HTTP::Headers = HTTP::Headers.new)
    headers["receipt"] = receipt.to_s
    Frame.new(:disconnect, headers)
  end

  def next_frame(stream) : Frame
    frame = Frame.new(stream)
    raise ResponseError.new(frame) if frame.command.error?
    frame
  end
end
