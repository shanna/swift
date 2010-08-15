module Swift
  class Scheme
    def self.migrations &migrations
      (class << self; self end).send :define_method, :migrate!, lambda{|db = Swift.db| migrations.call(db) }
    end

    def self.migrate!
      Swift.db.migrate! self
    end
  end # Scheme

  def self.migrate! name = nil
    scheme.each{|scheme| scheme.migrate!(db(name)) }
  end
end # Swift
