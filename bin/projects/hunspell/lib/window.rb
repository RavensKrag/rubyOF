class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("Hunspell test", 1746,1374)
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
	end
	
	def setup
		super()
		
		@p = [0,0]
		
		@start_position = [40, 30]
		
		
		
		# The size of the characters in the oF bitmap font is
		# height 11 px
		# width : 8 px
		@debug = {
			:position    => [40, 30],
			:z           => 1,
			:row_spacing => (11 + 4)
		}
		
		
		# This is a basic test of the hunspell gem
		# (requires hunspell-dev package to be installed)
		require 'hunspell'
		# testing using version 0.1.6 of the gem
		# (ubuntu 16.04.3, hunspell-dev 1.3.3)
		hs = Hunspell.new "/usr/share/hunspell/en_US.aff", "/usr/share/hunspell/en_US.dic"
		hs.spellcheck "testing"
		#  => true 
		hs.suggest "testing"
		# => ["setting", "testing", "resting", "testings", "tasting", "tenting", "nesting", "besting", "vesting", "westing", "zesting", "testiness", "dusting"] 
		hs.encoding
		# => ISO8859-1
		
		# NOTE: Hunspell gem supports older versions of hunspell (c-style strings) and newer versions (std::string) but I'm not exactly sure how (I know it checks the version number.) Hasn't been updated in some time (Dec 23, 2016) but supports hunspell 1.6 (ubuntu 17.10 plans on using hunspell 1.6.1. So it seems like new updates to the main library are slow anyway.)
		# source: https://github.com/segabor/Hunspell/
		
		
		# NOTE: Hunspell has korean support, but not Japanese or Chinese support. This is partially because Japanese / Chinese don't use spaces to split out words, which makes Hunspell's "word by word" approach complicated.
			# "Therefore, only if you can parse the text in such way, might Hunspell be suitable. You can also have a look at LanguageTool, it has already support for Chinese and Japanese."
				# PanderMusubi commented on Jun 19, 2017
		# source: https://github.com/hunspell/hunspell/issues/502

		
		
		# The code below uses the custom Hunspell wrapper I wrote
		# (which no one should ever use, because the existing gem is better)
		@word = "testing"  # correct - renders light purple
		@word = "testonth" # wrong - renders bright angry red
		
		
		
		
		@hs = RubyOF::CPP_Callbacks::Hunspell.new("/usr/share/hunspell/en_US.aff", "/usr/share/hunspell/en_US.dic")
		
		@check = @hs.spell_check @word
		p @check
		
		@color = RubyOF::Color.new
			if @check.nil?
				# correct spelling
				@color.tap do |c|
					c.r, c.g, c.b = [171, 160, 228] 
				end
			else
				# spelling error
				@color.tap do |c|
					c.r, c.g, c.b = [255,   0,   0] 
				end
			end
		
		
		@hs = RubyOF::CPP_Callbacks::Hunspell.new("/usr/share/hunspell/en_US.aff", "/usr/share/hunspell/en_US.dic")
	end
	
	def update
		super()
		
		
	end
	
	def draw
		super()
		
		
		draw_debug_info(@debug[:position], @debug[:row_spacing], @debug[:z])
		
		
		# TODO: improve symbols that are passed to clang / files where autocomplete triggers (it's not triggering on .rb, which is good, but because of how I have projects set up, I think it might be possible to not get completion on certain projects? maybe only the cpp_wrapper code has completion? need to check it out, and fix whatever is broken)
		
		
		
		ofPushMatrix()
		ofPushStyle()
			ofSetColor(@color) # rgba
			
			string = @word
			p = [500,120,0]
			ofDrawBitmapString(string, *p)
			
			unless @check.nil?
				@check.each_with_index do |suggestion, i|
					string = suggestion
					p = [500,120+30+(20*(i+1)),0]
					ofDrawBitmapString(string, *p)
				end
				
			end
			
		
		ofPopStyle()
		ofPopMatrix()
		
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
		@p = [x,y]
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
