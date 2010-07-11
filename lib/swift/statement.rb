module Swift
  class Statement < DBI::Statement
    def initialize adapter, model, query
      @model = model
      super adapter, query
    end

    def each
      super{|att| yield @model.load att}
    end
  end # Statement
end # Swift
