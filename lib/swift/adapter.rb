module Swift
  class Adapter < DBI::Handle

    # TODO move storing credentials to extension.
    attr_reader :options, :driver
    def initialize args
      @driver  = args[:driver]
      @options = args
      super(args)
    end

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
    # * Sequence handling since postgres and mysql do it different.
    def create *resources
      resources.each do |resource|
        attributes = resource.properties(:field)
        fields     = attributes.keys.join(', ')
        binds      = attributes.values
        supply     = (['?'] * attributes.size).join(', ')
        if st = prepare("insert into #{resource.model.resource} (#{fields}) values (#{supply})").execute(*binds)
          pp st.insert_id
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
