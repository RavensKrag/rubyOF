module LiveCoding

# Define new behavior for #inspect
# which truncates the horribly long Window#inspect output
# 
# Don't actually want to override Window#inspect directly,
# because the full output is ocassionally very useful when
# examining the window. However, I don't want to see all
# that when running #inspect on instances that merely hold
# a reference to window
# (especially because all things are contained inside Window)
module InspectionMixin
	def inspect
		# "<class=#{self.class} @visible=#{@visible}, file=#{self.class.const_get('ORIGIN_FILE')}>"
		
		# get ID for object
		get_id_string = ->(obj){
			return '%x' % (obj.object_id << 1)
		}
		
		id = get_id_string.(self)
		
		
		
		# manually inspect @window
		window_inspection = 
			"@window=<#{@window.class}:#{get_id_string.(@window)}>"
		
		# automatically inspect all things that are not @window
		foo = (instance_variables - [:@window])
		
		
		
		instance_var_inspection = 
			if foo.empty?
				nil
			else
				foo.collect{ |x|
					value = instance_variable_get(x).inspect
					
					"#{x}=#{value}"
					
				}.join(' ')
			end
		
		
		out = [window_inspection, instance_var_inspection].compact.join(', ')
		
		
		
		
		# custom inspection of @window (ID only)
		return "#<#{self.class}:0x#{id} #{out} >"
	end
end



end
