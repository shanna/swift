module Swift
  class Model
    def self.all scope, where=nil, bind=[], &block
      scope, where, bind = [ :default, scope, where || [] ] unless scope.kind_of?(Symbol)

      where = where ? 'where ' + where.gsub(/:(\w+)/) { n2f[$1.to_sym] } : ""
      Swift.db(scope).prepare(self, "select * from #{resource} #{where}").execute(*bind, &block)
    end

    def self.only scope, args={}, &block
      scope, args = [ :default, scope ] unless scope.kind_of?(Symbol)

      bind   = []
      limit  = args.key?(:limit)  ? "limit #{args.delete(:limit)}" : ""
      offset = args.key?(:offset) ? "offset #{args.delete(:offset)}" : ""
      where  = 'where ' + args.inject([]) {|w, (k,v)| bind << v; w + [ "#{n2f[k]} = ?" ] }.join(' and ')
      Swift.db(scope).prepare(self, "select * from #{resource} #{where} #{limit} #{offset}").execute(*bind, &block)
    end

    def self.create scope=:default, attrs=nil
      scope, attrs = [ :default, scope ] unless attrs
      raise ArgumentError, "Use Swift::Adapter#create to create multiple instances." if attrs.kind_of?(Array)
      Swift.db(scope).create(self, attrs).first
    end

    def update scope=:default, attrs=nil
      scope, attrs = [ :default, scope ] unless attrs
      attrs.each {|k,v| instance_variable_set("@#{k}", v) }
      Swift.db(scope).update self.class, self
    end
  end
end
