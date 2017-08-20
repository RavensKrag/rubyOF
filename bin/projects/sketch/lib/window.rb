require 'pathname'

lib_dir = Pathname.new(__FILE__).expand_path.dirname


require lib_dir/'repl'
# defines REPL to manage connection to repl, and two methods:
#    REPL.connect(binding, blocking:false)
#    REPL.disconnect

require lib_dir/'live_coding'/'code_loader'






class Entity
	def initialize
		
	end
end

class Point < Entity
	attr_reader :p
	attr_accessor :z
	attr_accessor :r
	
	def initialize(window)
		@window = window
		
		@color =
			RubyOF::Color.new.tap do |c|
				c.r, c.g, c.b, c.a = [0, 141, 240, 255]
			end
		@p = CP::Vec2.new(0,0)
		@z = 0
		@r = 5
	end
	
	def draw
		@window.tap do |w|
			w.ofPushStyle()
			w.ofSetColor(@color)
			
			w.ofDrawCircle(@p.x, @p.y, @z, @r)
			
			w.ofPopStyle()
		end
	end
end


class TextEntity
	attr_reader :p
	# ^ can edit properties of the vector, but can't set a new object
	#   (mutator defined manually below, so only CP::Vec2 instances can be set)
	
	attr_accessor :string
	
	def initialize(window, font)
		@window = window
		@font = font
		
		
		@p = CP::Vec2.new(0,0)
		
		@color =
			RubyOF::Color.new.tap do |c|
				c.r, c.g, c.b, c.a = [0, 141, 240, 255]
			end
		
		@string = "From ruby: こんにちは"
	end
	
	def draw
		@window.ofPushStyle()
		@window.ofSetColor(@color)
		
		@font.draw_string(@string, @p.x, @p.y)
		
		@window.ofPopStyle()
	end
	
	def p=(vec)
		if vec.is_a? CP::Vec2
			@p = vec
		else
			raise ArgumentError, "Argument of type CP::Vec2 expected. Can't set position of #{self.class} instance to #{vec.class}."
		end
	end
end


class Timer
	def initialize
		
	end
	
	def ms
		RubyOF::Utils.ofGetElapsedTimeMillis
	end
	
	def us
		RubyOF::Utils.ofGetElapsedTimeMicros
	end
end


require 'yaml'

class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("App to sketch out ideas", 1746,1194)
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@mouse_pos = CP::Vec2.new(0,0)
		
	end
	
	def setup
		super()
		
		
		# NOTE: You can still read and print instance variables
		#       from the Window in the main thread from the REPL thread
		REPL.connect(binding)
		
		
		
		# (project root)
		root = Pathname.new(__FILE__).expand_path.dirname.parent
		
		@live_wrapper = LiveCoding::DynamicObject.new(
			self,
			save_directory:   (root/'bin'/'data'),
			dynamic_code_file:(root/'lib'/'live_coding'/'code'/'test.rb'),
			method_contract:  [:serialize, :cleanup, :update, :draw]
		)
		
		@live_wrapper.setup # loads anonymous class, and initializes it
		
		
		@live_code_input = LiveCoding::DynamicObject.new(
			self,
			save_directory:   (root/'bin'/'data'),
			dynamic_code_file:(root/'lib'/'live_coding'/'code'/'input.rb'),
			method_contract:  [
				:serialize, :cleanup, :update, :draw,
				:mouse_moved, :mouse_pressed, :mouse_released, :mouse_dragged
			]
		)
		
		# :mouse_moved(x,y)
		# :mouse_pressed(x,y, button)
		# :mouse_released(x,y, button)
		# :mouse_dragged(x,y, button)
		
		
		
		@live_code_input.setup # loads anonymous class, and initializes it
	end
	
	def update
		# super()
		
		@live_wrapper.update
		@live_code_input.update
	end
	
	def draw
		# super()
		
		
		# The size of the characters in the oF bitmap font is
		# height 11 px
		# width : 8 px
		
		start_position = [40, 30]
		row_spacing    = 11 + 4
		z              = 1
		draw_debug_info(start_position, row_spacing, z)
		
		
		
		@live_wrapper.draw
		@live_code_input.draw
	end
	
	def on_exit
		super()
		
		@live_wrapper.on_exit
		@live_code_input.on_exit
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
		@mouse_pos.x = x
		@mouse_pos.y = y
		
		@live_code_input.mouse_moved(x,y)
	end
	
	def mouse_pressed(x,y, button)
		super(x,y, button)
		
		
		@click_log ||= Array.new
		case button
			when 0 # left
				@click_log << CP::Vec2.new(x,y)
			when 1 # middle
				
			when 2 # right
				
			when 3 # prev (extra mouse button)
					
			when 4 # next (extra mouse button)
				
		end
		
		ofExit() if button == 8
		# different window systems return different numbers
		# for the 'forward' mouse button:
			# GLFW: 4
			# Glut: 8
		# TODO: set button codes as constants?
		
		@live_code_input.mouse_pressed(x,y, button)
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
		@live_code_input.mouse_released(x,y, button)
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
		@live_code_input.mouse_dragged(x,y, button)
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
end
