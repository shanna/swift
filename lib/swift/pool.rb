require 'eventmachine'

module Swift
  class Pool
    module Handler
      def initialize request, pool
        @request = request
        @pool    = pool
      end
      def notify_readable
        if @request.process
          @pool.detach self
          detach
        end
      end
    end

    def initialize size, options
      @pool = Swift::DBI::ConnectionPool.new size, options
      @pending = {}
    end

    def attach id
      @pending[id] = true
    end

    def detach id
      @pending.delete(id)
      EM.stop if @pending.empty?
    end

    def execute sql, *bind, &callback
      request = @pool.execute sql, *bind, &callback
      EM.watch(request.socket, Handler, request, self) do |c|
        attach c
        c.notify_writable = false
        c.notify_readable = true
      end
    end

    def run &block
      EM.run { instance_eval(&block) }
    end
  end

  def self.pool size, name=:default, &block
    scope = Swift.db(name) or raise RuntimeError, "Unable to initialize a pool for #{name}. Have you done #setup yet ?"
    Pool.new(size, scope.options).run(&block)
  end
end
