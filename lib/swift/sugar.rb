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
  end
end
