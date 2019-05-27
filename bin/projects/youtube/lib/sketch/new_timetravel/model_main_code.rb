module Model
  class MainCode
    attr_reader :value
    
    def initialize
      @value = 1000
    end
    
    def update
      @value = @value + 10
      
      return true # return true if update was successful
    end
  end
end
