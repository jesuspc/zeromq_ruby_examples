# A server pushes updates to a set of clients
#
#               publisher (PUB) - bind
#                   |
#         ---------------------
#         |                   |
#         v                   v
#    subscriber (SUB)    subscriber (SUB) - connect

require 'rbczmq'

CONTEXT = ZMQ::Context.new(1)

class Server
  def initialize(address_1: 'tcp://*:5556', address_2: 'ipc://weather.ipc')
    self.address_1 = address_1
    self.address_2 = address_2
  end

  def run
    # Multiple addresses can be binded at the same time. The second one is
    # not listened by any client in this example.
    socket.bind address_1
    socket.bind address_2
    broadcast
  end

  private

  attr_accessor :address_1, :address_2

  def broadcast
    loop do
      socket.send "channel_1 #{rand(1000)}"
      socket.send 'channel_2 This message is not received by the client'
    end
  end

  def socket
    @socket ||= CONTEXT.socket(ZMQ::PUB)
  end
end

class Client
  def initialize(address: "tcp://localhost:5556")
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
      response = socket.recv

      puts "Received random number #{request_nbr}: [#{response}]"
    end
  end

  def context
    @context ||= ZMQ::Context.new(1)
  end

  def socket
    @socket ||= CONTEXT.socket(ZMQ::SUB)
  end
end

Thread.new { Server.new.run }
client_1 = Thread.new { Client.new.run }
client_2 = Thread.new { Client.new.run }
client_1.join
client_2.join

# Output:
# Received random number 0: [channel_1 516]
# Received random number 0: [channel_1 516]
# Received random number 1: [channel_1 521]
# Received random number 2: [channel_1 156]
# Received random number 3: [channel_1 968]
# Received random number 4: [channel_1 271]
# Received random number 5: [channel_1 540]
# Received random number 6: [channel_1 646]
# Received random number 1: [channel_1 521]
# Received random number 2: [channel_1 156]
# Received random number 3: [channel_1 968]
# Received random number 4: [channel_1 271]
# Received random number 5: [channel_1 540]
# Received random number 7: [channel_1 256]
# Received random number 8: [channel_1 486]
# Received random number 9: [channel_1 728]
# Received random number 6: [channel_1 646]
# Received random number 7: [channel_1 256]
# Received random number 8: [channel_1 486]
# Received random number 9: [channel_1 728]

