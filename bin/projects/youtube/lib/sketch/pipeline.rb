require 'fiber'
require 'yaml'
require 'pathname'
require 'fileutils'

current_file = Pathname.new(__FILE__).expand_path
project_dir  = current_file.parent.parent

Dir.chdir project_dir do
	require Pathname.new('./helpers.rb').expand_path
end


class Pipeline
	include HelperFunctions
	
	def initialize(seed_data)
		@data = seed_data
		
		@instructions = Array.new
		
		@fiber = Fiber.new do
			puts "executing pipeline..."
			
			@data.each do |x|
				out = x
				@instructions.each do |proc|
					out = proc.call(out)
				end
			end
			
			@instructions.each do |proc|
				@data = proc.call @data
				Fiber.yield
			end
			
			puts "execution finished!"
		end
	end
	
	def add(&block)
		@instructions << block
		
		return self
	end
	
	# wait for the previous stage of the pipeline to complete,
	# and then cache that data to disk
	# filepath    ---   location where intermidate should be stored
	def save_intermediate(filepath)
		add do
			puts "saved"
			# data
			# dump_yaml data => filepath
		end
	end
	
	
	
	def call()
		if @fiber.alive?
			@fiber.resume
			return false
		else
			return true
		end
	end
end



data = (1..10).to_a

# Pipeline.new(data)
# .p1{ |filepath|
# 	# specify a filepath to store the intermediate,
# 	# or omit if you don't want to save it
# 	filepath = ""
# }
# .p2{
	
# }
# .p3{
	
# }



# html_file ->                             # youtube subscription page
# [data_1, data_2, data_3, ..., data_n] -> # channel data - name, icon url, etc
# [icon_1, icon_2, icon_3, ..., icon_n] -> # icon image data (on disk)
# [img_1, img_2, img_3, ..., img_n]     -> # icon image data (textures in RAM)





# simple pipeline test
xs = (1..10).to_a

pipeline1 = 
	Pipeline.new(xs) # initially, input a list
	.add{ |x| # at each step, process one element
		puts "one"
		# x * 2
	}
	.add{ |x|
		puts "two"
		# x + 3
	}
	.add{ |x|
		puts "three"
		# x % 5
	}

loop do
	puts "main: tick"
	
	if pipeline1.call()
		break
	end
	
	# puts "main: tock"
end





producer = Fiber.new do
	(1..10).each do |i|
		Fiber.yield i
	end
	
	nil # return
end

consumer = Fiber.new do
	producer.resume if producer.alive?
end

12.times do 
	puts producer.resume if producer.alive?
end



# Each stage passes information to the next as an IO stream.
# For this to work properly, even the first stage must take a stream as input.





# Start a pipeline using an Enumerator
def wrap_seed(enum)
	Fiber.new do
		enum.each do |x|
			Fiber.yield x
		end
		
		:PIPELINE_END # return
	end
end

def pipe(input, &block)
	Fiber.new do
		while input.alive?
			data_in  = input.resume 
			
			unless data_in == :PIPELINE_END
				data_out = block.call(data_in)
				
				Fiber.yield data_out
			end
		end
	end
end

# Finish off a pipeline
def finish_pipeline(fiber)
	Enumerator.new do |y|
		while fiber.alive?
			out = fiber.resume
			
			if out == :PIPELINE_END
				break
			else
				y.yield out
			end
		end
	end
end



puts "=== all Fiber implementation"
seed = wrap_seed (1..10).each
fiber = pipe(seed){|x| x + 6 }

finish_pipeline(fiber).each do |x|
	puts x
end

p finish_pipeline(fiber).to_a





puts "=== Enumerator implementation"

# Start a pipeline using an Enumerator
def pipe(input, &block)
	Enumerator.new do |y|
		loop do
			data_in  = input.next
			data_out = block.call(data_in)
			y.yield data_out
		end
	end
	# Input.next raises exception when there is no more data to consume, but I guess because we're inside an Enumerator block that gets swallowed? Cool!
