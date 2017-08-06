
module RubyOF
	module SelfMonkeyPatch



module Image
	def dsl_load # &block
		# pass config DSL object to block
		config = DSL_Object.new
		
		yield config
		
		# establish real objects
		image    = self.class.new
		settings = RubyOF::ImageLoadSettings.new
		
		# convert config -> settings
		# NOTE: initialized values of ImageLoadSettings are the defaults
		path = config.path
		
		settings.accurate     = config.accurate?
		settings.exifRotate   = config.exifRotate?
		settings.grayscale    = config.grayscale?
		settings.separateCMYK = config.separateCMYK?
		
		
		# load using settings
		load_status = image.load(path, settings)
		raise "Could not load image" unless load_status
		
		return image
	end
	
	class DSL_Object
		attr_accessor :path
		
		def initialize
			
		end
		
		
		# create methods like:
			# enable_accurate
			# disable_accurate
		# rather than letting the user set arbirary values to these flags
		# (they should only ever be booleans)
		flags = [
			:accurate,
			:exifRotate,
			:grayscale,
			:separateCMYK
		]
		
		
		# TODO: abstract the following into a metaprogramming method 'boolean_attr_accessors' or similar
		
		
		# establish new mutation interface
		# ex) enable_accurate / disable_accurate (for variable @accurate)
		[:enable, :disable].zip(flags)
		.each do |en_or_dis_able, flag_name|
			if en_or_dis_able == :enable
				define_method "#{en_or_dis_able}_#{flag_name}" do
					self.instance_variable_set "@#{flag_name}", true
				end			
			else # assuming ':disable'
				define_method "#{en_or_dis_able}_#{flag_name}" do
					self.instance_variable_set "@#{flag_name}", false
				end
			end
		end
		
		# establish new accessor interface
		# ex) accurate? (for variable @accurate)
		flags.each do |flag_name|
			define_method "#{flag_name}?" do
				self.instance_variable_get "@#{flag_name}"
			end
		end
		
	end
end


end; end



module RubyOF

class Image
	prepend RubyOF::SelfMonkeyPatch::Image
end

end
