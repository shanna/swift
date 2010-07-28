module Swift
  class Statement < DBI::Statement
    def initialize adapter, scheme, query
      @scheme = scheme
      super adapter, query
    end

    def each
      super{|att| yield @scheme.load att}
    end
  end # Statement
end # Swift
