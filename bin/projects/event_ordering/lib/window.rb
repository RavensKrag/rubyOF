require 'fiber'
require 'yaml'

class Window < RubyOF::Window
	PROJECT_DIR = Pathname.new(__FILE__).expand_path.parent.parent
	def initialize
		@window_dimension_save_file = PROJECT_DIR/'bin'/'data'/'window_size.yaml'
		
		window_size = YAML.load_file(@window_dimension_save_file)
		w,h = *window_size
		
		# super("Youtube Subscription Browser", 1853, 1250)
		super("event ordering test", w,h) # half screen
		# super("Youtube Subscription Browser", 2230, 1986) # overlapping w/ editor
		
		# ofSetEscapeQuitsApp false
		
		@i = -1
		puts "init #{@i}"
	end
	
	
	def setup
		super()
		
		@i = 0
		puts "setup #{@i}"
		
	end
	
	def update
		# super()
		@i += 1
		puts "update #{@i}"
	end
	
	def draw
		# super()
		
		puts "draw #{@i}"
	end
	
	def on_exit
		super()
		
		puts "exit"
	end
	
	
	
	
	def key_pressed(key)
		super(key)
		
		begin
			string = 
				if key == 32
					"<space>"
					@i += 1
				elsif key == 13
					"<enter>"
				else
					key.chr
				end
				
			puts string
		rescue RangeError => e
			
		end
		
		puts "pressed #{@i}"
	end
	
	def key_released(key)
		super(key)
		
		@i += 1
		puts "released #{@i}"
	end
	
	
	
	
	
	def mouse_moved(x,y)
	end
	
	def mouse_pressed(x,y, button)
		super(x,y, button)
		
		ofExit() if button == 8
		# different window systems return different numbers
		# for the 'forward' mouse button:
			# GLFW: 4
			# Glut: 8
		# TODO: set button codes as constants?
		
		# case button
		# 	when 1 # middle click
		# 		@drag_origin = CP::Vec2.new(x,y)
		# 		@camera_origin = @camera.pos.clone
		# end
		
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
		
		# case button
		# 	when 1 # middle click
		# 		pt = CP::Vec2.new(x,y)
		# 		d = (pt - @drag_origin)/@camera.zoom
		# 		@camera.pos = d + @camera_origin
		# end
		
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
		
		# case button
		# 	when 1 # middle click
				
		# end
		
	end
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		super(x,y, scrollX, scrollY) # debug print
		
		# zoom_factor = 1.05
		# if scrollY > 0
		# 	@camera.zoom *= zoom_factor
		# elsif scrollY < 0
		# 	@camera.zoom /= zoom_factor
		# else
			
		# end
		
		# puts "camera zoom: #{@camera.zoom}"
		
	end
	
	
	
	# this is for drag-and-drop, not for mouse dragging
	def drag_event(files, position)
		p [files, position]
		
		# 	./lib/main.rb:41:in `show': Unable to convert glm::tvec2<float, (glm::precision)0>* (ArgumentError)
		# from ./lib/main.rb:41:in `<main>'
		
		# the 'position' variable is of an unknown type, leading to a crash
	end
	
	
	# NOTE: regaurdless of if you copy the values over, or copy the color object, the copying slows things down considerably if it is done repetedly. Need to either pass one pointer from c++ side to Ruby side, or need to wrap ofParameter and use ofParameter#makeReferenceTo to ensure that the same data is being used in both places.
	# OR
	# you could use ofParameter#addListener to fire an event only when the value is changed (that could work)
		# May still want to bind ofParameter on the Ruby side, especially if I can find a way to allow for setting event listeners in Ruby.
	# def font_color=(color)
	# 	p color
	# 	# puts color
	# 	# 'r g b a'.split.each do |channel|
	# 	# 	@font_color.send("#{channel}=", color.send(channel))
	# 	# end
	# 	@font_color = color
	# 	@font_color.freeze
	# end
	
	
	# Set parameters from C++ by passing a pointer (technically, a reference),
	# wrapped up in a way that Ruby can understand.
	# 
	# name         name of the parameter being set
	# value_ptr    &data from C++, wrapped up in a Ruby class
	#              (uses the same class wrapper as normal Rice bindings)
	def set_gui_parameter(name, value_ptr)
		value_ptr.freeze
		
		# TODO: delegate core of this method to Loader, and then to the wrapped object inside. Want to be able to controll this dynamically.
		
		case name
			when "color"
				@font_color = value_ptr
			else
				msg = 
				[
					"",
					"Tried to set gui parameter, but I wasn't expecting this name.",
					"method call: set_gui_parameter(name, value_ptr)",
					"name:        #{name.inspect}",
					"value_ptr:   #{value_ptr.inspect}",
					"",
					"NOTE: set_gui_parameter() is often called from C++ code.",
					"      C++ backtrace information is not normally provided.",
					"",
					"NOTE: Sometimes C++ backtrace can be obtained using GDB",
					"      (use 'rake debug' to get a GDB prompt)"
				].join("\n") + "\n\n\n"
				
				raise msg
		end
	end
end
