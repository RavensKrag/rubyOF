require 'mkmf-rice'
require 'pathname'

GEM_ROOT = '../../../../..'

require File.expand_path('./common', GEM_ROOT)
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

