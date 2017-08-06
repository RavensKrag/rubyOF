module RubyOF


class Window
	alias :rice_cpp_initialize :initialize
	def initialize(title, width, height)
		# pass Ruby instance to C++ land for callbacks, etc
		rice_cpp_initialize(self, width, height)
		
		# ensure that all windows have a title by requring one in the constructor
		self.window_title = title
	end
	
	
	def setup
		puts "ruby: Window#setup"
	end
	
	def update
		puts "ruby: Window#update"
	end
	
	def draw
		puts "ruby: Window#draw"
	end
	
	# NOTE: this method can not be called 'exit' because there is a method Kernel.exit
	def on_exit
		puts "ruby: exiting application..."
	end
	
	
	def key_pressed(key)
		p [:pressed, key]
	end
	
	def key_released(key)
		p [:released, key]
	end
	
	
	def mouse_moved(x,y)
		p "mouse position: #{[x,y]}.inspect"
	end
	
	def mouse_pressed(x,y, button)
		p [:pressed, x,y, button]
	end
	
	def mouse_released(x,y, button)
		p [:released, x,y, button]
	end
	
	def mouse_dragged(x,y, button)
		p [:dragged, x,y, button]
	end
	
	
	def mouse_entered(x,y)
		p [:mouse_in, x,y]
	end
	
	def mouse_exited(x,y)
		p [:mouse_out, x,y]
	end
	
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		p [:mouse_scrolled, x,y, scrollX, scrollY]
	end
	
	
	def window_resized(w,h)
		p [:resize, w,h]
	end
	
	def drag_event(files, position)
		p [files, position]
	end
	
	def got_message()
		# NOTE: not currently bound
	end
end


end
