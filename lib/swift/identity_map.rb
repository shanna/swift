module Swift
  # Weak hash set.
  #--
  # TODO: Is 'hash set' the real name for a hash where both the keys and values must be unique?
  class IdentityMap
    def initialize
      @cache, @reverse_cache, @finalize = {}, {}, method(:finalize)
    end

    def get key
      value_id = @cache[key]
      return ObjectSpace._id2ref(value_id) unless value_id.nil?
      nil
    end

    #--
    # TODO: Barf if the value.object_id already exists in the cache.
    def set key, value
      @reverse_cache[value.object_id] = key
      @cache[key]                     = value.object_id
      ObjectSpace.define_finalizer(value, @finalize)
    end

    private
      def finalize value_id
        @cache.delete @reverse_cache.delete value_id
      end
  end # IdentityMap

  class Adapter
    def identity_map
      @identity_map ||= IdentityMap.new
    end
  end

  class Record
    #--
    # TODO: Redefined method :(
    def self.load tuple
      im = [self, *tuple.values_at(*header.keys)]
      unless record = Swift.db.identity_map.get(im)
        record       = allocate
        record.tuple = tuple
        Swift.db.identity_map.set(im, record)
      end
      record
    end
  end # Record
end # Swift
