
# TODO: rename things so this project doesn't have symbol collision with the other package I named "Oni", from which this project's template derives.
	
# TODO: wrap functions to get window dimensions
# TODO: consider marking all drawing methods as private from Ruby-land

# TODO: when Ruby code throws an exception, supress the exception, trigger proper C++ shutdown, and then throw the exception again. Otherwise, you get segfaults, leaking, etc.


# TODO: wrap basic texture mapping features
# TODO: LATER use use of the batching sprite rendering extensions, wrapping that in Ruby, to draw images
# TODO: wrap batching draw call API so you don't have to lean so hard to the immediate mode stuff




# Interface to linux shell command fc-list
# Shows the available fonts on the system,
# and provides an interface for searching through them.
class FontDB
	def initialize
		# TODO: consider using another method of invoking shell, as this may be mangling some right-to-left language output (unsure what language)
		fonts_data = `fc-list`
		# p fonts_data.lines
		
		@available_fonts = 
			fonts_data.lines                      # split into lines
			          .collect{ |x| x.chomp }     # remove trailing newlines
			          .collect{ |x|
			             x.split(':')             # : separated list (3 sections?)
			              .collect{ |y| y.strip } # remove extra whitespace
			          }
			          .collect{ |path, names, *other|
			             # parts[0]     # path
			             # parts[1]     # names       (list of strings)
			             # parts[2..-1] # other keys  (KEY=v1,v2,v3)
			             
			             # out = {:path => "", :names => [], :style => [], etc }
			             
			             out = Hash.new
			             
			             # path
			             out[:path] = path
			             
			             # name(s)
			             out[:names] = names.split(',').collect{ |x| x.strip }
			             
			             # other keys
			             other.each do |data|
			             	parts = data.split("=")
			             	k, v = parts
			             	
			             	k = k.to_sym
			             	v = v.split(',')
			             	
			             	out[k] = v
			             end
			             
			             
			             
			             # pseudo return
			             out
			          }
		
		# require 'yaml'
		# puts @available_fonts.to_yaml
	end
	
	
	def find_by_name(name)
		@available_fonts.select do |record|
			record[:names].any?{ |x| x.include? name }
		end
	end
	
	
	def find_by_style(style)
		
	end
	
	alias :find_by_weight :find_by_style
	
	
	
	# TODO: need a way of viewing fonts by their "full name"
	# ex) DejaVu Sans mono book (name="DejaVu Sans", style=mono and book)
	def list(verbose=true)
		if verbose
			# full names
			@available_fonts.collect{ |x|
				styles = x[:style]
				
				foo = 
					if styles.nil? or styles.empty?
						x[:names]
					else
						x[:names].zip(styles)
					end
				
				foo.collect{ |y| y.join(' ') }
			}.flatten.uniq.sort!
			# TODO: maybe you want to omit the "Regular" part?
			# TODO: maybe the key should be "styles" (with an s (currently no s))
		else
			# short names
			@available_fonts.collect{|x| x[:names]}.flatten.uniq
		end
	end
end


# This extension to the base font class allows you
# to read the name off the font object,
# without having to keep the settings object alive.
# All other properties of the font can be read
# through the font object, but not the name.
# It appears that the name is not even being set
# as a member variable on the font object.

