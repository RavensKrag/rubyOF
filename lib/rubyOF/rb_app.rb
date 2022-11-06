module RubyOF
  

class RbApp
  attr_reader :width, :height
  attr_reader :opengl_version_major, :opengl_version_minor
  
  attr_reader :window, :app
  
  def initialize(window_size:[100,100], opengl_version:"3.2")
    # set window size
    @width, @height = window_size
    
    # parse OpenGL version string
    gl_version = opengl_version.split('.').map{|x| x.to_i }
    if gl_version.empty? || gl_version.size != 2
      msg = [
        "ERROR: Could not parse opengl version string.",
        "Keyword parameter opengl_version: was specified as #{opengl_version.inspect}. Expected a number like '3.2', encoded as a string, with a single dot between the major version and the minor version. Please correct the version number and try again."
      ]
      
      raise ArgumentError, msg.join("\n")
    end
    @opengl_version_major, @opengl_version_minor = gl_version
  end
  
  # called when Launcher is initialized
  def bind(window_ptr, app_ptr)
    @window = window_ptr
    @app = app_ptr
  end
  
  # called before app starts to execute
  def setup()
    
  end
  
  def update
    puts "ruby: Window#update (RubyOF default)"
  end
  
  def draw
    puts "ruby: Window#draw (RubyOF default)"
  end
  
  # NOTE: this method can not be called 'exit' because there is a method Kernel.exit
  def on_exit
    puts "ruby: exiting application... (RubyOF default)"
  end
  
  
  def key_pressed(key)
    p [:pressed, key]
  end
  
  def key_released(key)
    p [:released, key]
  end
  
  
  def mouse_moved(x,y)
    p "mouse position: #{[x,y]}.inspect"
  end
  
  def mouse_pressed(x,y, button)
    p [:pressed, x,y, button]
  end
  
  def mouse_released(x,y, button)
    p [:released, x,y, button]
  end
  
  def mouse_dragged(x,y, button)
    p [:dragged, x,y, button]
  end
  
  
  def mouse_entered(x,y)
    p [:mouse_in, x,y]
  end
  
  def mouse_exited(x,y)
    p [:mouse_out, x,y]
  end
  
  
  def mouse_scrolled(x,y, scrollX, scrollY)
    p [:mouse_scrolled, x,y, scrollX, scrollY]
  end
  
  
  def window_resized(w,h)
    p [:resize, w,h]
  end
  
  def drag_event(files, position)
    p [files, position]
  end
  
  def got_message()
    # NOTE: not currently bound
  end
  
end


end
