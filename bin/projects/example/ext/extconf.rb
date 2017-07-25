require 'mkmf-rice'
require 'fileutils'
require 'open3'

require 'yaml'

path_to_file = File.absolute_path(File.dirname(__FILE__))
gem_root = File.expand_path('../../../../', path_to_file)

require File.expand_path('./common', gem_root)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# ^--- changed that part (needed to update the 'gem_root' path)




# NOTE: DATA_PATH (c++ preprocessor constant) currently being set manually for this project



# TODO: link against a static library created by the main project, which is just the basic glue code.
# TODO: need to make that static library first (just gather up all the .o filer in the ext/rubyOF directory)




# `ar cr libwrapper.a app.o Fbo.o Graphics.o image.o launcher.o rubyOF.o TrueTypeFont.o `
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/app.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/Fbo.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/Graphics.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/image.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/launcher.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/rubyOF.o
	# /home/ravenskrag/Desktop/gem_structure/ext/rubyOF/TrueTypeFont.o




require File.join(GEM_ROOT, 'ext', NAME, 'extconf_common.rb')


# ========================================
# ========== add new stuff here ==========


# headers = File.join(GEM_ROOT, 'ext', NAME)
# libs    = File.join(GEM_ROOT, 'ext', NAME, 'lib')

# dir_config(
# 	"wrapper", # name to use with 'have_library'
# 	headers, libs
# )

# have_library("wrapper")   # oF version

# $LOCAL_LIBS << "-lwrapper"


path = File.join(GEM_ROOT, 'ext', NAME)
$CPPFLAGS += " -I#{path}"



# ========================================
# ========================================



create_makefile('rubyOF/rubyOF')



require File.join(GEM_ROOT, 'ext', NAME, 'extconf_printer.rb')

filepath = File.join(path_to_file, 'extconf_variables.yaml')
write_extconf_variables_to_file(filepath)
