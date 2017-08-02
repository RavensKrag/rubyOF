class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("Boilerplate App", 1746,1374)
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		@p_history = Array.new
		@trail_dt = 1
		
		
	end
	
	def setup
		super()
		
		x = 30
		puts "Ruby data: #{x}"
		
		out = RubyOF::CPP_Callbacks.simple_callback x
		puts "Ruby -> roundtrip from C++"
		puts out
		
		
		
		puts "-----"
		puts "ruby roundtrip: array test"
		x = [1,2,3,4]
		puts "Ruby data: #{x}"
		
		out = RubyOF::CPP_Callbacks.array_callback x
		puts "Ruby -> roundtrip from C++"
		puts out
	end
	
	def update
		super()
		
		
	end
	
	def draw
		super()
		
		
	end
	
	def on_exit
		super()
	end
	
	
	
	
	def key_pressed(key)
		super(key)
		
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
		super(key)
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
		
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
	end
	
	
	
	private
	
	def draw_debug_info(start_position, row_spacing, z=1)
		[
			"mouse: #{@p.inspect}",
			"window size: #{window_size.to_s}",
			"dt: #{ofGetLastFrameTime.round(5)}",
			"fps: #{ofGetFrameRate.round(5)}",
			"time (uSec): #{RubyOF::Utils.ofGetElapsedTimeMicros}",
			"time (mSec): #{RubyOF::Utils.ofGetElapsedTimeMillis}"
		].each_with_index do |string, i|
			x,y = start_position
			y += i*row_spacing
			
			ofDrawBitmapString(string, x,y,z)
		end
	end
	
	
	def callback_to_cpp(*args)
		p args
			
		vector = args.first
		vector.x = 2
		
		puts "ruby: #{vector}"
		
		return vector
	end
end
