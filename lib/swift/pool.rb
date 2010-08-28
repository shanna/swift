require 'eventmachine'

module Swift
  class Pool
    module Handler
      def initialize request, pool
        @request, @pool = request, pool
      end

      def socket
        @request.socket
      end

      def notify_readable
        if @request.process
          detach
          @pool.detach self
        end
      end
    end # Handler


    def initialize size, options
      @pool         = Swift::DB::Pool.new size, options
      @stop_reactor = EM.reactor_running? ? false : true
      @pending      = {}
      @queue        = []
    end

    def attach c
      @pending[c] = true
    end

    def detach c
      @pending.delete(c)
      if @queue.empty?
        EM.stop if @stop_reactor && @pending.empty?
      else
        sql, bind, callback = @queue.shift
        execute(sql, *bind, &callback)
      end
    end

    def attached? fd
      @pending.keys.select{|c| c.socket == fd}.length > 0
    end

    def execute sql, *bind, &callback
      request = @pool.execute sql, *bind, &callback
      # TODO EM throws exceptions in C++ land which are not trapped in the extension.
      #      This is somehow causing everything to unravel and result in a segfault which
      #      I cannot track down. I'll buy a beer for someone who can get this fixed :)
      #      Oh, here it throws an exception if we try to attach same fd twice.
      if request && !attached?(request.socket)
        EM.watch(request.socket, Handler, request, self) do |c|
          attach c
          c.notify_writable = false
          c.notify_readable = true
        end
      else
        @queue << [ sql, bind, callback ]
      end
    end

    def run &block
      EM.run{ yield self }
    end
  end # Pool

  def self.pool size, name = :default, &block
    pool = Pool.new(size, Swift.db(name).options)
    pool.run(&block) if block_given?
    pool
  end
end # Swift
