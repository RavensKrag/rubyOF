class History
  def initialize
    @buffer = HistoryBuffer.new
    @shared_data = Context.new(@buffer)
    @transport = TimelineTransport.new(@shared_data, @state_machine)
    # ^ methods = [:play, :pause, :seek, :reset]
    
    @state_machine = StateMachine.new(@transport, @shared_data)
    @state_machine.setup do |s|
      s.define_states States::Initial,
                      States::GeneratingNew,
                      States::ReplayingOld,
                      States::Finished
      
      s.initial_state States::Initial
      
      s.define_transitions do |p|
        p.on_transition :any_other => States::Finished do |ipc|
          puts "finished --> (send message to blender)"
          
          ipc.send_to_blender({
            'type' => 'loopback_finished',
            'history.length' => @shared_data.history.length
          })
        end
        
        p.on_transition States::GeneratingNew => States::ReplayingOld do |ipc|
          # should cover both pausing and pulling the read head back
          
          ipc.send_to_blender({
            'type' => 'loopback_paused_new',
            'history.length'      => @shared_data.history.length,
            'history.frame_index' => @shared_data.frame_index
          })
        end
      end
    end
    
  end
  
  attr_reader :transport
  
  def bind_to_world(world)
    world.bind_history @history
  end
  
  def update(ipc, &block)
    @state_machine.update(ipc)
    
    if @transport.playing?
      @shared_data.bind_code(block)
      @state_machine.next
    end
  end
  
  def on_reload_code(ipc)
    
  end
  
  def on_reload_data(ipc)
    
  end
end



# control timeline transport (move back and forward in time)
class TimelineTransport
  def initialize(shared_data, state_machine)
    @state_machine = state_machine
    @data = shared_data
    @frame = 0
    @play_or_pause = :paused
  end
  
  # if playing, pause forward playback
  # else, do nothing
  def pause
    @play_or_pause = :paused
  end
  
  # if paused, run forward
  # 'running' has different behavior depending on the currently active state
  # may generate new data from code,
  # or may replay saved data from history buffer
  def play
    @play_or_pause = :playing
  end
  
  def paused?
    return @play_or_pause == :paused
  end
  
  def playing?
    return @play_or_pause == :playing
  end
  
  # instantly move to desired frame number
  # (moving frame-by-frame in blender is implemented in terms of #seek)
  def seek(frame_number)
    @data.frame_index = frame_number
    @state_machine.seek(@data.frame_index)
  end
  
  # reset the timeline back to t=0 and clear history
  def reset
    
  end
  
  
  # where does this belong?
  def on_crash
    @data.frame_index -= 1
    self.seek(@data.frame_index)
  end
end

# state shared between TimelineTransport and the StateMachine states,
# but that is not revealed to the outside world
class Context
  attr_accessor :frame_index
  attr_accessor :block
  
  def initialize(buffer)
    @buffer = buffer
    @frame_index = 0
    
    # @final_frame = ???
    # TODO: implement @final_frame and outside access
  end
  
  def bind_code(&block)
    @block = block
  end
  
  def load_state_at_current_frame
    @buffer.load_state_at @frame_index
  end
  
  def snapshot_gamestate_at_current_frame
    # @buffer.load_state_at @frame_index
  end
  
end

