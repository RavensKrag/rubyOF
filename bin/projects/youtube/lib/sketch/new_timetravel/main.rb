

require './model_raw_input'
require './model_core_space'

require './controller_state_machine'

class Main
  def initialize
    # @live_code  = []                 # code env with live reloading
    @core_space = Model::RawInput.new  # space containing main entities
    @user_input = Model::CoreSpace.new # raw user input data (drives sequences)
    
    
    
    @x = Controller.new(@core_space, @user_input)

  end
  
  def run
    puts "initial states:"
    print "=> "
    p [@x.execution_state, @x.i]

    require 'irb'
    binding.irb
  end
end

Main.new.run
