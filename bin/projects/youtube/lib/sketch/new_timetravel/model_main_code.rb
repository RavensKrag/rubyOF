module Model
  class MainCode
    def initialize
      # can't store 
    end
    
    def update(space_history, input_history)
      # TODO: does the code need to be a model? should it be a controller?
        # it does have to be a model in a sense, as it owns non-spatial data
      # TODO: does this code need access to the entire history, or is it sufficient to only pass it the current state of the space / input?
        # need to understand inputs over time, so that's probably out.
        # understanding space over time might be good for understanding movement?
      # maybe just leave things like this for now
      
      space_history.inner.tap do |space|
        space.value = space.value + 10
      end
      
      
      return true # return true if update was successful
    end
  end
end
