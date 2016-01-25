# In order to communicate a pool of servers with a pool of clients we add a
# broker.
# When you use REQ to talk to REP, you get a strictly synchronous request-reply
# dialog. Luckily DEALER and ROUTER that let you do nonblocking
# request-response.
#
#     (REQ)        (REQ)         (REQ)
#       |            |              |
#        ---------------------------
#                    |
#                 (ROUTER) - bind
#   Code that shoves messages from RO to DE
#                 (DEALER) - bind
#                    |
#        ---------------------------
#       |            |              |
#       v            v              v
#     (REP)        (REP)          (REP)

should_run = ARGV.pop == 'run'

require 'rbczmq'

module ExtendedRequestReply
  class Client
    def initialize(id:, context:, address: 'tcp://localhost:5559')
      self.id = id
      self.context = context
      self.address = address
    end

    def run
      socket.connect address

      do_requests
    end

    private

    attr_accessor :id, :context, :address

    def do_requests
      10.times do |i|
        msg = "Hello #{id}-#{i}"
        puts "[CLIENT #{id}] Sending: \"#{msg}\""
        socket.send msg
        # Blocks while waiting the reply
        reply = socket.recv
        puts "[CLIENT #{id}] Received reply to \"#{msg}\": \"#{reply}\""
      end
    end

    def socket
      @socket ||= context.socket(ZMQ::REQ)
    end
  end

  class Worker
    def initialize(id:, context:, address: 'tcp://localhost:5560')
      self.id = id
      self.context = context
      self.address = address
    end

    def run
      socket.connect address

      do_work
    end

    private

    attr_accessor :id, :context, :address

    def do_work
      loop do
        puts "[WORKER #{id}] Received \"#{socket.recv}\""
        response = 'World'
        puts "[WORKER #{id}] Sending response: \"#{response}\""
        socket.send response
      end
    end

    def socket
      @socket ||= context.socket(ZMQ::REP)
    end
  end

  class Broker
    def initialize(context:, client_address: 'tcp://*:5559',
                             worker_address: 'tcp://*:5560')
      self.context = context
      self.client_address = client_address
      self.worker_address = worker_address
    end

    def run
      router_socket.bind client_address
      dealer_socket.bind worker_address

      poller.register router_socket
      poller.register dealer_socket

      do_polling
    end

    private

    attr_accessor :context, :client_address, :worker_address

    def do_polling
      loop do
        poller.poll
        poller.readables.each do |socket|
          case socket
          when router_socket
            dealer_socket.send_message socket.recv_message
          when dealer_socket
            router_socket.send_message socket.recv_message
          end
        end
      end
    end

    def poller
      @poller ||= ZMQ::Poller.new
    end

    def router_socket
      @router_socket ||= context.socket(ZMQ::ROUTER)
    end

    def dealer_socket
      @dealer_socket ||= context.socket(ZMQ::DEALER)
    end
  end

  module Program
    def self.call(context)
      Thread.new { ExtendedRequestReply::Broker.new(context: context).run }

      3.times do |i|
        Thread.new do
          ExtendedRequestReply::Worker.new(id: i, context: context).run
        end
      end

      3.times.map do |i|
        Thread.new do
          ExtendedRequestReply::Client.new(id: i, context: context).run
        end
      end.map(&:join)
    end
  end
end

ExtendedRequestReply::Program.call ZMQ::Context.new(1) if should_run

# Output:
# (...)
# [CLIENT 2] Sending: "Hello 2-2"
# [WORKER 2] Received "Hello 1-2"
# [WORKER 2] Sending response: "World"
# [WORKER 1] Received "Hello 2-2"
# [WORKER 1] Sending response: "World"
# [CLIENT 0] Received reply to "Hello 0-1": "World"
# [CLIENT 0] Sending: "Hello 0-2"
# [CLIENT 1] Received reply to "Hello 1-2": "World"
# [CLIENT 1] Sending: "Hello 1-3"
# [CLIENT 2] Received reply to "Hello 2-2": "World"
# [CLIENT 2] Sending: "Hello 2-3"
# [WORKER 0] Received "Hello 0-2"
# [WORKER 0] Sending response: "World"
# [WORKER 2] Received "Hello 1-3"
# [WORKER 2] Sending response: "World"
# [WORKER 1] Received "Hello 2-3"
# [WORKER 1] Sending response: "World"
# [CLIENT 0] Received reply to "Hello 0-2": "World"
# [CLIENT 0] Sending: "Hello 0-3"
# [CLIENT 1] Received reply to "Hello 1-3": "World"
# (...)
