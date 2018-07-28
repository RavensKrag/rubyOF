# Need to rebind code, but keep data exactly the way it is in memory,
# because when I have a full history of states for Space I can roll
# back to, I don't want to have to pay the cost of full serialization
# every time I refresh the code.

# The idea is to dynamically reload the core part of the code base.
# From there, any reloading of additional types or data is
# 

class LiveCoding
	# NOTE: Save @inner, not the entire wrapper. This means you can move the defining code to some other location on disk if you would like, or between computers (system always uses absolute paths, so changing computer would break data, which is pretty bad)

	# remember file paths, and bind data


	def initialize(class_constant_name,
		header:, body:, save_directory:, method_contract:
	)
		puts "setting up Live Coding environment"
		
		
		@klass_name  = class_constant_name
		@header_file = header
		@body_file   = body
		@save_file   = save_directory/'data.yml'
		@method_contract = method_contract
		
		
		# klass = Kernel.const_get @klass_name
		# if method_contract_satisfied?(klass, @method_contract)
		# 	puts "test"
		# end
		
		setup_delegators(@method_contract)
		
		
		@wrapped_object = nil
	end

	# automatically save data to disk before exiting
	def on_exit
		
	end


	# reload code as needed
	def update
		# puts "update"
		
		# protect_runtime_errors do
			if @wrapped_object.nil?
				# puts "null handler: #{sym}"
			else
				@wrapped_object.send sym, *args
			end
		# end
	end
	
	
	# NOTE: under this architecture, you can't dynamically change initialization or serialization code - you would have to restart the program if that sort of change is made
	# ^ is this still true?
	
	
	private
	
	
	def method_contract_satisfied?(klass, contract)
		unless contract.all?{|sym| obj.respond_to? sym }
			a = contract.inspect
			b = klass.instance_methods.inspect
			
			msg = 
			[
			"Failed to bind the following object from #{@file}: #{obj}",
			"  Object returned from lambda does not respond to all methods specified in the method contract.",
			"  contract: #{a}",
			"  methods:  #{b}",
			"  missing methods: #{a - b}",
			].join("\n")
			
			raise msg
		end
		
		return true
	end
	
	
	# 
	# create delegates to all of the methods in @method_contract
	# 
	
	def setup_delegators(method_contract)
		# NOTE: Must use the @wrapped_object instance variable instead of passing as parameter. Otherwise, #setup_delegators needs to be re-run every time a new object is loaded.
		
		# TODO: automate creation of wrappers for methods with names that exist in this wrapper (create all mehtods on module, and then mix it in?)
		
		# --- blacklist some methods from being wrapped,
		#     because they have been handled manually.
		excluded_methods = [:update]
		method_symbols = (method_contract - excluded_methods)
		
		
		# --- make sure :setup isn't part of the method contract
		if method_symbols.include? :setup
			raise WrapperContractError, "Callback object should not declare #setup. Place setup code in the normal #initialize method found in all Ruby objects instead. Fix the method contract and try again."
		end
		
		# --- check for symbol collision
		collisions = self.public_methods + self.private_methods
		if collisions.any?{|sym| method_symbols.include? sym }
			raise WrapperNameCollison.new(
				sym, file, method_contract, method_symbols
			)
		end
		
		# --- create the acutal delegators
		method_symbols.each do |sym|
			meta_def sym do |*args|
				# protect_runtime_errors do
					if @wrapped_object.nil?
						# puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, *args
					end
				# end
			end
		end
	end
	
	class WrapperNameCollison < StandardError
		def initialize(sym, file, method_contract, method_symbols)
			msg = 
				"wrapper / wrapped object method name collision for method '#{sym}' in the contract for callback object from #{file}.\n" +
				"  Full method contract: #{method_contract.inspect}\n" +
				"  Attempting to bind these symbols: #{method_symbols.inspect}\n" +
				"  (To examine where the contract was defined, look further up the stack, to where DynamicObject.new was called."
			super(msg)
		end
	end
	
	class WrapperContractError < StandardError
		def initialize(msg)
			super(msg)
		end
	end
end

