#!/usr/bin/env ruby

timestamp = ARGV[0]



data = File.readlines(timestamp + '.log')

File.open(timestamp + '.out.tsv','w'){ |f|
	out = 
		data.select{ |l|   l[0..2] == ">> "  }
		.each_with_index
		.map{|x,i| ([i] + x.chomp.split("\t")).join("\t") }.join("\n")
	
	f.puts out
}
