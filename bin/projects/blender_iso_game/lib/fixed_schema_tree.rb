class FixedSchemaTree
  def initialize(tree_like_hash)
    @hash = Hash.new
    
    # prohibit adding / deleting from Hash
    
    tree_like_hash.each do |key, val|
      if val.is_a? Hash
        @hash[key] = FixedSchemaTree.new(val)
      else
        @hash[key] = val
      end
    end
    
    @hash.freeze
  end
  
  def [](key)
    # using Hash#fetch with the did_you_mean gem enabled allows for spellcheck on key names. You need the exception to be thrown for this to work, so don't pass a block to #fetch.
    
    begin
      out = @hash.fetch(key)
      
      # return a subtree (which is also a FixedSchemaTree object)
      # or for leaf nodes, just return the actual data
      return out
      
    rescue KeyError => e
      # TODO: try patching the error message to be slightly more descriptive - wnat to know that it's coming from FixedSchemaTree access, not a normal hash
      
      p e.methods
      p e.original_message
      p e.spell_checker
      p e.corrections
      
      if e.corrections.empty?
        # patch error message if "did you mean" did not trigger
        msg = [
          "No subtree named #{key.inspect} ",
          "Did you mean?  #{@hash.keys.map{|x| x.inspect}.join(', ')}"
        ].join("\n")
        raise KeyError, msg
      else
        raise e
      end
      
      
      
      # raise e
    end
    
  end
end

