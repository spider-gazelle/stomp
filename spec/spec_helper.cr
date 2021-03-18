require "spec"
require "../src/stomp"

::Log.setup("*", :trace)

Spec.before_suite do
  ::Log.builder.bind("*", backend: ::Log::IOBackend.new(STDOUT), level: ::Log::Severity::Trace)
end

require "socket"

def handle_client(client)
  # negotiate connection
  client.sync = false
  frame = STOMP::Frame.new(client)
  case frame.command
  when .connect?, .stomp?
    connected = STOMP::Frame.new(STOMP::Command::Connected, HTTP::Headers{
      "version"    => "1.2",
      "heart-beat" => "0,0",
    })
    connected.to_s(client)
    client.flush
  else
    error = STOMP::Frame.new(STOMP::Command::Error, HTTP::Headers{
      "message" => "unexpected frame #{frame.command}",
    })
    error.to_s(client)
    client.flush
    client.close
    return
  end

  # send a message (possible race condition, but fine for testing)
  spawn(same_thread: true) do
    # So specs don't hang
    sleep 2
    client.close unless client.closed?
  end

  loop do
    frame = STOMP::Frame.new(client)

    if receipt = frame.headers["receipt"]?
      done = STOMP::Frame.new(STOMP::Command::Receipt, HTTP::Headers{
        "receipt-id" => receipt,
      })

      done.to_s(client)
      client.flush
    end

    case frame.command
    when .disconnect?
      client.close
      return
    when .subscribe?
      done = STOMP::Frame.new(STOMP::Command::Message, HTTP::Headers{
        "message-id"   => "123",
        "destination"  => frame.headers["destination"],
        "subscription" => frame.headers["id"],
        "ack"          => "123",
      })
      done.to_s(client)
      client.flush
    end
  end
end

server = TCPServer.new("localhost", 1234)

spawn do
  while client = server.accept?
    spawn handle_client(client)
  end
end

Spec.after_suite do
  server.close
end
