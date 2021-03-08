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
end
