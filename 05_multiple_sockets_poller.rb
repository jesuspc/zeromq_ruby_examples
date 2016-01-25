# Unlinke in 04 here we treat sockets fairly by reading first from one
# and then from the other instead of prioritizing as we did there.

should_run = ARGV.pop == 'run'

require 'rbczmq'
require './02_basic_pub_sub'
require './03_basic_parallel_pipeline'

module MultipleSocketsPoller
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

      poller.register(worker_socket)
      poller.register(sub_socket)

      do_polling
    end

    private

    attr_accessor :context, :pub_address, :ventilator_address

    def do_polling
      loop do
        poller.poll
        poller.readables.each do |socket|
          case socket
          when worker_socket then puts "Receiving work to do #{socket.recv}"
          when sub_socket then puts "Receiving push notification #{socket.recv}"
          end
        end
      end
    end

    def poller
      @poller ||= ZMQ::Poller.new
    end

    def sub_socket
      @sub_socket ||= context.socket(ZMQ::SUB)
    end

    def worker_socket
      @worker_socket ||= context.socket(ZMQ::PULL)
    end
  end

  class Program
    def self.call(context)
      Thread.new { BasicParallelPipeline::Ventilator.new(context: context).run }
      Thread.new { BasicPubSub::Server.new(context: context).run }
      Thread.new { Client.new(context: context).run }.join
    end
  end
end

MultipleSocketsPoller::Program.call ZMQ::Context.new(1) if should_run

# Output:
# Receiving push notification channel_1 866
# (...)
# Receiving push notification channel_1 694
# Ventilating workload 0
# Receiving push notification channel_1 882
# Ventilating workload 1
# Ventilating workload 2
# Receiving push notification channel_1 172
# Receiving work to do 10
# Receiving push notification channel_1 723
# Ventilating workload 3
# Receiving work to do 10
# Ventilating workload 4
# Receiving push notification channel_1 913
# Ventilating workload 5
# Ventilating workload 6
# Ventilating workload 7
# Receiving work to do 10
# Receiving push notification channel_1 701
# Receiving work to do 10
# Receiving push notification channel_1 450
# Receiving work to do 10
# Receiving push notification channel_1 690
# Receiving work to do 10
# Receiving push notification channel_1 520
# Ventilating workload 8
# Receiving work to do 10
# Receiving push notification channel_1 234
# Ventilating workload 9
# Receiving work to do 10
# Receiving push notification channel_1 697
# Receiving push notification channel_1 388
# Receiving work to do 10
# Receiving push notification channel_1 809
# Receiving work to do 10
# Receiving push notification channel_1 452
# (...)
# Receiving push notification channel_1 292
