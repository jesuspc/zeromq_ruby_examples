# The client sends "Hello" to the server, which replies with "World"
#         client (REQ)
#             | ^
#     'hello' | | 'world'
#             v |
#         server (REP)
#
require 'rbczmq'

class Server
  def initialize(address: "tcp://*:5555")
    self.address = address
  end

  def run
    socket.bind address
    listen
  end

  private

  attr_accessor :address

  def listen
    while true do
      request = socket.recv

      puts "Received request. Data: #{request.inspect}"

      socket.send("world")
    end
  end

  def context
    @context ||= ZMQ::Context.new(1)
  end

  def socket
    @socket ||= context.socket(ZMQ::REP)
  end
end

class Client
  def initialize(address: "tcp://localhost:5555")
    self.address = address
  end

  def run
    socket.connect address
    request
  end

  private

  attr_accessor :address

  def request
    0.upto(9) do |request_nbr|
      puts "Sending request #{request_nbr}…"
      socket.send "Hello"

      response = socket.recv

      puts "Received reply #{request_nbr}: [#{response}]"
    end
  end

  def context
    @context ||= ZMQ::Context.new(1)
  end

  def socket
    @socket ||= context.socket(ZMQ::REQ)
  end
end

Thread.new { Server.new.run }
Thread.new { Client.new.run }.join

# Outputs:
# Sending request 0…
# Received request. Data: "Hello"
# Received reply 0: [world]
# Sending request 1…
# Received request. Data: "Hello"
# Received reply 1: [world]
#Sending request 2…
# Received request. Data: "Hello"
# Received reply 2: [world]
# Sending request 3…
# Received request. Data: "Hello"
# Received reply 3: [world]
# Sending request 4…
# Received request. Data: "Hello"
# Received reply 4: [world]
# Sending request 5…
# Received request. Data: "Hello"
# Received reply 5: [world]
# Sending request 6…
# Received request. Data: "Hello"
# Received reply 6: [world]
# Sending request 7…
# Received request. Data: "Hello"
# Received reply 7: [world]
# Sending request 8…
# Received request. Data: "Hello"
# Received reply 8: [world]
# Sending request 9…
# Received request. Data: "Hello"
# Received reply 9: [world]
