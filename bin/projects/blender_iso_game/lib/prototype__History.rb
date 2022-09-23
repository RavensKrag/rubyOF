class History
  def initialize
    @buffer = HistoryBuffer.new
    @shared_data = Context.new(@buffer)
    @transport = TimelineTransport.new(@shared_data, @state_machine)
    # ^ methods = [:play, :pause, :seek, :reset]
    
    h1 = SaveHelper.new(@buffer, @shared_data)
    h2 = LoadHelper.new(@buffer, @shared_data)
    
    @state_machine = StateMachine.new
    @state_machine.setup do |s|
      s.define_states(
        States::Initial.new(      @state_machine),
        States::GeneratingNew.new(@state_machine, @shared_data, h1),
        States::ReplayingOld.new( @state_machine, @shared_data, @transport, h2),
        States::Finished.new(     @state_machine, @shared_data, @transport, h2)
      )
      
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
  
  # where does this belong?
  def on_crash(ipc)
    @shared_data.frame_index -= 1
    @transport.seek(@shared_data.frame_index)
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
  
  def final_frame
    @buffer.length
  end
end

# helps to save stuff from code into the buffer, so we can time travel later
class SaveHelper
  # TODO: re-name this class. it actually does some amount of loading too, so that it can resume fibers...
  def initialize(history_buffer, context)
    @history = history_buffer
    @context = context
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
      snapshot_gamestate_at_current_frame()
      
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
  
  private
  
  def snapshot_gamestate_at_current_frame
    @state[:cache].update @state[:pixels]
    @history[frame_index] = @state[:pixels]
    
    # NOTE: cache#update is sort of a weird interface, because the data is flowing from left-to-right (cache -> pixels), even though standard data assigment direction is right-to-left
  end
end

# helps to load data from the buffer
class LoadHelper
  def initialize(history_buffer, context)
    @history = history_buffer
    @context = context
  end
  
  def load_state_at_current_frame
    cached_data = @history[@context.frame_index]
    @state[:pixels].copy_from cached_data
    @state[:cache].load @state[:pixels]
    
    # TODO: find a better interface for loading
      # when I save the frame, it looks just like array saving,
      # but when I load the frame I have to call #copy_from.
      # Is there a way to make this more symmetric?
    
  end
end

# TODO: consider consolidating all high-level buffer operations in one place
class Foo
  def initialize(buffer)
    @buffer = buffer
    
    
    # retain key data objects for entity state
    @state = {
      :pixels => pixels,
      :texture => texture,
      :cache => cache
    }
    
    # where does the data move from :pixels to :cache ?
    # It's not in this file.
    # Should it be here? It might make the information flow clearer.
    
    # currently in VertexAnimationTextureSet#update
      # /home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/lib/vertex_animation_texture_set.rb
      # probably want to keep the logic there because it also handles serialization (disk -> pixels -> texture and cache)
      # but maybe we call the update from here instead of the current location?
    
    # World#update -> VertexAnimationTextureSet#update
  end
  
  # create buffer of a certain size
  def setup
    @buffer.setup(buffer_length: 3600,
                  frame_width:   @state[:pixels].width,
                  frame_height:  @state[:pixels].height)
    
  end
  
  # save current frame to buffer
  def snapshot
    @state[:cache].update @state[:pixels]
    @buffer[frame_index] = @state[:pixels]
  end
  
  # load current frame from buffer
  def load
    cached_data = @buffer[@context.frame_index]
    @state[:pixels].copy_from cached_data
    @state[:cache].load @state[:pixels]
  end
  
  # delete arbitrary frame from buffer
  def delete
    # @buffer.delete(@context.frame_index)
  end
  
  # create a new buffer using a slice of the current buffer
  def branch
     
  end
end










