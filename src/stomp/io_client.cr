require "../stomp"

class STOMP::IOClient < STOMP::Client
  def initialize(@host, socket, @send_acknowledgements : Bool = true)
    socket.tcp_nodelay = true if socket.responds_to?(:tcp_nodelay=)
    socket.sync = false if socket.responds_to?(:sync=)
    @socket = socket
  end

  @socket : IO
  @mutex = Mutex.new
  getter? closed = false
  @closing : String? = nil

  # Called when the client receives a message from a server.
  def on_connected(&@on_connected : Frame ->)
  end

  # Called when the client receives a message from a server.
  def on_message(&@on_message : Frame ->)
  end

  def on_receipt(&@on_receipt : Frame ->)
  end

  def on_error(&@on_error : Frame ->)
  end

  # Called when the connection is closed. True when closed gracefully
  def on_close(&@on_close : Bool ->)
  end

  def send(message : Frame) : Nil
    @mutex.synchronize do
      message.to_s(@socket)
      @socket.flush
    end
  end

  def send_heart_beat : Nil
    return if version.v1_0?
    @mutex.synchronize do
      @socket << '\n'
      @socket.flush
    end
  end

  def close(receipt = "disconnect", headers : HTTP::Headers = HTTP::Headers.new, unceremoniously = false) : Nil
    receipt = receipt.to_s
    @closing = receipt
    # Don't negotiate the close
    if unceremoniously
      @socket.close
      return
    end
    send disconnect(receipt, headers)
  end

  # Continuously receives messages and calls previously set callbacks until the socket is closed.
  def run(*args, **named) : Nil
    send stomp(*args, **named)

    loop do
      begin
        frame = Frame.new(@socket)
      rescue error
        Log.debug(exception: error) { "error reading frame" } unless @closing
        break
      end

      # raise an error if we receive something other than the connected frame
      negotiate(frame) unless connected?

      if @send_acknowledgements && (ack_id = frame.headers["ack"]?)
        Log.trace { "sending requested ack '#{ack_id}'" }
        send ack(ack_id)
      end

      case frame.command
      when .connected?
        @on_connected.try &.call(frame)
      when .receipt?
        @on_receipt.try &.call(frame)
        break if @closing && frame.headers["receipt-id"]? == @closing
      when .error?
        @on_error.try &.call(frame)
      else
        @on_message.try &.call(frame)
      end
    end
  ensure
    @socket.close
    @closed = true
    @on_close.try &.call(!!@closing)
  end
end
