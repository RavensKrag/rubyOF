module Model
  class MainCode
    attr_reader :value
    
    def initialize
      
    end
    
    def update
      @fiber ||= Fiber.new do
        
        ('a'..'z').each do |letter|
          @value = letter
          Fiber.yield
        end
        
      end
      
      @fiber.resume
    end
  end
end