# abstract definition of state machine structure
# + update     triggers state transitions
# + next       delegate to current state (see 'States' module below)
class StateMachine
  extend Forwardable
  
  def initialize()
    
  end
  
  def setup(&block)
    @states = []
    @transitions = [] # [prev_state, next_state, Proc]
    
    helper = DSL_Helper.new(@states, @transitions)
    block.call helper
    
    @previous_state = nil
    @current_state = helper.initial_state
  end
  
  # update internal state and fire state transition callbacks
  def update(ipc)
    match(@previous_state, @current_state, transition_args:[ipc])
  end
  
  def_delegators :@current_state, :next
  # TODO: Implement custom delegation using method_missing, so that the methods to be delegated can be specified on setup. Should extend the DSL with this extra functionality. That way, the state machine can become a fully reusable component.
  
  
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
      # ASSUME: all arguments should be objects that implement the desired semantics of a state machine state. not exactly sure what that means rigorously, so can't perform error checking.
      @states = args
    end
    
    def initial_state(state_class)
      if @states.empty?
        raise "ERROR: Must first declare all possible states using #define_states. Then, you can specify one of those states to be the initial state, by providing the class of that state object."
      end
      
      unless state_defined? state_class
        raise "ERROR: '#{state_class.to_s}' is not one of the available states declared using #define_states. Valid states are: #{ @states.map{|x| x.class.to_s} }"
      end
      
      @initial_state = find_state(state_class)
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
                 state_defined? state_class
          )
            raise "ERROR: State transition was not defined correctly. Given '#{state_class.to_s}', but expected either one of the states declared using #define_states, or the symbols :any or :any_other, which specify sets of states. Defined states are: #{ @states.map{|x| x.class.to_s} }"
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
  
  # return the first state object which is a subclass of the given class
  def find_state(state_class)
    return @states.find{|x| x.is_a? state_class }
  end
  
  # returns true if @states contains an object of the specified class
  def state_defined?(state_class)
    return find_state(state_class) != nil
  end
end

# class DefaultState
#   def initialize(state_machine, transport, context)
#     @state_machine = state_machine
#     @transport = transport
#     @context = context
#   end
# end

     
# states used by state machine defined below
# ---
# should we generate new state from code or replay old state from the buffer?
# that depends on the current system state, so let's use a state machine.
# + next       advance the system forward by 1 frame
# + seek       jump to an arbitrary frame
module States
  class Initial < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine)
      @state_machine = state_machine
    end
    
    # called every time we enter this state
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
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, save_helper)
      @state_machine = state_machine
      @context = shared_data
      @save_helper = save_helper
      
      @f1 = nil
      @f2 = nil
    end
    
    # called every time we enter this state
    def on_enter
      @f1 = nil
      @f2 = nil
    end
    
    # step forward one frame
    def next
      @f2 ||= Fiber.new do
        # This Fiber wraps the block so we can resume where we left off
        # after Helper pauses execution
        @context.block.call(@save_helper)
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
        @state_machine.transition_to Finished
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      
    end
  end
  
  class ReplayingOld < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, transport, load_helper)
      @state_machine = state_machine
      @context = shared_data
      @transport = transport
      @load_helper = load_helper
    end
    
    # called every time we enter this state
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
        @load_helper.load_state_at_current_frame
        
        # stay in state ReplayingOld
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @context.final_frame) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @context.frame_index = frame_number
        @load_helper.load_state_at_current_frame
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @context.final_frame
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @context.frame_index = @context.final_frame
        @load_helper.load_state_at_current_frame
        
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
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, transport, load_helper)
      @state_machine = state_machine
      @context = shared_data
      @transport = transport
      @load_helper = load_helper
    end
    
    # called every time we enter this state
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
        @transport.seek(frame_number)
        
      end
    end
  end
end





