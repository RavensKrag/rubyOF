
# TODO: can't use block style, because that prevents local variables from passing from block to block. Try using Fiber instead, with 'checkpoints' (just initial lines, not do-end blocks) to block execution at certain points while waiting to be scheduled

class Scheduler_v2
  
  class SchedulerHelper
    
    
    
    # block until the scheduler has enough time to run the specified section
    # (the 'section' is just the code that follows - no block given to method)
    # 
    # need to measure time between calls to this function
    def section(name:, budget:)
      # TOP:
      # <--- after finished, #section is called again at start of next section
      
      
      # block until section can be scheduled
      loop do
        signal = Fiber.yield(name, budget)
        break if signal == :scheduled
      end
      
    end
  end
  
  
  
  def initialize(outer, callback_method_name, frame_deadline_ms)
    @callback_name = callback_method_name
    @outer = outer
    
    @total_time_per_frame = frame_deadline_ms
    @time_used_this_frame = 0
    
    # step through sections of the inner block
    @f2 = Fiber.new do
      
      helper = SchedulerHelper.new
      
      loop do
        
        @outer.send(@callback_name, helper)
        # ^ helper calls Fiber.yield at key points in the callback
        
        # TODO: need to call Fiber.yield once more at the end of the method before looping in order to correctly time the final block
        
      end
      
    end
    
    
    # loop through all sections
    @f1 = Fiber.new do
      # loop through the callbacks, scheduling them
      # in the order they were declared order, ad infinitum
      
      while @f2.alive? # @f2 contains an infinite loop, so should live forever
        
        # 
        # schedule blocks
        # 
        
        # get section name and budget, and block until you have enough time
        section_name, time_budget_ms = @f2.resume()
        p [ section_name, time_budget_ms ]
        
        loop do
          if @time_used_this_frame + time_budget_ms < @total_time_per_frame
            # we have the time. go ahead and run this task.
            
            break
          else
            # return control to main Fiber
            # and 'sleep' until the next frame
            
            puts "block"
            Fiber.yield :time_limit_reached # return control to main Fiber 
            @time_used_this_frame = 0
          end
        end
        
        # NOTE: Matz favors loop{ break if <cond> } over 
        #       'begin <code> end while <cond>' for clarity 
        #       (unclear that it is different from '<code> while <cond>'')
        # 
        # src: https://stackoverflow.com/questions/136793/is-there-a-do-while-loop-in-ruby
        
        
        
        
        puts "running update #{section_name}"
        
        timer_start = RubyOF::Utils.ofGetElapsedTimeMicros
        
          out = @f2.resume(:scheduled)
          puts "fiber return: #{out}"
          # (why do we need to wake the Fiber twice?)
            # Once to get the info, once to actually run
            # maybe we should use a Fiber local var to pass the info instead?
        
        timer_end = RubyOF::Utils.ofGetElapsedTimeMicros
        dt = timer_end - timer_start # TODO: account for timer looping
        
        
        
        @time_used_this_frame += time_budget_ms
        # ^ increment by time budgeted, not time actually spent
        #   this way gives more scheduling control to the programmer
        
        puts "time budget: #{@time_used_this_frame} / #{@total_time_per_frame} (+ #{dt} )"
        
        
        
        # 
        # save time data for later visualization
        # 
        
        # [ section_name, time_budget_ms, [dt_0, dt_1, dt_2] ]
        
        
        
        
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

