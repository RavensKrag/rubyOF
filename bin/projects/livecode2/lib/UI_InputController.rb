
class UI_InputController
  def initialize(ui_model)
    @ui_model = ui_model
    
    puts "init input control"
  end
  
  def on_reload
  	
  end
  
  def update(hash={})
    # inputs => outputs
    inputs, outputs = parse_args_hash(hash)
    
    input_queue = inputs
    window = outputs
    
    # puts "hello"
    
    
    # getting more than one input per frame,
    # which is good because it means that
    # + OpenFrameworks has evented input
    # + events fire at a higher time resolution than graphical updates
    
    # p input_queue
    input_queue.each do |input_sym, args|
    	# p args
    	self.send input_sym, window, *args
    end
    
    
    # # FIXME: allow for manual step, mulit-step, and continuous execution modes
    # step_mode = :mulitstep
    # frames_per_turn = 10
    
    # case step_mode
    # when :manual # full manual - only step on explict command
    #   # NO-OP
    # when :mulitstep # slow execution - take a turn, then wait some frames
    #   @mulistep_fiber ||= Fiber.new do |frames_per_turn|
    #     framecount = 0
        
    #     # FIXME: update this loop logic - it's not quite right
    #     # (also not sure if I can use Fiber at all - because the turn counter uses Fiber, this would create a situation with nested fibers)
    #     loop do
    #       if framecount == 0
    #         @x.update
    #       end
          
    #       framecount += 1
    #       if framecount % frames_per_turn == 0
    #         framecount = 0
    #       end
          
    #       frames_per_turn = Fiber.yield
    #     end
    #   end
      
    #   @mulistep_fiber.resume
    # when :continuous # full speed - take one turn every frame
    #   @x.update
    # end
    # # # if we're in play mode, advance the core state now
    # # @x.update
    # #   # step space
    # #   # step main code
    
    return self
  end
  
  
  
  
  # == keyboard input ==
  def key_pressed(window, key)
   # puts "key -> #{key}"
   
   # use REPL to explore constants: MAIN_OBJ.class.constants
   # (' ' [spacebar] has no constant, because it creates a printing character)
   
   case key
   when 32
   	puts "pause / play"
    window.timeline_controller.tap do |controller|
     	case window.timeline_controller.execution_state_name
      when :paused
        controller.play
      when :running
        controller.pause
      end
    end
   when OF_KEY_LEFT
   	puts "back"
   	window.timeline_controller.step_back
   when OF_KEY_RIGHT
   	puts "forward"
   	# p window.timeline_controller
   	window.timeline_controller.step_forward
   end
   
  end
  
  
  def key_released(window, key)
   
  end
  
  
  
  # == mouse input ==  
  
  def mouse_moved(window, x,y)
    
  end
  
  def mouse_pressed(window, x,y, button)
    # ofExit() if button == 8
    
    
    # different window systems return different numbers
    # for the 'forward' mouse button:
      # GLFW: 4
      # Glut: 8
    # TODO: set button codes as constants?
    
    # case button
    #   when 1 # middle click
    #     @drag_origin = CP::Vec2.new(x,y)
    #     @camera_origin = @camera.pos.clone
    # end
  end
  
  def mouse_dragged(window, x,y, button)
    # case button
    #   when 1 # middle click
    #     pt = CP::Vec2.new(x,y)
    #     d = (pt - @drag_origin)/@camera.zoom
    #     @camera.pos = d + @camera_origin
    # end
  end
  
  def mouse_released(window, x,y, button)
    # case button
    #   when 1 # middle click
        
    # end
  end
  
  def mouse_scrolled(window, x,y, scrollX, scrollY)
    # zoom_factor = 1.05
    # if scrollY > 0
    #   @camera.zoom *= zoom_factor
    # elsif scrollY < 0
    #   @camera.zoom /= zoom_factor
    # else
      
    # end
    
    # puts "camera zoom: #{@camera.zoom}"
  end
  
  
  private
  
  
  # hash format:
  # inputs => outputs
  def parse_args_hash(hash)
    inputs = hash.keys.first
    outputs = hash.values.first
    
    return inputs, outputs
  end
end
