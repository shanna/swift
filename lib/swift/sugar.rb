module Swift
  class Model
    class << self
      def all db = nil, where = nil, bind = [], &block
        db, where, bind = [:default, db, where || []] unless db.kind_of?(Symbol)

        where = where ? 'where ' + where.gsub(/:(\w+)/) { fieldmap[$1.to_sym] } : ""
        Swift.db(db).prepare(self, "select * from #{resource} #{where}").execute(*bind, &block)
      end

      def only db, args = {}, &block
        db, args = [:default, db] unless db.kind_of?(Symbol)

        bind   = []
        limit  = args.key?(:limit)  ? "limit #{args.delete(:limit)}" : ""
        offset = args.key?(:offset) ? "offset #{args.delete(:offset)}" : ""
        where  = 'where ' + args.inject([]) {|w, (k,v)| bind << v; w + [ "#{fieldmap[k]} = ?" ] }.join(' and ')
        Swift.db(db).prepare(self, "select * from #{resource} #{where} #{limit} #{offset}").execute(*bind, &block)
      end

      def first db, args = {}
        only(db, args).first
      end

      def get db, *id
        db.kind_of?(Symbol) ? Swift.db(db).get(self, *id) : Swift.db(:default).get(self, db, *id)
      end

      def create db = :default, attrs = nil
        db, attrs = [ :default, db ] unless attrs
        raise ArgumentError, "Use Swift::Adapter#create to create multiple instances." if attrs.kind_of?(Array)
        Swift.db(db).create(self, attrs).first
      end

      private
        def fieldmap
          @fieldmap ||= Hash[*fields.zip(names).flatten]
        end
    end

    def update db = :default, attributes = nil
      db, attributes = [:default, db] unless attributes
      model.properties.each{|p| send(:"#{p.name}=", attributes.fetch(p.name, p.default)) if attributes.key?(p.name)}
      Swift.db(db).update(model, self)
    end

    # TODO should we prepare cache this too ?
    def destroy db = :default
      keys  = model.key.map(&:field)
      bind  = properties(:field).values_at(*keys)
      where = keys.map {|key| "#{key} = ?" }.join(' and ')
      Swift.db(db).execute("delete from #{model.resource} where #{where}", *bind)
    end
  end # Model
end # Swift