# helps to save stuff from code into the buffer, so we can time travel later
class Helper
  def initialize(context, history)
    @context = context
    @history = history
    
    # TODO: how can I allow GeneratingNew to have access to the history buffer, without exposing the ability to take snapshots to all states?
      # currently, Helper is being initialized by GeneratingNew.
      # This means Helper can't recieve any data that GeneratingNew doesn't already have, but GeneratingNew shares the same data will all other StateMachine states.
  end
  
  def frame(&block)
    if @context.frame_index < @context.final_frame
      # resuming
      
      # if manually stepping forward, we'll be able to see the transition
      # but otherwise, this transition will be silent,
      # because there is no Fiber.yield in this branch.
      # 
      # (keeps logs clean unless you really need the info)
      
      # (skip this frame)
      # don't run the code for this frame,
      # so instead update the transforms
      # based on the history buffer
      
      # Can't just jump in the buffer, because we need to advance the Fiber.
      # BUT we may be able to optimize to just loading the last old state
      # before we need to generate new states.
      
      @context.frame_index += 1
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} resuming"
      
      @history.load_state_at @context.frame_index
      
    else # [@history.length-1, inf]
      # actually generating new state
      @history.snapshot_gamestate_at @context.frame_index
      
      # p [@context.frame_index, @history.length-1]
      # puts "history length: #{@history.length}"
      
      @context.frame_index += 1
      
      frame_str = @context.frame_index.to_s.rjust(4, '0')
      src_file, src_line = block.source_location
      
      file_str = src_file.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")
      
      puts "#{frame_str} new state  #{file_str}, line #{src_line} "
      
      # p block
      # puts "--------------------------------"
      # p block.source_location
      block.call()
      # puts "--------------------------------"
      
      Fiber.yield
    # elsif @executing_frame > @history.length
    #   # scrubbing in future space
    #   # NO-OP
    #   # (pretty sure I need both this logic and the logic in Finished)
    # else
    #   # initial state??
    #   # not sure what's left
    end
    
  end
end





# abstract definition of state machine structure
# + update     triggers state transitions
# + next       delegate to current state (see 'States' module below)
class StateMachine
  extend Forwardable
  
  def initialize(transport, shared_data)
    @transport = transport
    @shared_data = shared_data
  end
  
  def setup(&block)
    @states = []
    @transitions = [] # [prev_state, next_state, Proc]
    
    helper = DSL_Helper.new(@states, @transitions)
    block.call helper
    
    @previous_state = nil
    @current_state = helper.initial_state.new(self, @transport, @shared_data)
  end
  
  # update internal state and fire state transition callbacks
  def update(ipc)
    match(@previous_state, @current_state, transition_args:[ipc])
  end
  
  def_delegators :@current_state, :next
  
  
  
  # trigger transition to the specified state
  def transition_to(new_state_klass)
    if not @states.include? new_state_klass
      raise "ERROR: '#{new_state_klass.to_s}' is not one of the available states declared using #define_states. Valid states are: #{@states.inspect}"
    end
    
    new_state = new_state_klass.new(self)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    
    new_state.on_enter()
    @previous_state = @current_state
    @current_state = new_state
  end
  
  class DSL_Helper
    attr_reader :initial_state
    
    def initialize(states, transitions)
      @states = states
      @transitions = transitions
    end
    
    def define_states(*args)
      args.each do |state_class|
        if not state_class.is_a? DefaultState
          raise "ERROR: tried to specify state #{state.to_s}, but all states must be descendants of the DefaultState class."
        end
      end
      
      @states = args
    end
    
    def initial_state(state_class)
      if @states.empty?
        raise "ERROR: Must first declare all possible states using #define_states. Then, you can specify one of those states to be the initial state"
      end
      
      unless @states.include? state_class
        raise "ERROR: '#{state_class.to_s}' is not one of the available states declared using #define_states. Valid states are: #{@states.inspect}"
      end
      
      @initial_state = state_class
    end
    
    def define_transitions(&block)
      helper = PatternHelper.new(@states, @transitions)
      block.call helper
    end
    
    
    class PatternHelper
      def initialize(states, transitions)
        @states = states
        @transitions = transitions
      end
      
      # States::StateOne => States::StateTwo do ...
      def on_transition(pair={}, &block)
        prev_state_id = pair.keys.first
        next_state_id = pair.values.first
        
        [prev_state_id, next_state_id].each do |state_class|
          unless(state_class == :any || 
                 state_class == :any_other ||
                 @states.include? state_class
          )
            raise "ERROR: State transition was not defined correctly. Given '#{state_class.to_s}', but expected either one of the states declared using #define_states, or the symbols :any or :any_other, which specify sets of states. Defined states are: #{@states.inspect}"
          end
        end
        
        @transitions << [ prev_state_id, next_state_id, block ]
      end
    end
  end
  
  
  private
  
  
  def match(p,n, transition_args:[])
    @patterns.each do |prev_state_id, next_state_id, proc|
      # state IDs can be the class constant of a state,
      # or the symbols :any or :any_other
      # :any matches any state (allowing self loops)
      # :any_other matches any state other than the other specified state (no self loop)
      # if you specify :any_other in both slots, the callback will trigger on all transitions that are not self loops
      
      cond1 = (
        (prev_state_id == :any) || 
        (prev_state_id == :any_other && p != n) ||
        (p == prev_state_id)
      )
      
      cond2 = (
        (next_state_id == :any) || 
        (next_state_id == :any_other && n != p) ||
        (n == next_state_id)
      )
      
      if cond1 && cond2
        proc.call(*args)
      end
    end
  end
