require 'pathname'

lib_dir = Pathname.new(__FILE__).expand_path.dirname


require lib_dir/'repl'
# defines REPL to manage connection to repl, and two methods:
#    REPL.connect(binding, blocking:false)
#    REPL.disconnect


class TextEntity
	attr_reader :p
	# ^ can edit properties of the vector, but can't set a new object
	
	def initialize(window, font)
		@window = window
		@font = font
		
		
		@p = CP::Vec2.new(200,430)
		
		@color =
			RubyOF::Color.new.tap do |c|
				c.r, c.g, c.b, c.a = [0, 141, 240, 255]
			end
		
	end
	
	def draw
		@window.ofPushStyle()
		@window.ofSetColor(@color)
		
		@font.draw_string("From ruby: こんにちは", @p.x, @p.y)
		
		@window.ofPopStyle()
	end
end

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
		@font.draw_string("From ruby: こんにちは", @p.x, @p.y)
		
		@window.tap do |w|
			w.ofPushStyle()
			w.ofSetColor(@color)
			
			w.ofDrawCircle(@p.x, @p.y, @z, @r)
			
			w.ofPopStyle()
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
		
		
		@live_code = {
			:update => Array.new,
			:draw   => Array.new
		}
		
		@time = Timer.new
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		
		@text = TextEntity.new(self, @font)
	end
	
	def update
		# super()
		
		@live_code[:update].each do |block|
			block.call
		end
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
		
		
		
		@text.draw
		
		@live_code[:draw].each do |block|
			block.call
		end
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
		@mouse_pos.x = x
		@mouse_pos.y = y
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
end
