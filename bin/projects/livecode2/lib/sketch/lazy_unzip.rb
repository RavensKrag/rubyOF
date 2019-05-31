# using a lazy Enumerator, we can use #zip to combine two input streams
# (think Unix pipes). How can we reverse this process?
# 
# What I want to do is take a single input stream, specified by an Enumerator,
# and multiplex it out into many streams.


a = (1..10)
b = ('a'..'z')

enum = a.lazy.zip(b)


# enum	Enumerator object
#        (preferably a lazy Enumerator, but lazy may be harder)
# 
# output type: [Enumerator]
def multiplex(enum)
	# all elements of index i=0 should go into one stream,
	# all elements of index i=1 should go into a second stream,
	# etc up to i=n
	
	enum.to_a.transpose.map{|x| x.each }
	
	
	
	enum.each do |tuple|
		n = tuple.length
		n.times.collect do |i|
			Enumerator.new do |y|
				y.yield tuple[i]
			end
		end
	end
end


# NOTE: needs to have an end signal (nil is a pretty good choice)
# recall that in the Clojure library Core.async, you can't put nil into a channel, because nil is used as the stop signal. This is thet same idea.
def lazy_multiplex(enum)
	n = enum.peek.length # just want to get the size, but not advance yet
	
	children = n.times.collect do |i|
		Fiber.new do |value|
			until value == nil
				# NOTE: needs to have an end signal (nil is a pretty good choice)
				
				
				
				value = Fiber.yield
			end
		end
	end
	
	# main thread needs to be aware of the children to pass data to them,
	# so main must be declared after children
	main = Fiber.new do
		begin
			enum.each do |tuple|
				children.zip(tuple) do |child, value|
					child.resume(value)
				end
				
				Fiber.yield
			end
		rescue StopIteration => e
			
		end
	end
	
	
	main =
		enum.lazy.map{ |tuple|
			children.zip(tuple) do |child, value|
				child.resume(value)
			end
		}.each # return a lazy Enumerator, not a Map-ed array
	
	
	return {:main => main, :children => children}
end

# Mulitplex from one stream to many.
# The result of each child stream will be yielded back to the main stream.
# (main stream holds aggregate result of all child work)
def lazy_multiplex_map
	
end




a = (1..10)
b = ('a'..'z')

enum = a.lazy.zip(b)

list = multiplex(enum)
list.each_with_index do |x, i|
	puts "#{i}: #{x.next.inspect}"
end





a = (1..10)
b = ('a'..'z')

enum = a.lazy.zip(b)

list = lazy_multiplex(enum)
list.each_with_index do |x, i|
	puts "#{i}: #{x.next.inspect}"
end
