require 'yaml'
require 'pathname'
require 'fiber'


require './history'

require './nonblocking_error_output'
require './live_code_loader'
require './update_fiber'

require './model_code'
require './model_main_code'
require './model_raw_input'
require './model_core_space'

require './controller_state_machine'


class Main
  def initialize
    # wrap all models in History objects, to preserve history
    
    
    # TODO: After going back in time (to the past) and making a change, state between the past and the present will be invalidated. Need a way to overwrite this state in the alternate timeline. Currently, the old state will persist. Thus, reloading is only useful for effecting future state, which is... dramatically less useful.
    
    
    # Initial output stream for LiveCode
    # (must be global - can't store in LiveCode due to History serialization)
    $nonblocking_error = NonblockingErrorOutput.new($stdout)
    
    
    # space containing main entities
    @core_space = History.new(Model::CoreSpace.new)
    
    # raw user input data (drives sequences)
    @user_input = History.new(Model::RawInput.new)
    
    # code env with live reloading
    # (depends on @core_space and @user_input)
    @main_code =  History.new(
                    LiveCode.new(Model::MainCode.new,
                                 './model_main_code.rb'))
    
    
    # the controller passes information between many objects
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
