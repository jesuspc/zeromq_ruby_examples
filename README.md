# ZeroMQ Ruby Examples

## A brief description

Those are example implementations of network topologies using a Ruby wrapper on
top of CZMQ, a high-level C binding of [ZeroMQ](http://zeromq.org).

## Install

Simply clone the repo and install the
[rbczmq](https://github.com/methodmissing/rbczmq) gem, which already includes
the source code for both ZeroMQ and CZMQ:

```bash
gem install rbczmq
```

The scripts have been tested with Ruby 2.4.x and rbczmq 1.7.x.

## How to use it

Each file can be required by other files in order to reuse the module defined
in it, but can also be run directly from the command line. To do so a _run_
flag has to be provided:

```bash
ruby 01_hello_world.rb run
```

## Sources

* [ZeroMQ official guide](http://zguide.zeromq.org/page:all)
