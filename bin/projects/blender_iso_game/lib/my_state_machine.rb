

# abstract definition of state machine structure
# + next       delegate to current state (see 'States' module below)
class MyStateMachine
  # TODO: remove use of state_machine library in live_code.rb, and then rename this class to StateMachine
  
  extend Forwardable
  
  def initialize()
    
  end
  
  def setup(&block)
    helper = StateDefinitionHelper.new(TempStorage.new)
    
    block.call helper
    
    helper.data.tap do |d|
      @states         = d.states
      @transitions    = d.transitions # [prev_state, next_state, Proc]
      
      @previous_state = nil
      @current_state  = d.initial_state
      
      @current_state.on_enter()
    end
    
  end
  
  # trigger transition to the specified state
  def transition_to(new_state_klass, ipc)
    if not state_defined? new_state_klass
      raise "ERROR: #{new_state_klass} is not one of the available states declared using #define_states. Valid states are: #{@states.map{|x| x.class}.inspect}"
    end
    
    new_state = find_state(new_state_klass)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    
    new_state.on_enter(ipc)
    @previous_state = @current_state
    @current_state = new_state
    
    match(@previous_state, @current_state, transition_args:[ipc])
  end
  
  # returns current state object
  # WARNING: this may allow external systems to alter the state object.
  def current_state
    return @current_state
  end
  
  
  
  class StateDefinitionHelper
    attr_accessor :data
    
    def initialize(data)
      @data = data
    end
    
    def define_states(*args)
      # ASSUME: all arguments should be objects that implement the desired semantics of a state machine state. not exactly sure what that means rigorously, so can't perform error checking.
      
      @data.states = args
    end
    
    def initial_state(state_class)
      if @data.states.empty?
        raise "ERROR: Must first declare all possible states using #define_states. Then, you can specify one of those states to be the initial state, by providing the class of that state object."
      end
      
      unless @data.state_defined? state_class
        raise "ERROR: #{state_class.inspect} is not one of the available states declared using #define_states. Valid states are: #{ @data.states.map{|x| x.class} }"
      end
      
      @data.initial_state = @data.find_state(state_class)
    end
    
    def define_transitions(&block)
      helper = PatternHelper.new(@data)
      block.call helper
      # ^ sets @data.transitions directly
    end
  end
  
  class PatternHelper
    def initialize(data)
      @data = data
    end
    
    # States::StateOne => States::StateTwo do ...
    def on_transition(pair={}, &block)
      prev_state_id = pair.keys.first
      next_state_id = pair.values.first
      
      [prev_state_id, next_state_id].each do |state_class|
        unless(state_class == :any || 
               state_class == :any_other ||
               @data.state_defined?(state_class)
        )
          raise "ERROR: State transition was not defined correctly. Given '#{state_class.to_s}', but expected either one of the states declared using #define_states, or the symbols :any or :any_other, which specify sets of states. Defined states are: #{ @data.states.map{|x| x.class}.inspect }"
        end
      end
      
      @data.transitions << [ prev_state_id, next_state_id, block ]
    end
  end
  
  # temporarily store data in this class while state machine is being declared
  class TempStorage
    attr_accessor :states, :transitions, :initial_state
    
    def initialize
      @states = []
      @transitions = []
      @initial_state = nil
    end
    
    # returns true if @states contains an object of the specified class
    def state_defined?(state_class)
      return find_state(state_class) != nil
    end
    
    # return the first state object which is a subclass of the given class
    def find_state(state_class)
      return @states.find{|x| x.is_a? state_class }
    end
  end
  
  
  
  private
  
  def match(p,n, transition_args:[])
    @transitions.each do |prev_state_id, next_state_id, proc|
      # state IDs can be the class constant of a state,
      # or the symbols :any or :any_other
      # :any matches any state (allowing self loops)
      # :any_other matches any state other than the other specified state (no self loop)
      # if you specify :any_other in both slots, the callback will trigger on all transitions that are not self loops
      
      cond1 = (
        (prev_state_id == :any) || 
        (prev_state_id == :any_other && p != n) ||
        (p.is_a? prev_state_id)
      )
      
      cond2 = (
        (next_state_id == :any) || 
        (next_state_id == :any_other && n != p) ||
        (n.is_a? next_state_id)
      )
      
      if cond1 && cond2
        proc.call(*transition_args)
      end
    end
  end
  
  # returns true if @states contains an object of the specified class
  def state_defined?(state_class)
    return find_state(state_class) != nil
  end
  
  # return the first state object which is a subclass of the given class
  def find_state(state_class)
    return @states.find{|x| x.is_a? state_class }
  end
  
end