# TODO: file bug report for ofTrueTypeFont, stating that name can not be retrieved from the font object, only the settings object.
class Font < RubyOF::TrueTypeFont
	def load(settings)
		@name = settings.font_name
		super(settings)
	end
	
	# Return the font name as specified by the settings object
	# (in some cases, this may actually be the full path to the font file)
	# 
	# (Currently, this is the indentifier of the font file, and not actually the 'name' of the font face.)
	def name
		raise "ERROR: Font not yet loaded." if @name.nil?
		# ^ @name not set until #load() is called.
		
		return @name
	end
	# NOTE: no setter for this value, because you can't change the font face once the font object is loaded. (have to switch objects)
	
	
	
	# Create easy gemfile-style DSL for loading font parameters,
	# including error checking.
	def dsl_load # &block
		config = DSL_Object.new
		
		yield config
		
		
		font = self.class.new
		font_settings = RubyOF::TtfSettings.new(config.path, config.size)
		
		config.alphabets.each do |x|
			font_settings.add_alphabet x
		end
		
		
		load_status = font.load(font_settings)
		raise "Could not load font" unless load_status
		
		return font
	end
	
	class DSL_Object
		attr_reader :alphabets
		attr_accessor :path, :size, :antialiased
		
		def initialize
			@alphabets = Array.new
		end
		
		def add_alphabet(alphabet)
			alphabet_list = RubyOF::TtfSettings::UnicodeAlphabets
			unless alphabet_list.include? alphabet
				message = [
					"Alphabet '#{alphabet}' is not one of the supported values.",
					"Use a value from TtfSettings::UnicodeAlphabets",
					"Try one of these: #{alphabet_list.inspect}"
				].join("\n")
				
				raise message
			end
			
			@alphabets << alphabet
		end
	end
end

class Image < RubyOF::Image
	def dsl_load # &block
		# pass config DSL object to block
		config = DSL_Object.new
		
		yield config
		
		# establish real objects
		image    = self.class.new
		settings = RubyOF::ImageLoadSettings.new
		
		# convert config -> settings
		# NOTE: initialized values of ImageLoadSettings are the defaults
		path = config.path
		
		settings.accurate     = config.accurate?
		settings.exifRotate   = config.exifRotate?
		settings.grayscale    = config.grayscale?
		settings.separateCMYK = config.separateCMYK?
		
		
		# load using settings
		load_status = image.load(path, settings)
		raise "Could not load image" unless load_status
		
		return image
	end
	
	class DSL_Object
		attr_accessor :path
		
		def initialize
			
		end
		
		
		# create methods like:
			# enable_accurate
			# disable_accurate
		# rather than letting the user set arbirary values to these flags
		# (they should only ever be booleans)
		flags = [
			:accurate,
			:exifRotate,
			:grayscale,
			:separateCMYK
		]
		
		
		# TODO: abstract the following into a metaprogramming method 'boolean_attr_accessors' or similar
		
		
		# establish new mutation interface
		# ex) enable_accurate / disable_accurate (for variable @accurate)
		[:enable, :disable].zip(flags)
		.each do |en_or_dis_able, flag_name|
			if en_or_dis_able == :enable
				define_method "#{en_or_dis_able}_#{flag_name}" do
					self.instance_variable_set "@#{flag_name}", true
				end			
			else # assuming ':disable'
				define_method "#{en_or_dis_able}_#{flag_name}" do
					self.instance_variable_set "@#{flag_name}", false
				end
			end
		end
		
		# establish new accessor interface
		# ex) accurate? (for variable @accurate)
		flags.each do |flag_name|
			define_method "#{flag_name}?" do
				self.instance_variable_get "@#{flag_name}"
			end
		end
		
	end
end

