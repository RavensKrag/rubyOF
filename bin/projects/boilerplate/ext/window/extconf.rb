require 'mkmf-rice'
require 'pathname'

GEM_ROOT = '../../../../..'

require File.expand_path('./common', GEM_ROOT)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# ^--- changed that part (needed to update the 'gem_root' path)


require File.join(GEM_ROOT, 'ext', NAME, 'extconf_common.rb')


# Need this to load 'app_factory.h'
path = File.join(GEM_ROOT, 'ext', NAME)
$CPPFLAGS += " -I#{path}"

# ========================================
# ========== add new stuff here ==========





# ========================================
# ========================================



create_makefile('rubyOF/rubyOF')



require File.join(GEM_ROOT, 'ext', NAME, 'extconf_printer.rb')

path_to_file = File.absolute_path(File.dirname(__FILE__))
filepath = File.join(path_to_file, 'extconf_variables.yaml')
write_extconf_variables_to_file(filepath)

