module Swift
  class Adapter < DBI::Handle
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
    # * Optional model first argument for single prepare multiple execute form.
    # * DB sync, default values, ids?
    def create *resources
      resources.each do |resource|
        attributes = resource.properties :field
        fields     = attributes.keys.join(', ')
        binds      = attributes.values
        supply     = (['?'] * attributes.size).join(', ')
        if prepare("insert into #{resource.model.resource} (#{fields}) values (#{supply})").execute(*binds)
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
