require 'mkmf-rice'
require 'fileutils'
require 'open3'

require 'yaml'

path_to_file = File.absolute_path(File.dirname(__FILE__))
gem_root = File.expand_path('../../', path_to_file)

require File.expand_path('./build/common', gem_root)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions






create_makefile('rubyOF/rubyOF', 'cpp/lib')
