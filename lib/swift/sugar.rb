module Swift
  class Model

    class << self
      def fieldmap; @fieldmap ||= Hash[*fields.zip(names).flatten] end
      private :fieldmap

      def all scope=nil, where=nil, bind=[], &block
        scope, where, bind = [ :default, scope, where || [] ] unless scope.kind_of?(Symbol)

        where = where ? 'where ' + where.gsub(/:(\w+)/) { fieldmap[$1.to_sym] } : ""
        Swift.db(scope).prepare(self, "select * from #{resource} #{where}").execute(*bind, &block)
      end

      def only scope, args={}, &block
        scope, args = [ :default, scope ] unless scope.kind_of?(Symbol)

        bind   = []
        limit  = args.key?(:limit)  ? "limit #{args.delete(:limit)}" : ""
        offset = args.key?(:offset) ? "offset #{args.delete(:offset)}" : ""
        where  = 'where ' + args.inject([]) {|w, (k,v)| bind << v; w + [ "#{fieldmap[k]} = ?" ] }.join(' and ')
        Swift.db(scope).prepare(self, "select * from #{resource} #{where} #{limit} #{offset}").execute(*bind, &block)
      end

      def create scope=:default, attrs=nil
        scope, attrs = [ :default, scope ] unless attrs
        raise ArgumentError, "Use Swift::Adapter#create to create multiple instances." if attrs.kind_of?(Array)
        Swift.db(scope).create(self, attrs).first
      end
    end

    def update scope=:default, attrs=nil
      scope, attrs = [ :default, scope ] unless attrs
      attrs.each {|k,v| instance_variable_set("@#{k}", v) }
      Swift.db(scope).update self.class, self
    end
  end
end
