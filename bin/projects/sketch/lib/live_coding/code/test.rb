Class.new do
	include LiveCoding::InspectionMixin
	
	def initialize(window, save_directory)
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
		
		
		@display   = TextEntity.new(@window, @font)
		@display.p = CP::Vec2.new 200, 400
		
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
		
		#                  seconds per frame       number of frames in loop
		frame_count = (@time.ms / (0.8*1000).to_i % 10 )
		#                                ^ sec to ms
		
		#       indent     total range to travel
		#           |       |
		#         |---|  |----|
		@text.p.x = 100 + 800 * frame_count / 10.to_f
		#                       |_____________________|
		#                         10 frames in loop, what percent has passed?
		#                          (3 / 10 frames) -> 30% total distance
		
		# convert frame_count into a string, and display that
		@display.string = frame_count.to_s
		
		
		
		
	end
	
	def draw
		# aoeu
		# puts "draw"
		
		@display.draw
		@text.draw
		# # store clicks from mouse as point data, and process that
		# # @live_code[:draw][0] = ->(){@click_log.each{|o| ofDrawCircle(o.x, o.y, 0, 5) }}
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
end
