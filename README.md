# Crystal Lang STOMP Protocol

[![Build Status](https://travis-ci.com/spider-gazelle/stomp.svg?branch=master)](https://travis-ci.com/github/spider-gazelle/stomp)

Communicate with devices supporting the STOMP protocol

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     stomp:
       github: spider-gazelle/stomp
   ```

2. Run `shards install`


## Usage

```crystal

require "stomp"

hostname = "stomp.server.com"
port = 1234
socket = TCPSocket.new(hostname, port)

# accepts any object implementing `IO`
client = STOMP::IOClient.new(hostname, socket)

# client is ready
client.on_connected do |frame|
  client.send client.subscribe("main", "/some/path", HTTP::Headers{
    "receipt" => "confirm-main",
  })
end

# process messages here
client.on_message do |frame|
  frame.headers["subscription"] # => "main" (as specified in the subscription above)
  frame.headers["destination"] # => "/some/path"

  # get the data, handles charset automatically
  frame.body_text

  # or can get the raw bytes
  frame.body
end

# if you are interested in receipts
client.on_receipt do |frame|
  frame.headers["receipt-id"] # => "confirm-main"
end

# if you are interested in errors
client.on_error do |frame|
  message = frame.headers["message"]? || frame.body_text
  Log.error { message }

  # maybe you want to close on error?
  client.close
end

client.on_close do |frame|
  received_closed += 1
end

# blocks until the socket is closed or an unhandled error occurs
# client is thread safe
client.run

```
