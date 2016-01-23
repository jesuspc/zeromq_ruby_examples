# Simple example of reading from two sockets using nonblocking reads.
# This program acts both as a subscriber to pub/sub updates, and a worker for
# parallel tasks.

should_run = ARGV.pop == 'run'

require 'rbczmq'
require './basic_pub_sub'
require './basic_parallel_pipeline'

module MultipleSocketsReader
  class Client
    def initialize(context:, pub_address: 'tcp://localhost:5556',
                   ventilator_address: 'tcp://localhost:5557')
      self.context = context
      self.pub_address = pub_address
      self.ventilator_address = ventilator_address
    end

    def run
      sub_socket.connect pub_address
      sub_socket.subscribe 'channel_1'

      worker_socket.connect ventilator_address

      work_and_receive
    end

    private

    attr_accessor :context, :pub_address, :ventilator_address

    def work_and_receive
      loop do
        message = sub_socket.recv_nonblock
        puts "Received message: #{message}" if message
        work_to_do = worker_socket.recv_nonblock
        puts "Received work to do: #{work_to_do}" if work_to_do
        # The cost of this approach is some additional latency on the first msg,
        # when there are no waiting messages to process
        sleep 0.001
      end
    end

    def sub_socket
      @sub_socket ||= context.socket(ZMQ::SUB)
    end

    def worker_socket
      @worker_socket ||= context.socket(ZMQ::PULL)
    end
  end

  module Program
    def self.call(context)
      Thread.new { BasicParallelPipeline::Ventilator.new(context: context).run }
      Thread.new { BasicPubSub::Server.new(context: context).run }
      Thread.new { Client.new(context: context).run }.join
    end
  end
end

MultipleSocketsReader::Program.call ZMQ::Context.new(1) if should_run

# Output:
# Received message: channel_1 930
# (...)
# Received message: channel_1 490
# Ventilating workload 0
# Ventilating workload 1
# Ventilating workload 2
# Ventilating workload 3
# Ventilating workload 4
# Ventilating workload 5
# Ventilating workload 6
# Ventilating workload 7
# Ventilating workload 8
# Ventilating workload 9
# Received message: channel_1 3
# Received work to do: 10
# Received message: channel_1 670
# Received work to do: 10
# Received message: channel_1 498
# Received work to do: 10
# Received message: channel_1 120
# Received work to do: 10
# Received message: channel_1 131
# Received work to do: 10
# Received message: channel_1 827
# Received work to do: 10
# Received message: channel_1 368
# Received work to do: 10
# Received message: channel_1 636
# Received work to do: 10
# Received message: channel_1 825
# Received work to do: 10
# Received message: channel_1 403
# Received work to do: 10
# Received message: channel_1 428
# Received message: channel_1 954
# (...)