class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("Test App", 1746,1374)
		# ofSetEscapeQuitsApp false
		
		# ofSetVerticalSync(true)
			# NOTE: my current linux app forces vsync on all apps, including OpenFrameworks, regaurdless of whether this is set or not.
			# 
			# kubuntu xenial 16.04.3 LTS (64 bit)
			# KDE plasma 5.8.7
			# kernel 4.4.0-89-generic
			# X.Org X Server 1.18.4

		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		@p_history = Array.new
		@trail_dt = 1
		
		
	end
	
	def setup
		super()
		
		
		# --- things to test in the example / template ---
		# (already bound)
		# font          x
		# font bb       _
		# time          x
		# fbo           x
		# image         x
		# texture       _
		# pixels        _
		# Color         x
		# ofSetColor    x
		# position      _ 
		# + basic shapes   
		#    circle     x
		#    rectangle  _
		
		# (not bound yet)
		# line drawing  _
		# bezier curve  _
		# ----------
		
		
		
		# p @font.methods
		@font_db = FontDB.new
			# require 'irb'
			# binding.irb
		# p @font_db.list(true)
		
		
		# @font_db.find_by_name("DejaVu Sans Mono")
		
		
		# .find_by_name("DejaVu Sans Mono")
		# 
		# .path
		
		
		@font = 
			Font.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		
		
		# @image.load("box.jpg")
		# # NOTE: #load overwrites the default private method #load, which seems to be present on all Ruby objects (likely Kernel.load(), but unsure)
		
		@image =
			Image.new.dsl_load do |x|
				x.path = "box.jpg"
				# x.enable_accurate
				# x.enable_exifRotate
				# x.enable_grayscale
				# x.enable_separateCMYK
			end
		
		
		# @texture = RubyOF::Texture.new
		# ofLoadImage(@texture, "/home/ravenskrag/Pictures/Buddy Icons/100shinn1.png")
		
		
		
		# NOTE: fbo test is in the #draw callback
		
	end
	
	def update
		# super()
		@tick ||= 0
		@tick += 1
		if @tick == @trail_dt
			@tick = 0
			
			@p_history << @p
		end
		
		trail_length = 20*3*2
		# if @tick == 30
		# 	@p_history.shift
		# end
		
		if @p_history.length > trail_length
			i = [0, @p_history.length - trail_length - 1].max
			@p_history.shift(i)
		end
		
		# p @p_history
	end
	
	def draw
		super()
		
		# NOTE: background color should be set from C++ level, because C++ level code executes first. May consider flipping the order, or even defining TWO callbacks to Ruby.
		# ofBackground(171, 160, 228,   255) # rgba
		z = 1
		
		# === Render debug info
		ofPushMatrix()
		ofPushStyle()
			
			# This style of specifying color means that you can specify the color channels in whatever order you please. The system will still use a standard internal representation.
			c = RubyOF::Color.new
			c.r, c.g, c.b, c.a = [171, 160, 228, 255]
			ofSetColor(c)
			
			start = [12, 15]
			row_spacing = 15
			
			
			# s = 5
			# ofScale(s,s,1)
			# NOTE: scaling does not effect size of ofDrawBitmapString
			# (ofDrawBitmapString is used by draw_debug_info)
			draw_debug_info(start, row_spacing, z)
		
		ofPopStyle()
		ofPopMatrix()
		
		# c = RubyOF::Color.new
		# c.r, c.g, c.b, c.a = [255, 255, 255, 255]
		# ofSetColor(c)
		
		# === Render mouse trail
		ofPushStyle()
			
			@p_history.reverse_each.each_with_index do |p, i|
				next unless i % 3 == 0
				
				x,y = p
				
				# Allocate one color object, and just change the alpha
				if @mouse_trail_color.nil?
					@mouse_trail_color = RubyOF::Color.new.tap do |c|
						c.r, c.g, c.b, c.a = [255,0,0, 255]
					end
				end
				@mouse_trail_color.a = 255-i*10
				ofSetColor(@mouse_trail_color)
				
				r = 20-i/2
				r = 0 if r < 0
				ofDrawCircle(x,y,z, r)
			end
			
		ofPopStyle()
		
		
		
		# === Draw Unicode string with Japanese glyphs
		ofPushStyle()
		c = RubyOF::Color.new
		c.r, c.g, c.b, c.a = [0, 141, 240, 255]
		ofSetColor(c)
		
		x,y = [200,430]
			# not sure why, but need to get variables again?
			# if you don't, the text trails behind the desired position by a couple seconds.
		@font.draw_string("From ruby: こんにちは", x, y)
		# puts "こんにちは"
		ofPopStyle()
		
		
		
		# === Draw sample image
		ofPushStyle()
			c = RubyOF::Color.new
			c.r, c.g, c.b, c.a = [0, 141, 240, 255]
			# puts c
			ofSetColor(c)
			
			x,y = [180, 600]
			
			text = [
				"Two test images",
				"(Small one: ruby.` Big one: c++)"
			].join("\n")
			@font.draw_string(text, x,y)
		ofPopStyle()
		
		
		ofPushStyle()
		ofPushMatrix()
			# need to make sure color is set to white (default)
			# before drawing images, otherwise image will be tinted.
			ofTranslate(200,700, 0)
			
			s = 0.5
			ofScale(s,s,1)
			
			@image.draw(0,0, z)
		ofPopMatrix()
		ofPopStyle()
		
		# # x = y = 300
		# width = height = 100
		# @texture.draw_wh(
		# 	x,y,	z,
		# 	width, height
		# )
		
		
		# === Test exception handling
		# raise "BOOM!"
		
		
		# === FBO test
		if @fbo.nil?
			@fbo = RubyOF::Fbo.new
			
			settings = RubyOF::Fbo::Settings.new
			settings.width     = self.width
			settings.height    = self.height
			settings.minFilter = GL::GL_NEAREST
			settings.maxFilter = GL::GL_NEAREST
			# ^ just set the width and height to match that of the window,
			#   at least for now.
			
			@fbo.allocate(settings)
			# TODO: create DSL for Fbo#allocate like with Font and Image
			
			
			
			@fbo.begin()
				# need to clear the buffer, or you get whatever garbage is in there
				ofClear(0,0,0,0)
				
				# render some things into the fbo here
				# (rendering relative to the orign of the FBO, which moves)
				ofPushStyle()
				ofPushMatrix()
					c = RubyOF::Color.new
					c.r, c.g, c.b, c.a = [0, 141, 240, 255]
					ofSetColor(c)
					
					ofDrawBitmapString("ruby: FBO test", 0, 10, z);
					ofDrawBitmapString("hello again from ruby!", 0, 100, z);
					ofDrawBitmapString("many things!", 20, 200, z);
					ofDrawBitmapString("so many things", 144, 38, z);
				ofPopMatrix()
				ofPopStyle()
			@fbo.end()
			
			# NOTE:
				# Apparently #bind and #unbind are more low level,
				# and are used for "vertex based drawing"
				# where as when using openFramework's higher-level stuff,
				# you want to use #begin / #end
				# 
				# src: http://openframeworks.cc/documentation/gl/ofFbo/#show_bind
		end
		
		
		@fbo.draw(500,1000)
		
		
		# === Various
		ofPushStyle()
			
			# ofDrawBitmapString("hello again from ruby!", 300, 350, z);
			# ofDrawBitmapString("clipboard: #{self.clipboard_string.inspect}", 100, 400, z);
			# ^ NOTE: I think this gives you an error when the contains something that is not a string?
			# [ error ] ofAppGLFWWindow: 65545: X11: Failed to convert selection to string
			
			c = RubyOF::Color.new
			c.r, c.g, c.b, c.a = [255,0,0, 255]
			ofSetColor(c)
			# ofDrawCircle(*@p,z, 20)
			
		ofPopStyle()
		
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
		
		
		
		if button == 7
			# --- test Point class (wraps ofPoint, which is an alias for ofVec3f)
			point = RubyOF::Point.new(200, 200, 0)
			puts point
			puts point.x
			
				point.x = 100
				
			puts point.x
			puts point
			
			
			# self.set_window_position(200, 200) 
			
			
			
			# --- toggle cursor visibility
			@cursor_visible = true if @cursor_visible.nil?
			p @cursor_visible
			if @cursor_visible
				hide_cursor
			else
				show_cursor
			end
				
			@cursor_visible = !@cursor_visible
		elsif button == 5
			self.clipboard_string = "hello world"
		end
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
