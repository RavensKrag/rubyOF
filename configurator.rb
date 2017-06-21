#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

# Reads the config.yaml file, and updates the repository
# transforming all instances of the 'current_name' => 'name'
# The old name that was overwritten is saved as 'old_name'
# in case you need to revert what was done.
# 
# (Just move the 'old_name' key into the 'name' field, and rewrite again)




# -- load config file
def load_config(config_filepath)
	begin
		config = YAML.load_file config_filepath
	rescue Errno::ENOTDIR => e
		# trying to open file from directory that does not exist
	rescue Errno::ENOENT => e
		# trying to open a file that does not exist
	end
	
	return config
end

# -- write configuration back to disk
def dump_config(config_filepath, config)
	File.open config_filepath, 'w' do |f|
		f.print config.to_yaml
	end
end



config_filepath = "./config.yaml"
config = load_config(config_filepath)

# -- do work
old_name = config[:old_name]
name     = config[:current_name]
new_name = config[:name]

if new_name != name
	# Directories
	FileUtils.mv("./ext/#{name}", "./ext/#{new_name}")
	FileUtils.mv("./lib/#{name}", "./lib/#{new_name}")
	
	# Files
	FileUtils.mv("./lib/#{name}.rb", "./lib/#{new_name}.rb")
end


# -- update config
config[:old_name]     = name
config[:current_name] = new_name
config[:name]         = new_name


dump_config(config_filepath, config)










# # -- debug only stuff

# require 'irb'

# binding.irb
