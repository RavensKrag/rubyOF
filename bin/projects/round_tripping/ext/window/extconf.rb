require 'mkmf-rice'

path_to_file = File.absolute_path(File.dirname(__FILE__))
gem_root = File.expand_path('../../../../../', path_to_file)

require File.expand_path('./common', gem_root)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# ^--- changed that part (needed to update the 'gem_root' path)


require File.join(GEM_ROOT, 'ext', NAME, 'extconf_common.rb')


# ========================================
# ========== add new stuff here ==========


# Need this to load 'app_factory.h'
path = File.join(GEM_ROOT, 'ext', NAME)
$CPPFLAGS += " -I#{path}"



# ========================================
# ========================================



create_makefile('rubyOF/rubyOF')



require File.join(GEM_ROOT, 'ext', NAME, 'extconf_printer.rb')

filepath = File.join(path_to_file, 'extconf_variables.yaml')
write_extconf_variables_to_file(filepath)

