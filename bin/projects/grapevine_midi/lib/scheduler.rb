
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
  
  attr_reader :time_log
  attr_accessor :log_length
  
  def initialize(outer, callback_method_name, frame_deadline_ms)
    @time_log = Array.new
    @log_length = 0 # number of sections to save
    
    @callback_name = callback_method_name
    @outer = outer
    
    @total_time_per_frame = frame_deadline_ms
    @time_used_this_frame = 0
    
    
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
      
      @f2.resume() # step the Fiber forward until the first time it blocks
      
      while @f2.alive? # @f2 contains an infinite loop, so should live forever
        
        # 
        # schedule sections
        # 
        
        # get info from section...
        section_name, time_budget_ms = @helper.data
        p [ section_name, time_budget_ms ]
        
        # ...and block until you have enough time
        # (return control to main Fiber to forfeit remaining time)
        while @time_used_this_frame + time_budget_ms >= @total_time_per_frame
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
        @time_used_this_frame += time_budget_ms
        # ^ increment by time budgeted, not time actually spent
        #   this way gives more scheduling control to the programmer
        
        puts "time budget: #{@time_used_this_frame} / #{@total_time_per_frame} (+ #{dt} )"
        
        
        
        # 
        # save time data for later visualization
        # 
        
        # [ section_name, time_budget_ms, [dt_0, dt_1, dt_2] ]
        @time_log << [ section_name, time_budget_ms, dt ]
        
        # drop old entries if too many data points are being saved
        if @time_log.length > @log_length
          d_len = @time_log.length - @log_length
          @time_log.shift(d_len)
        end
        
        
        # Fiber.yield :end_of_loop
        # # ^ this doesn't work as expected.
        # #   hitting this line after every section
      end
    end
    
  end
  
  def resume
    
    return @f1.resume()
    # ^ either :end_of_loop or :time_limit_reached
    
  end
  
end

