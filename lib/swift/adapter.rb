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
    # TODO: This is where it gets suck.
    # * Optional model first argument for single prepare multiple execute form?
    def create *resources
      resources.each do |resource|
        model      = resource.model
        attributes = resource.properties(:field)
        fields     = attributes.keys.join(', ')
        binds      = attributes.values
        supply     = (['?'] * attributes.size).join(', ')
        returning  = "returning #{model.serial.field}" if model.serial? and returning?
        if st = prepare("insert into #{resource.model.resource} (#{fields}) values (#{supply}) #{returning}").execute(*binds)
          resource.properties = {model.serial.name => st.insert_id}
        end
      end
    end

    def update *resources
    end

    def transaction name = nil, &block
      super(name){ self.instance_eval(&block)}
    end
  end # Adapter
end # Swift
