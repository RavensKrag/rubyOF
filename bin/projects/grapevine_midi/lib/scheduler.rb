
# TODO: can't use block style, because that prevents local variables from passing from block to block. Try using Fiber instead, with 'checkpoints' (just initial lines, not do-end blocks) to block execution at certain points while waiting to be scheduled

class Scheduler
  
  class SchedulerHelper
    attr_reader :data
    
    def initialize
      @data = nil # at any point, can be nil or Array
    end
    
    
    # block until the scheduler has enough time to run the specified section
    # (the 'section' is just the code that follows - no block given to method)
    # 
    # need to measure time between calls to this function
    def section(name:, budget:)
      
      # pass data to outside world
      @data = [name, budget]
      
      # block until section can be scheduled
      Fiber.yield(name, budget)
      
      # clear the data, so it doesn't linger around to the next call
      @data = nil
      
    end
  end
  
  
  
  # NOTE: Matz favors loop{ break if <cond> } over 
  #       'begin <code> end while <cond>' for clarity 
  #       (unclear that it is different from '<code> while <cond>'')
  # 
  # src: https://stackoverflow.com/questions/136793/is-there-a-do-while-loop-in-ruby
  
  # DEBUG = true
  DEBUG = false
  
  attr_accessor :section_count
  attr_reader :total_time
  
  
  MAX_NUM_SECTIONS = 32
  
  def initialize(outer, callback_method_name, frame_deadline_us)
    @callback_name = callback_method_name
    @outer = outer
    
    @total_time_per_frame = frame_deadline_us
    @time_used_this_frame = 0
    @total_time = 0 # visualize 'time_used_this_frame, from the previous iteration'
    
    @section_count = 1
    @first_loop_complete = false
    @helper = SchedulerHelper.new
    
    # step through sections of the inner block
    @f2 = Fiber.new do
      
      loop do
        
        @outer.send(@callback_name, @helper)
        # ^ helper calls Fiber.yield at key points in the callback
        
        # TODO: need to call Fiber.yield once more at the end of the method before looping in order to correctly time the final block
        
      end
      
    end
    
    
    # loop through all sections
    @f1 = Fiber.new do
      # loop through the callbacks, scheduling them
      # in the order they were declared order, ad infinitum
      
      @i = 0
      @f2.resume() # step the Fiber forward until the first time it blocks
      
      while @f2.alive? # @f2 contains an infinite loop, so should live forever
        
        # 
        # schedule sections
        # 
        
        # get info from section...
        section_name, time_budget = @helper.data
        p [ section_name, time_budget ] if Scheduler::DEBUG
        
        # ...and block until you have enough time
        # (return control to main Fiber to forfeit remaining time)
        if @time_used_this_frame + time_budget >= @total_time_per_frame
          puts "block"
          Fiber.yield :time_limit_reached # return control to main Fiber 
          @time_used_this_frame = 0
        end
        
        # If there's enough time left this frame,
        # then unblock Fiber @f2 and execute the section
        puts "running update #{section_name}"
        
        timer_start = RubyOF::Utils.ofGetElapsedTimeMicros
        
          @f2.resume()
        
        timer_end = RubyOF::Utils.ofGetElapsedTimeMicros
        dt = timer_end - timer_start # TODO: account for timer looping
        
        
        # advance the timer
        @time_used_this_frame += dt
        # ^ increment by time budgeted, not time actually spent
        #   this way gives more scheduling control to the programmer
        
        puts "time budget: #{(@time_used_this_frame.to_f / @total_time_per_frame).round(3)} (+ #{dt} us )" if Scheduler::DEBUG
        
        
        
        # 
        # save time data for later visualization
        # 
        save_time_data(@i, section_name, time_budget, dt)
        @i += 1
        
        # 
        # on the first iteration of the loop,
        # count up the number of sections
        # 
        unless @first_loop_complete
          @section_count += 1
        end
        
        # 
        # enforce limit on number of sections
        # 
        
        if @section_count > MAX_NUM_SECTIONS
          raise "ERROR: too many sections declared for scheduler. Maximum is #{MAX_NUM_SECTIONS}, as defined in #{__FILE__}"
        end
        
        
        # 
        # if you're executed all sections, wait until
        # the next frame to run additional updates
        # (want to limit the number of possible interleavings)
        # 
        if section_name == "end"
          @first_loop_complete = true
          
          
          puts "total time: #{@time_used_this_frame}"
          @total_time = @time_used_this_frame
          
          Fiber.yield :time_limit_reached # return control to main Fiber
          @time_used_this_frame = 0
          
          @i = 0
        end
        
        
        
        
        # Fiber.yield :end_of_loop
        # # ^ this doesn't work as expected.
        # #   hitting this line after every section
      end
    end
    
  end
  
  # NOTE: The entire scheduler is refreshed when new code is live loaded
  
  def resume
    
    return @f1.resume()
    # ^ either :end_of_loop or :time_limit_reached
    
  end
  
  
  
  
  
  
  def performance_log
    return @log_old
  end
  
  attr_reader :time_log
  attr_reader :budgets
  attr_reader :sample_count
  
  private
  
  def save_time_data(i, section_name, time_budget, dt)
    @log_new ||= Array.new(MAX_NUM_SECTIONS)
    @sample_count ||= 1
    
    
    # save double-buffered data
    # 
    # current buffer for the frame being executed
    # and previous buffer for the previous frame.
    # Statistics are always based on the previous frame,
    # as that is the most recent frame for which we have full data.
    
    @log_new[i] = [section_name, time_budget, dt]
    
    
    if section_name == "end"
      @log_old = @log_new
      @log_new = nil
      
      @sample_count += 1
    end
    
    
  end
  
end

