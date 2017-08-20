# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj
	include LiveCoding::InspectionMixin
	
	def setup(window, save_directory)
		@window = window
		
		# TODO: do something with the save directory
		# (load state)
		
		# NOTE: do NOT save the save_directory in any variables.
		# (have to migrate to using a database as some point, don't want to use a style that means I end up hanging on to closed DB handles)
		
		
		puts "setting up callback object #{self.class.inspect}"
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
				
				# TODO: how do you discover what the alphabets are?
				# stored in RubyOF::TtfSettings::UnicodeRanges
				# maybe provide discoverable access through #alphabets on the DSL object?
			end
			
		@font2 = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
				x.size = 20
				x.add_alphabet :Latin
			end
		
		
		@display   = TextEntity.new(@window, @font2)
		@display.p = CP::Vec2.new 200, 400
		
		@out   = TextEntity.new(@window, @font2)
		@out.p = CP::Vec2.new 200, 420
		
		@text      = TextEntity.new(@window, @font)
		@text.p    = CP::Vec2.new 500, 500
		
		
		
		@time = Timer.new
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		
	end
	
	# reverse all the stateful changes made to @window
	# (basically, undo everything you did across all ticks of #update and #draw)
	# Usually, this is just about deleting the
	# entities you created and put in the space.
	def cleanup
		
	end
	
	# TODO: figure out if there needs to be a "redo" operation as well
	# (easy enough - just save the data in this object instead of full on deleting it. That way, if this object is cleared, the state will be fully gone, but as long as you have this object, you can roll backwards and forwards at will.)
	
	
	def update
		# puts "update"
		
		
		# # --- move text across the screen
		# @text.p.x = 800 * ((@time.ms % 100) / 100.to_f)
		
		# # --- chunk time
		# # example pattern:
		# # 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4
		
		# #                  seconds per frame       number of frames in loop
		# @display.string = (@time.ms / (1.5*1000).to_i % 10 ).to_s
		# #                                ^ sec to ms
		
		
		# COMBINE THE FIRST TWO IDEAS
		# move a changing number across the screen
		
		
		frames_per_loop = 10 # start on frame 0, plus 10 solid frames
		
		#              sec to ms    convert to int so modulo works correctly
		ms_per_frame = (0.2*1000).to_i
		frame_count = (@time.ms / ms_per_frame % (frames_per_loop+1) )
		#                                      ^ here's the modulo
		
		t = frame_count / (frames_per_loop).to_f
		#   |____________________________________|
		#     what percent of the frames have passed?
		#      (3 / 10 frames) -> 30% total distance
		
		
		# Need the numbers in the decretized representation of time
		# to go up to the divisor in the t calculation.
		# That way, t can be (0..1) (float)
		# (otherwise, you can't ever get to 100%)
		
		
		
		# indent      = 100
		# total_range = 800
		
		# @text.p.x = indent + total_range * t
		
		
		
		points = {
			:start => CP::Vec2.new( 131, 455),
			:end   => CP::Vec2.new(1204, 455)
		}
		@text.p = points[:start].lerp points[:end], t
		# p @text.p.x
		
		
		
		# convert frame_count into a string, and display that
		@display.string = "frame_count: " + frame_count.to_s
		@out.string     = "t:           " + t.to_s
	end
	
	def draw
		# aoeu
		# puts "draw"
		
		@display.draw
		@out.draw
		@text.draw
		
		
		# # store clicks from mouse as point data, and process that
		# # @live_code[:draw][0] = ->(){@click_log.each{|o| ofDrawCircle(o.x, o.y, 0, 5) }}
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
	
	
	# # send data to another live coding module in memory
	# # (for planned visual coding graph)
	# # NOTE: Try not to leak state (send immutable data, functional style)
	# def send
	# 	return nil
	# end
	
	# # recive data from another live-coding module in memory
	# # (for planned visual coding graph)
	# def recieve(data)
		
	# end
end; return obj }

