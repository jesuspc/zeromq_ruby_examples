# The broker from 06 is implemented in its own function because it is very
# common. This acts as a message queue.

should_run = ARGV.pop == 'run'

require 'rbczmq'
require './06_extended_request_reply.rb'

module BuiltInProxyFunction
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
      ZMQ.proxy router_socket, dealer_socket
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
      Thread.new { BuiltInProxyFunction::Broker.new(context: context).run }

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

BuiltInProxyFunction::Program.call ZMQ::Context.new(1) if should_run

# Output:
# (...)
# [CLIENT 1] Received reply to "Hello 1-2": "World"
# [CLIENT 1] Sending: "Hello 1-3"
# [CLIENT 2] Received reply to "Hello 2-2": "World"
# [CLIENT 2] Sending: "Hello 2-3"
# [WORKER 1] Received "Hello 0-2"
# [WORKER 1] Sending response: "World"
# [WORKER 0] Received "Hello 1-3"
# [WORKER 0] Sending response: "World"
# [WORKER 2] Received "Hello 2-3"
# [WORKER 2] Sending response: "World"
# [CLIENT 0] Received reply to "Hello 0-2": "World"
# [CLIENT 0] Sending: "Hello 0-3"
# [CLIENT 1] Received reply to "Hello 1-3": "World"
# [CLIENT 1] Sending: "Hello 1-4"
# [CLIENT 2] Received reply to "Hello 2-3": "World"
# [CLIENT 2] Sending: "Hello 2-4"
# (...)
