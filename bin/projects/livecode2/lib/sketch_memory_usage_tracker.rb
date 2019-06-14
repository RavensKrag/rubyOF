 
require 'objspace'


# ObjectSpace.memsize_of
# ObjectSpace.reachable_objects_from

a = (1..100).to_a
b = ('a'..'z').to_a
x = [a,b]


def mem_size(x)
	if x.is_a? Class
		ObjectSpace.memsize_of(x)
	else
		ObjectSpace.memsize_of(x) +
		ObjectSpace.reachable_objects_from(x).map{|x| mem_size(x) }.reduce(&:+)
	end
end


require 'irb'
binding.irb




# mem_size(a)                =>    5616
# mem_size(b)                =>  128232
# mem_size(a) + mem_size(b)  =>  133848
# mem_size(x)                =>  138440
# ObjectSpace.memsize_of_all => 3526762

# mem_size(a) + mem_size(b) < mem_size(x)
# => true

# ObjectSpace.memsize_of_all > mem_size(x)
# => true

	# 2.5.1 :001 > mem_size(a)
	#  => 5616 
	# 2.5.1 :003 > mem_size(b)
	#  => 128232 
	# 2.5.1 :005 > mem_size(a) + mem_size(b)
	#  => 133848 
	# 2.5.1 :004 > mem_size(x)
	#  => 138440 
	# 2.5.1 :007 > mem_size(a) + mem_size(b) < mem_size(x)
	#  => true 
	# 2.5.1 :008 > ObjectSpace.memsize_of_all
	#  => 3526762 
	# 2.5.1 :009 > ObjectSpace.memsize_of_all > mem_size(x)
	#  => true 