# stores the data for time traveling
class HistoryBuffer
  # attr_reader :state, :buffer
  # protected :state
  # protected :buffer
  
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(mom=nil, slice_range=nil)
    if mom
      @max_num_frames = mom.max_num_frames
      self.setup(mom.state[:pixels],
                 mom.state[:texture],
                 mom.state[:cache]
      )
      slice_range.each do |i|
        @buffer[i].copy_from mom.buffer[i]
      end
    else
      @max_num_frames = 0
      @buffer = []
      @valid = []
    end
      
      # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
  end
  
  # TODO: remove @state and related variables from HistoryBuffer. should only be a storage data structure for a sequence of images over time. should not know anything about the specifics of the vertext animation texture system.
  def setup(buffer_length:3600, frame_width:9, frame_height:100)
    puts "[ #{self.class} ]  setup "
    
    @max_num_frames = buffer_length
    
    # # retain key data objects for entity state
    # @state = {
    #   :pixels => pixels,
    #   :texture => texture,
    #   :cache => cache
    # }
    
    # store data
    @buffer = Array.new(@max_num_frames)
    @buffer.size.times do |i|
      pixels = RubyOF::FloatPixels.new
      
      pixels.allocate(frame_width, frame_height)
      pixels.flip_vertical
      
      @buffer[i] = pixels
    end
    
    # create array of booleans to know which images store valid states
    @valid = Array.new(@buffer.size, false)
  end
  
  def length
    return @max_num_frames
  end
  
  alias :size :length
  
  def frame_width
    @buffer[0].width
  end
  
  def frame_height
    @buffer[0].height
  end
  
  # read from buffer
  def [](frame_index)
    raise IndexError, "Index should be a non-negative integer. (Given #{frame_index.inspect} instead.)" if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside the bounds of recorded frames: 0..#{self.length-1}" unless frame_index.between?(0, self.length-1)
    
    raise "Attempted to read garbage state. State at frame #{frame_index} was either never saved, or has since been deleted." unless @valid[frame_index]
    
    return @buffer[frame_index]
  end
  
  # save to buffer
  def []=(frame_index, data)
    raise IndexError, "Index should be a non-negative integer." if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{self.length-1}" unless frame_index.between?(0, self.length-1)
    
    data_size   = [data.width, data.height]
    buffer_size = [self.frame_width, self.frame_height]
    raise "Dimensions of provided frame data do not match the size of frames in the buffer. Provided: #{data_size.inspect}; Buffer size: #{buffer_size.inspect}" unless data_size == buffer_size
    
    @buffer[frame_index].copy_from data
    @valid[frame_index] = true
  end
  
  # delete data at index
  def delete(frame_index)
    @valid[frame_index] = false
  end
  
  # TODO: consider storing the current frame_count here, to have a more natural interface built around #<< / #push
  # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
  
  
  # # TODO: implement this new interface
  # @buffer[frame_index] << @state[:pixels] # save data into history buffer
  # @buffer[frame_index] >> @state[:pixels] # load data from buffer into another image
  #   # + should I implement this on RubyOF::Pixels for all images?
  #   # + can this be patterned as a general "memory transfer operator" ?
    
  # @state[:pixels] << @buffer[frame_index] # load data from buffer into another image
  
  
  # image buffers are guaranteed to be the right size,
  # (as long as the buffer is allocated)
  # because of setup()
  
  
end
  # FIXME: recieving index -1
  # (should I interpret that as distance from the end of the buffer, or what? need to look into the other code on the critical path to figure this out)
  
  
  
  # OpenFrameworks documentation
    # use ofPixels::pasteInto(ofPixels &dst, size_t x, size_t y)
    # 
    # "Paste the ofPixels object into another ofPixels object at the specified index, copying data from the ofPixels that the method is being called on to the ofPixels object at &dst. If the data being copied doesn't fit into the destination then the image is cropped."
    
  
    # cropTo(...)
    # void ofPixels::cropTo(ofPixels &toPix, size_t x, size_t y, size_t width, size_t height)

    # This crops the pixels into the ofPixels reference passed in by toPix. at the x and y and with the new width and height. As a word of caution this reallocates memory and can be a bit expensive if done a lot.




end
