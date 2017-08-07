Class.new do
	include LiveCoding::InspectionMixin
	
	def initialize(window, save_directory)
		@window = window
		
		# TODO: do something with the save directory
		# (load state)
		
		# NOTE: do NOT save the save_directory in any variables.
		# (have to migrate to using a database as some point, don't want to use a style that means I end up hanging on to closed DB handles)
		
		
		puts "setting up callback object"
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		
		@text = TextEntity.new(@window, @font)
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
	
	
	
	# # setup additional variables
	# # (will be useful later for constraints)
	# # DEPRECIATED: use initialize instead
	# def bind(save_directory)
		
	# end
	
	# # DEPRECIATED: use initialize instead
	# def setup
		
	# end
	
	
	
	def update
		# puts "update"
		
		@time = Timer.new
		
		
		
		
		# # --- move text across the screen
		# @live_code[:update][0] = ->(){ @text.p.x = 800 * ((@time.ms % 100) / 100.to_f)}
		
		
		# # --- chunk time
		# # example pattern:
		# # 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4
		# # (easy to dump into REPL)
		# @live_code[:update][1] = ->(){ @text.string = (@time.ms / (1.5*1000).to_i % 10 ).to_s }
		
		# # (formatted and documented)
		# @live_code[:update][1] = ->(){ 
		# 	#                  seconds per frame       number of frames in loop
		# 	@text.string = (@time.ms / (1.5*1000).to_i % 10 ).to_s
		# 	#                                ^ sec to ms
		# }
		
		
		
		
		# # COMBINE THE FIRST TWO IDEAS
		# # move a changing number across the screen
		
		
		# # (dump to REPL)
		# @live_code[:update][0] = ->(){ @frame_count = (@time.ms / (0.8*1000).to_i % 10 ) }
		
		# @live_code[:update][1] = ->(){ @text.p.x = 100 + 800 * @frame_count / 10.to_f }
		
		# @live_code[:update][2] = ->(){ @text.string = @frame_count.to_s }
		
		
		
		# # (formatted and documented)
		
		# @live_code[:update][0] = ->(){
		# 	#                  seconds per frame       number of frames in loop
		# 	@frame_count = (@time.ms / (0.8*1000).to_i % 10 )
		# 	#                                ^ sec to ms
		# }
		
		# @live_code[:update][1] = ->(){
		# 	#       indent     total range to travel
		# 	#           |       |
		# 	#         |---|  |----|
		# 	@text.p.x = 100 + 800 * @frame_count / 10.to_f
		# 	#                       |_____________________|
		# 	#                         10 frames in loop, what percent has passed?
		# 	#                          (3 / 10 frames) -> 30% total distance
		# }
		
		# @live_code[:update][2] = ->(){ 
		# 	# convert @frame_count from [0] into a string, and display that
		# 	@text.string = @frame_count.to_s
		# }
		
		
		
		# # store clicks from mouse as point data, and process that
		# # @live_code[:draw][0] = ->(){@click_log.each{|o| ofDrawCircle(o.x, o.y, 0, 5) }}
		
	end
	
	def draw
		@test = 'foo'
		# aoeu
		# puts "draw"
	end
end
