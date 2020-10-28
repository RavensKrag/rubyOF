
class Core_InputController
  def initialize
    
  end
  
  def on_reload
    
  end
  
  def update(hash={})
    # inputs => outputs
    inputs, outputs = parse_args_hash(hash)
    
    input_history = inputs
    window = outputs
    
    return self
  end
  
  
  
  # == keyboard input ==
  def key_pressed(key)
   begin
     string = 
       if key == 32
         "<space>"
       elsif key == 13
         "<enter>"
       else
         key.chr
       end
       
     puts string
   rescue RangeError => e
     
   end
  end
  
  
  def key_released(key)
   
  end
  
  
  
  # == mouse input ==  
  
  def mouse_moved(x,y)
    
  end
  
  def mouse_pressed(x,y, button)
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
  
  def mouse_dragged(x,y, button)
    # case button
    #   when 1 # middle click
    #     pt = CP::Vec2.new(x,y)
    #     d = (pt - @drag_origin)/@camera.zoom
    #     @camera.pos = d + @camera_origin
    # end
  end
  
  def mouse_released(x,y, button)
    # case button
    #   when 1 # middle click
        
    # end
  end
  
  def mouse_scrolled(x,y, scrollX, scrollY)
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

      
