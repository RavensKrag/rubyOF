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
    
    
    # FIXME: After going back in time (to the past) and making a change, state between the past and the present will be invalidated. Need a way to overwrite this state in the alternate timeline. Currently, the old state will persist. Thus, reloading is only useful for effecting future state, which is... dramatically less useful.
    
    # FIXME: Integrate this code with RubyOF in a new project (make copy of 'youtube' project)
      # start by creating a View class for visualization
      # have been doing a lot of repetitive typing to step back and forth
      # get a UI for that instead (just use OpenFrameworks UI stuff)
      # and instead of guess and check recompiling of C++,
      # set unknown values through Ruby calls, that can be tried in REPL.
      # 
      # May actually need to set up RubyOF + REPL first
      # because REPL is a good fallback from direct manipulation.
      # -- how can I step with both the REPL and a GUI??
    
    
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
