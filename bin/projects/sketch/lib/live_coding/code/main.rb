# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj


require 'yaml'

	
	# ===================================
	
	
	include LiveCoding::InspectionMixin
	
	include RubyOF::Graphics
	
	
	
	def setup(window, save_directory)
		@window = window
		
		
		root = Pathname.new(__FILE__).expand_path.dirname.parent.parent.parent
		@live_wrapper = LiveCoding::DynamicObject.new(
			@window,
			save_directory:   (root/'bin'/'data'),
			dynamic_code_file:(root/'lib'/'live_coding'/'code'/'test.rb'),
			method_contract:  [:serialize, :cleanup, :update, :draw]
		)
		
		@live_wrapper.setup # loads anonymous class, and initializes it
		
		
		
		@input_test = LiveCoding::DynamicObject.new(
			@window,
			save_directory:   (root/'bin'/'data'),
			dynamic_code_file:(root/'lib'/'live_coding'/'code'/'input.rb'),
			method_contract:  [
				:serialize, :cleanup, :update, :draw,
				:mouse_moved, :mouse_pressed, :mouse_released, :mouse_dragged
			]
		)
		
		@input_test.setup # loads anonymous class, and initializes it
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		[
			# @live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.serialize save_directory
		end
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
		[
			@live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.update
		end
	end
	
	def draw
		[
			@live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.draw
		end
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
	
	# NOTE: Can't use the name 'send' because the #send method is what allows you to call arbitrary methods using Ruby's message passing interface.
	# 
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
	
	
	def mouse_moved(x,y)
		[
			# @live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.mouse_moved x,y
		end
	end
	
	def mouse_pressed(x,y, button)
		[
			# @live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.mouse_pressed x,y, button
		end
	end
	
	def mouse_released(x,y, button)
		[
			# @live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.mouse_released x,y, button
		end
	end
	
	def mouse_dragged(x,y, button)
		[
			# @live_wrapper,
			@input_test,
		].each do |dynamic_obj|
			dynamic_obj.mouse_dragged x,y, button
		end
	end
	
end; return obj }

