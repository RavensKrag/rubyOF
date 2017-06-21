class Object
	# The hidden singleton lurks behind everyone
	def metaclass; class << self; self; end; end
	def meta_eval &blk; metaclass.instance_eval &blk; end

	# Adds methods to a metaclass
	def meta_def name, &blk
		meta_eval { define_method name, &blk }
	end

	# Defines an instance method within a class
	def class_def name, &blk
		class_eval { define_method name, &blk }
	end
	
	
	
	# Private meta definition
	def private_meta_def name, &blk
		meta_eval do
			define_method name, &blk 
			private name
		end
	end
	
	def private_class_def name, &blk
		class_eval do
			define_method name, &blk
			private name
		end
	end
end


class Class
	def def_each(*method_names, &block)
		method_names.each do |method_name|
			define_method method_name do
				instance_exec method_name, &block
			end
		end
	end
end