end


seed = (1..10).each
p1 = pipe(seed){|x| x + 3 }
p2 = pipe(p1){  |x| x * 2 }
p3 = pipe(p2){  |x| x % 5 }
final_pipeline = p3

final_pipeline.each do |x|
	puts x
end

# puts final_pipeline.next



# "Stop including Enumerable, return Enumerator instead"
# Robert Pankowecki, Jan 8 2014
# https://blog.arkency.com/2014/01/ruby-to-enum-for-enumerator/

# "Pipelines Using Fibers in Ruby 1.9"
# PragDave, Dec 30 2007
# https://web.archive.org/web/20150922002204/https://pragdave.me/blog/2007/12/30/pipelines-using-fibers-in-ruby-19/

# "Pipelines Using Fibers in Ruby 1.9—Part II"
# PragDave, Jan 1 2008
# https://pragdave.me/blog/2008/01/01/pipelines-using-fibers-in-ruby-19part-ii.html





# ok. now I want to make something very similar to using Enumerator, but I want extra functionality
# + I want to be able to save intermediates of the pipeline
# + I want to pause after each step of the pipeline, using Fiber.yield

puts "=== fiber-friendly custom Enumerator"
class CustomEnumerator
	def initialize(&block)
		@fiber = Fiber.new do |arg|
			begin
				block.call(arg)
			rescue StopIteration => e
				e
			end
			
		end
		
		return nil
	end
	
	def next
		if @fiber.alive?
			@fiber.resume
		else
			raise StopIteration
		end
	end
	
	def each(&block)
		begin
			while @fiber.alive?
				block.call @fiber.resume
			end
		rescue StopIteration
			
		end
	end
end


# Start a pipeline using an Enumerator
def pipe(input, &block)
	CustomEnumerator.new do |y|
		loop do
			data_in  = input.next
			p data_in
			# garbage = Fiber.yield data_in # <-- NO!
			data_out = block.call(data_in)
			Fiber.yield data_out
		end
		
		# raise StopIteration
	end
	# Enumerator is implemented using Fiber, so calling Fiber.yield
	# in the middle of an Enumerator block causes things to go weird
end

## NOT WORKING YET

# seed = (1..10).each
# p1 = pipe(seed){|x| puts "foo"; x + 3 }
# p2 = pipe(p1){  |x| puts "baz"; x * 2 }
# p3 = pipe(p2){  |x| puts "bar"; x % 5 }
# final_pipeline = p3

# final_pipeline.each do |x|
# 	puts "==> #{x}" 
# end





puts "=== using lazy Enumerators"

collection = Array.new

enum =
	(1..Float::INFINITY).lazy # remember to use 'lazy' for an infite process!
	.collect{|x| x + 3 }
	.collect{|x| x * 2 }
	.collect{|x| x - 12}
	.each # Get an enumerator out, instead of evaluating the thing right now

10.times do
	collection << enum.next
	p collection
end

# more = 5.times.collect{ enum.next }
# collection.concat more
# p collection # <--------

# more = 5.times.collect{ enum.next }
# collection.concat more
# p collection # <--------

# more = 5.times.collect{ enum.next }
# collection.concat more
# p collection # <--------







# Start a pipeline using an Enumerator
def pipe(input, &block)
	Enumerator.new do |y|
		loop do
			data_in  = input.next
			p data_in
			# garbage = Fiber.yield data_in # <-- NO!
			data_out = block.call(data_in)
			Fiber.yield data_out
		end
		
		raise StopIteration
	end
	# Enumerator is implemented using Fiber, so calling Fiber.yield
	# in the middle of an Enumerator block causes things to go weird
end



# # can save intermediates to file if desired.
# Pipeline.new(data)
# .add{
	
# }
# .save_intermediate("path/to/file.yaml")
# .add{
	
# }
# .save_intermediate("path/to/file.yaml")
# .add{
	
# }
