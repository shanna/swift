module Swift
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

    def get model, *ids
      keys = model.keys.map{|k| "#{k.field} = ?"}.join(', ')
      prepare(model, "select * from #{model.resource} where #{keys}").execute(*ids).first
    end

    #--
    # TODO: Without a model as the first argument demand resources be Model suclass instances, find from cache or
    # create from a prepared insert statement for each class. Perhaps sort resource by class first if that helps.
    def create model, *resources
      raise TypeError, "Expected Model subclass but got '#{model.inspect}'." unless model.kind_of?(Class) && model < Model
      supply = model.properties.reject(&:serial?).map(&:field)
      st     = prepare(insert_query(model, supply))

      resources.map do |resource|
        resource = model.new(resource) unless resource.kind_of?(model)
        binds    = resource.properties(:field).values_at(*supply)
        if st.execute(*binds) && model.serial?
          resource.properties = {model.serial.name => st.insert_id}
        end
      end
    end

    def update model, *resources
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end

    protected
      def insert_query model, fields
        supply    = (['?'] * fields.size).join(', ')
        returning = "returning #{model.serial.field}" if model.serial? and returning?
        "insert into #{model.resource} (#{fields.join(', ')}) values (#{supply}) #{returning}"
      end
  end # Adapter
end # Swift
