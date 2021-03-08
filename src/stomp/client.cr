require "../stomp"
require "math"

class STOMP::Client
  def initialize(@host)
  end

  getter host : String
  getter version : Version = Version::V1_0
  getter? connected : Bool = false
  getter server : String? = nil
  getter session : String? = nil

  getter heart_beat_client : Tuple(Int32, Int32)? = nil
  getter heart_beat_server : Tuple(Int32, Int32)? = nil

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
    Frame.new(Command::Connect, HTTP::Headers{
      "accept-version" => "1.0,1.1,1.2",
      "host"           => @host,
    })
  end

  def stomp(username : String? = nil, password : String? = nil, heart_beat : Tuple(Int32, Int32)? = nil)
    @heart_beat_client = heart_beat
    headers = HTTP::Headers{
      "accept-version" => "1.1,1.2",
      "host"           => @host,
    }
    headers["login"] = username if username
    headers["passcode"] = password if password
    headers["heart-beat"] = "#{heart_beat[0]},#{heart_beat[1]}" if heart_beat
    Frame.new(Command::Stomp, headers)
  end

  def negotiate(stream)
    frame = case stream
            when Frame
              stream
            else
              next_frame(stream)
            end

    raise ProtocolError.new("unexpected frame '#{frame.command}', expecting 'Connected'") unless frame.command.connected?
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
    @connected = true
    frame
  end

  def send(destination : String, headers : HTTP::Headers = HTTP::Headers.new, body : String = "", send_content_length : Bool = true)
    headers["destination"] = destination
    Frame.new(Command::Send, headers, body, send_content_length)
  end

  def subscribe(id, destination : String, headers : HTTP::Headers = HTTP::Headers.new, ack : AckMode = AckMode::Auto)
    headers["id"] = id.to_s
    headers["destination"] = destination
    headers["ack"] = ack.to_s.underscore.sub('_', '-')
    Frame.new(Command::Subscribe, headers)
  end

  def unsubscribe(id, headers : HTTP::Headers = HTTP::Headers.new)
    headers["id"] = id.to_s
    Frame.new(Command::Unsubscribe, headers)
  end

  def ack(id, headers : HTTP::Headers = HTTP::Headers.new, transaction = nil)
    headers["id"] = id.to_s
    headers["transaction"] = transaction.to_s if transaction
    Frame.new(Command::Ack, headers)
  end

  def nack(id, headers : HTTP::Headers = HTTP::Headers.new, transaction = nil)
    headers["id"] = id.to_s
    headers["transaction"] = transaction.to_s if transaction
    Frame.new(Command::Nack, headers)
  end

  def begin(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(Command::Begin, headers)
  end

  def commit(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(Command::Commit, headers)
  end

  def abort(transaction, headers : HTTP::Headers = HTTP::Headers.new)
    headers["transaction"] = transaction.to_s
    Frame.new(Command::Abort, headers)
  end

  def disconnect(receipt, headers : HTTP::Headers = HTTP::Headers.new)
    headers["receipt"] = receipt.to_s
    Frame.new(Command::Disconnect, headers)
  end

  def next_frame(stream) : Frame
    frame = Frame.new(stream)
    raise ResponseError.new(frame) if frame.command.error?
    frame
  end
end
