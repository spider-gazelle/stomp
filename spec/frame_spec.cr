require "./spec_helper"

module STOMP
  describe Frame do
    it "should parse a simple stomp frame" do
      raw = %(SEND\nheader:value\ncontent-length:9\n\nbody text\0)
      msg = Frame.new(raw)
      msg.command.should eq(Command::Send)
      msg.headers.should eq(HTTP::Headers{"header" => "value", "content-length" => "9"})
      msg.body_text.should eq("body text")

      msg.to_s.should eq(raw)
    end

    it "should parse example error frame" do
      raw = <<-MSG
        ERROR
        receipt-id:message-12345
        content-type:text/plain
        message:malformed frame received
        content-length:170

        The message:
        -----
        MESSAGE
        destined:/queue/a
        receipt:message-12345

        Hello queue a!
        -----
        Did not contain a destination header, which is REQUIRED
        for message propagation.
        \0
        MSG
      msg = Frame.new(raw)
      msg.command.should eq(Command::Error)
      msg.headers.should eq(HTTP::Headers{
        "receipt-id"     => "message-12345",
        "content-type"   => "text/plain",
        "message"        => "malformed frame received",
        "content-length" => "170",
      })
      msg.body_text.should eq <<-MSG
        The message:
        -----
        MESSAGE
        destined:/queue/a
        receipt:message-12345

        Hello queue a!
        -----
        Did not contain a destination header, which is REQUIRED
        for message propagation.

        MSG

      msg.to_s.should eq(raw)
    end

    it "should parse example RECEIPT frame" do
      raw = <<-MSG
        RECEIPT
        receipt-id:message-12345

        \0
        MSG
      msg = Frame.new(raw)
      msg.command.should eq(Command::Receipt)
      msg.headers.should eq(HTTP::Headers{
        "receipt-id" => "message-12345",
      })
      msg.body_text.should eq("")
      msg.send_content_length = false
      msg.to_s.should eq(raw)
    end

    it "should parse example MESSAGE frame" do
      raw = <<-MSG
        MESSAGE
        subscription:0
        message-id:007
        destination:/queue/a
        content-type:text/plain

        hello queue a\0
        MSG
      msg = Frame.new(raw)
      msg.command.should eq(Command::Message)
      msg.headers.should eq(HTTP::Headers{
        "subscription" => "0",
        "message-id"   => "007",
        "destination"  => "/queue/a",
        "content-type" => "text/plain",
      })
      msg.body_text.should eq("hello queue a")
      msg.send_content_length = false
      msg.to_s.should eq(raw)
    end

    it "should parse example RECEIPT frame" do
      raw = <<-MSG
        RECEIPT
        receipt-id:message-12345

        \0
        MSG
      msg = Frame.new(raw)
      msg.command.should eq(Command::Receipt)
      msg.headers.should eq(HTTP::Headers{
        "receipt-id" => "message-12345",
      })
      msg.body_text.should eq("")
      msg.send_content_length = false
      msg.to_s.should eq(raw)
    end
  end
end
