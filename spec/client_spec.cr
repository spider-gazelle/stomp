require "./spec_helper"

module STOMP
  describe Client do
    it "negotiate a connection" do
      client = Client.new("some.server")
      client.connected?.should eq false

      init_message = client.stomp
      init_message.command.stomp?.should eq true
      init_message.headers.should eq HTTP::Headers{
        "accept-version" => "1.1,1.2",
        "host"           => "some.server",
      }
      init_message.body.size.should eq 0

      connected = Frame.new(Command::Connected, HTTP::Headers{
        "version"    => "1.2",
        "heart-beat" => "5000,5000",
      })
      client.negotiate(connected)
      client.connected?.should eq true
      client.version.should eq(Version::V1_2)
    end
  end

  describe IOClient do
    it "interact with a server" do
      hostname = "localhost"
      socket = TCPSocket.new(hostname, 1234)
      client = IOClient.new(hostname, socket)

      connected_was_called = 0
      received_message = 0
      received_receipt = 0
      received_closed = 0
      received_error = 0

      client.connected?.should eq false

      client.on_connected do |_frame|
        connected_was_called += 1

        client.send client.subscribe("main", "/some/path", HTTP::Headers{
          "receipt" => "main",
        })
      end

      client.on_message do |_frame|
        received_message += 1

        client.close
      end

      client.on_receipt do |frame|
        if received_receipt == 0
          frame.headers["receipt-id"].should eq("main")
        else
          frame.headers["receipt-id"].should eq("disconnect")
        end
        received_receipt += 1
      end

      client.on_error do |_frame|
        received_error += 1
      end

      client.on_close do |_frame|
        received_closed += 1
      end

      client.run

      connected_was_called.should eq(1)
      received_message.should eq(1)
      received_receipt.should eq(2)
      received_closed.should eq(1)
      received_error.should eq(0)
    end
  end
end
