module Model
  class MainCode
    def initialize(core_space, user_input)
      @space_history = core_space
      @input_history = user_input
    end
    
    def update
      @space_history.inner.tap do |space|
        space.value = space.value + 10
      end
      
      
      return true # return true if update was successful
    end
    
    def value
      @space_history.inner.value
    end
  end
end
