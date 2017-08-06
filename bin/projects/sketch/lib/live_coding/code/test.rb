Class.new(LiveCoding::Code) do
	def initialize(window)
		super(window, "testing")
	end
	
	# setup additional variables
	# (will be useful later for constraints)
	def bind(save_directory)
		
	end
	
	# run this code using #call, rather than running directly
	def callback
		@time = Timer.new
		
		# @font = 
		# 	RubyOF::TrueTypeFont.new.dsl_load do |x|
		# 		# TakaoPGothic
		# 		x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
		# 		x.size = 20
		# 		x.add_alphabet :Latin
		# 		x.add_alphabet :Japanese
		# 	end
		
		# @text = TextEntity.new(self, @font)
		
		
		
		
		
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
end
