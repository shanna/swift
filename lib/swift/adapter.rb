module Swift
  #--
  # TODO: Golf, DRY and cache the SQL stuff.
  class Adapter < DBI::Handle

    # TODO: DBI::Handle should have this stuff.
    attr_reader :options, :driver

    def initialize options = {}
      @driver  = options.fetch(:driver)
      @options = options
      super
    end

    def returning?
      @driver == 'postgresql'
    end
    protected :returning?

    def identity_map
      @identity_map ||= IdentityMap.new
    end

    def prepare model, query = nil
      return super(model) unless model.kind_of?(Class) && model < Model
      Statement.new(self, model, query)
    end

    def get model, id
      id   = {model.key.first.name => id} unless id.is_a?(Hash)
      id   = Hash[*model.key.map(&:field).zip(id.values_at(*model.key.map(&:name))).flatten]
      keys = id.keys.map{|k| "#{k} = ?"}.join(' and ')
      prepare(model, "select * from #{model.resource} where #{keys}").execute(*id.values).first
    end

    #--
    # TODO: Without a model as the first argument demand resources be Model suclass instances, find from cache or
    # create from a prepared insert statement for each class. Perhaps sort resource by class first if that helps.
    def create model, *resources
      supply = model.properties.reject(&:serial?).map(&:field)
      st     = prepare_insert(model)

      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        binds    = resource.properties(:field).values_at(*supply)
        if st.execute(*binds) && model.serial?
          resource.properties = {model.serial.name => st.insert_id}
        end
        resource
      end
    end

    def update model, *resources
      supply = model.properties.reject(&:key?).map(&:field)
      st     = prepare_update(model)

      resources.map do |resource|
        binds = [resource.properties(:field).values_at(*supply, *model.key.map(&:field))].flatten
        st.execute(*binds)
      end
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end

    protected
      def cache model, op, sql
        @cache ||= {}
        @cache[model] ||= { insert: nil, update: nil }
        @cache[model][op] ||= prepare(sql)
      end

      def prepare_insert model
        fields    = model.properties.reject(&:serial?).map(&:field)
        binds     = (['?'] * fields.size).join(', ')
        returning = "returning #{model.serial.field}" if model.serial? and returning?
        cache(model, :insert, "insert into #{model.resource} (#{fields.join(', ')}) values (#{binds}) #{returning}")
      end

      #--
      # TODO: Gah you can't update keys.
      def prepare_update model
        fields = model.properties.reject(&:key?).map(&:field)
        supply = fields.map{|f| "#{f} = ?"}.join(', ')
        keys   = model.key.map{|k| "#{k.field} = ?"}.join(' and ')
        cache(model, :update, "update #{model.resource} set #{supply} where #{keys}")
      end
  end # Adapter
end # Swift
