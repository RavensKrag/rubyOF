require './history'

require './model_main_code'
require './model_raw_input'
require './model_core_space'

require './controller_state_machine'

class Main
  def initialize
    # @live_code  = []                 # code env with live reloading
    main_code  = Model::MainCode.new  # code env with live reloading
    core_space = Model::RawInput.new  # space containing main entities
    user_input = Model::CoreSpace.new # raw user input data (drives sequences)
    
    # wrap all models in History objects, to preserve history
    @main_code  = History.new(main_code)
    @core_space = History.new(core_space)
    @user_input = History.new(user_input)
    
    
    
    @x = Controller.new(@main_code, @core_space, @user_input)
  end
  
  def run
    puts "initial states:"
    print "=> "
    p [@x.execution_state, @x.i]
    
    x = @x
    
    require 'irb'
    binding.irb
  end
end

Main.new.run