end

class DefaultState
  def initialize(state_machine, transport, context)
    @state_machine = state_machine
    @transport = transport
    @context = context
  end
end


# states used by state machine defined below
# ---
# should we generate new state from code or replay old state from the buffer?
# that depends on the current system state, so let's use a state machine.
# + next       advance the system forward by 1 frame
# + seek       jump to an arbitrary frame
module States
  class Initial < DefaultState
    def on_enter
      
    end
    
    # step forward one frame
    # (name taken from Enumerator#next, which functions similarly)
    def next
      @state_machine.transition_to GeneratingNew
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      
    end
  end
  
  class GeneratingNew < DefaultState
    def on_enter
      
    end
    
    # step forward one frame
    def next
      @f2 ||= Fiber.new do
        # This Fiber wraps the block so we can resume where we left off
        # after Helper pauses execution
        @context.block.call(Helper.new(@context))
      end
      
      @f1 ||= Fiber.new do
        # Execute @f2 across many different frames, instead of all at once
        while @f2.alive?
          @f2.resume()
          Fiber.yield
        end
      end
      
      if @f1.alive?
        # if there is more code to run, run the code to generate new state
        @f1.resume()
      else
        # else, code has completed
        @context.transition_to Finished
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      
    end
  end
  
  class ReplayingOld < DefaultState
    def on_enter
      
    end
    
    # step forward one frame
    def next
      if @context.frame_index >= @context.final_frame
        # ran past the end of saved history
        # must retun to generating new data from the code
        
        # @context.transition_and_rerun(GeneratingNew, :update, &block)
        @state_machine.transition_to GeneratingNew
        @state_machine.next
        
      else # @context.frame_index < @context.final_frame
        # otherwise, just load the pre-generated state from the buffer
        
        @context.frame_index += 1
        @context.load_state_at_current_frame
        
        # stay in state ReplayingOld
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @context.final_frame) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @context.frame_index = frame_number
        @context.load_state_at_current_frame
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @context.final_frame
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @context.frame_index = @context.final_frame
        @context.load_state_at_current_frame
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        @transport.pause
        
        # stay in state ReplayingOld
        
      else # frame_number < 0
        raise "ERROR: Tried to seek to negative frame => (#{frame_number})"
      end
      # TODO: Blender frames can be negative. should handle that case too.
          
    end
  end
  
  class Finished < DefaultState
    def on_enter
      puts "#{@context.frame_index.to_s.rjust(4, '0')} initial"
    end
    
    # step forward one frame
    def next
      # instead of advancing the frame, or altering state,
      # just pause execution again
      @transport.pause
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      if frame_number >= @context.final_frame
        # NO-OP
      else
        # @context.transition_and_rerun ReplayingOld, :seek, frame_number
        @state_machine.transition_to ReplayingOld
        @state_machine.seek(frame_number)
        
      end
    end
  end
end





# stores the data for time traveling
class HistoryBuffer
  def bind_world(world)
    
  end
  
  def save_state(data)
    
  end
  
  def load_state_at(frame_index)
    
  end
end
