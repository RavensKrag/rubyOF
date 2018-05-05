class Entity
	attr_reader :body, :shape
	attr_accessor :z
	attr_accessor :id
	
	def initialize(body, shape)
		@body  = body # CP::Body
		@shape = shape # class from CP::Shape module, or similar
		@z = 0
		
		@id = nil # Unique identifier that persists between sessions.
		          # (assigned not on init, but when Entity is added to Space)
	end
	
	def serialize
		raise StubbedMethodError.new(self.class, "serialize()",
			"NOTE: Should return Seralized"
		)
	end
	
	def deserialize(serialized)
		raise StubbedMethodError.new(self.class, "serialize()",
			"NOTE: Uses Seralized to set all of the properties for this Entity"
		)
	end
	
	
	
	
	
	class StubbedMethodError < NoMethodError
		def initialize(klass, method_signature, message)
			msg = 
				[
					"Stubbed method not implemented: #{klass}##{method_signature}",
					message.each_line.collect{ |line| "  " + line }
				].join("\n")
			
			super(msg)
		end
	end
end 
