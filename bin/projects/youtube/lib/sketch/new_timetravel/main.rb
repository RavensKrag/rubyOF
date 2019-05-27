require 'yaml'
require 'pathname'

require './history'
require './live_code_loader'

require './model_main_code'
require './model_raw_input'
require './model_core_space'

require './controller_state_machine'


class Main
  def initialize
    # wrap all models in History objects, to preserve history
    
    # FIXME: History has problems with loading LiveCode because it contains an Proc (error handling callbacks)
    
    # code env with live reloading
    @main_code =  History.new(
                    LiveCode.new(
                      Model::MainCode.new, './model_main_code',
                      on_load_attempt: ->(file){
                        puts "live loading #{file}"
                      },
                      on_load:  ->(file){
                        puts "file loaded"
                      },
                      on_error: ->(file, e){
                        puts "FAILURE TO LOAD: #{file}"
                        
                        # Should print the error to some sort of log.
                        # Specific handling may need to use another thread.
                      }
                    ))
    
    
    # space containing main entities
    @core_space = History.new(Model::RawInput.new)
    
    # raw user input data (drives sequences)
    @user_input = History.new(Model::CoreSpace.new)
    
    
    
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
