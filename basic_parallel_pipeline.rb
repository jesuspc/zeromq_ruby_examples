# A ventilator that produces tasks that can be done in parallel
# A set of workers that process tasks
# A sink that collects results back from the worker processes
#
#                    ventilator (PUSH)
#                         |
#              -----------------------
#              |                     |
#              v                     V
#            (PULL)                (PULL)
#            worker                worker
#            (PUSH)                (PUSH)
#              |                     |
#              -----------------------
#                         |
#                         v
#                       sink (PULL)

require 'rbczmq'

CONTEXT = ZMQ::Context.new(1)

class Ventilator
  def initialize(address: 'tcp://*:5557')
    self.address = address
  end

  def run
    socket.bind address
    distribute_work_evenly
  end

  private

  attr_accessor :address

  def distribute_work_evenly
    # We have to synchronize the start of the batch with all workers being up
    # and running. The zmq_connect method takes a certain time. So when a set
    # of workers connect to the ventilator, the first one to successfully
    # connect will get a whole load of messages in that short time while
    # the others are also connecting. If you don't synchronize the start of
    # the batch somehow, the system won't run in parallel at all.
    sleep 1

    10.times do |i|
      puts "Ventilating workload #{i}"
      socket.send "10"
    end
  end

  def socket
    @socket ||= CONTEXT.socket(ZMQ::PUSH)
  end
end

class Worker
  def initialize(id:, receive_address: 'tcp://localhost:5557',
                 send_address: 'tcp://localhost:5558')
    self.id = id
    self.receive_address = receive_address
    self.send_address = send_address
  end

  def run
    receiver_socket.connect receive_address
    sender_socket.connect send_address
    work_and_pipe
  end

  private

  attr_accessor :id, :receive_address, :send_address

  def work_and_pipe
    loop do
      workload = receiver_socket.recv
      puts "[Worker #{id}] Working for #{workload}s"
      sender_socket.send 'Finished'
    end
  end

  def receiver_socket
    @receiver_socket ||= CONTEXT.socket(ZMQ::PULL)
  end

  def sender_socket
    @sender_socket ||= CONTEXT.socket(ZMQ::PUSH)
  end
end

class Sink
  def initialize(address: 'tcp://*:5558')
    self.address = address
  end

  def run
    socket.bind address
    collect_results_evenly
  end

  private

  def collect_results_evenly
    10.times do |task_nbr|
      socket.recv
      puts "Finished task (#{task_nbr})"
    end
  end

  attr_accessor :address

  def socket
    @socket ||= CONTEXT.socket(ZMQ::PULL)
  end
end

Thread.new { Ventilator.new.run }
Thread.new { Worker.new(id: 'A').run }
Thread.new { Worker.new(id: 'B').run }
Thread.new { Sink.new.run }.join

# Output:
# Ventilating workload 0
# Ventilating workload 1
# Ventilating workload 2
# Ventilating workload 3
# Ventilating workload 4
# Ventilating workload 5
# Ventilating workload 6
# [Worker B] Working for 10s
# Ventilating workload 7
# Ventilating workload 8
# Ventilating workload 9
# [Worker A] Working for 10s
# [Worker A] Working for 10s
# [Worker A] Working for 10s
# Finished task (0)
# Finished task (1)
# Finished task (2)
# Finished task (3)
# [Worker B] Working for 10s
# [Worker B] Working for 10s
# [Worker B] Working for 10s
# [Worker B] Working for 10s
# [Worker A] Working for 10s
# [Worker A] Working for 10s
# Finished task (4)
# Finished task (5)
# Finished task (6)
# Finished task (7)
# Finished task (8)
# Finished task (9)


