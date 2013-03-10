# Based on EM::Synchrony::ConnectionPool

module Swift
  class FiberConnectionPool

    def initialize opts, &block
      @reserved  = {}   # map of in-progress connections
      @available = []   # pool of free connections
      @pending   = []   # pending reservations (FIFO)
      @trace     = nil

      opts[:size].times do
        @available.push(block.call)
      end
    end

    def trace io = $stdout
      if block_given?
        begin
          _io, @trace = @trace, io
          yield
        ensure
          @trace = _io
        end
      else
        @trace = io
      end
    end

    private
      # Choose first available connection and pass it to the supplied
      # block. This will block indefinitely until there is an available
      # connection to service the request.
      def __reserve__
        id    = "#{Fiber.current.object_id}:#{rand}"
        fiber = Fiber.current
        begin
          yield acquire(id, fiber)
        ensure
          release(id)
        end
      end

      # Acquire a lock on a connection and assign it to executing fiber
      # - if connection is available, pass it back to the calling block
      # - if pool is full, yield the current fiber until connection is available
      def acquire id, fiber
        if conn = @available.pop
          @reserved[id] = conn
        else
          Fiber.yield @pending.push(fiber)
          acquire(id, fiber)
        end
      end

      # Release connection assigned to the supplied fiber and
      # resume any other pending connections (which will
      # immediately try to run acquire on the pool)
      def release(id)
        @available.push(@reserved.delete(id))
        if pending = @pending.shift
          pending.resume
        end
      end

      # Allow the pool to behave as the underlying connection
      def method_missing method, *args, &blk
        __reserve__ do |conn|
          if @trace
            conn.trace(@trace) {conn.__send__(method, *args, &blk)}
          else
            conn.__send__(method, *args, &blk)
          end
        end
      end
  end # FiberConnectionPool
end # Swift
