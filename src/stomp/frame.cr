require "../stomp"

class STOMP::Frame
  def initialize(stream : IO)
    @command = Command.parse(stream.gets('\n').not_nil!.rstrip("\r\n"))
    @headers = headers = HTTP::Headers.new

    loop do
      next_line = stream.gets('\n').not_nil!.rstrip("\r\n")
      break if next_line.blank?
      parts = next_line.split(':', 2)
      raise "invalid header: '#{next_line}'" unless parts.size == 2
      headers.add(STOMP.decode_header(parts[0]), STOMP.decode_header(parts[1]))
    end

    if size = headers.get?("content-length").try(&.first.to_i)
      slice = Bytes.new(size)
      stream.read_fully(slice)

      # need to read until null termination,
      # standard is unclear if terminating character is included in content-length
      # examples include it but many client implementations do not, so we should handle both
      if slice[-1] == 0_u8
        @body = slice[0..-2]
      else
        @body = slice
        while (byte = stream.read_byte)
          break if byte == 0_u8
        end
      end
    else
      buffer = IO::Memory.new
      while (byte = stream.read_byte)
        break if byte == 0_u8
        buffer.write_byte(byte)
      end
      @body = buffer.to_slice
    end
  end

  def self.new(frame : String)
    Frame.new(IO::Memory.new(frame))
  end

  def initialize(@command, @headers = HTTP::Headers.new, @body = "", @send_content_length = true)
  end

  property command : Command
  property headers : HTTP::Headers
  property body : Bytes
  property send_content_length : Bool = true

  def body_text : String
    charset = "utf-8"
    if ctype = @headers["content-type"]?
      ctype.split(';')[1..-1].each do |part|
        part = part.strip
        charset = part.split('=')[1] if part.starts_with?("charset")
      end
    end

    String.new(@body, charset)
  end

  def to_s(io : IO) : Nil
    io << command.to_s.upcase
    io << '\n'
    headers.each do |key, values|
      next if key == "content-length"
      values.each do |value|
        io << STOMP.encode_header(key)
        io << ':'
        io << STOMP.encode_header(value)
        io << '\n'
      end
    end
    # include the \0 character in the content-length
    # not explicit in the standard but the examples include it
    if send_content_length
      io << "content-length:"
      (body.size + 1).to_s(io)
      io << '\n'
    end
    io << '\n'
    io.write body
    io << '\0'
  end
end
