require 'mkmf-rice'
require 'pathname'

project_root = Pathname.new(__FILE__).expand_path.dirname.parent.parent
require (project_root/'config'/'build_variables')
# ^ definition of GEM_ROOT variable

require File.expand_path('./common', GEM_ROOT)
# ^ declares many constansts used by build system and some functions

# ^--- changed that part (needed to update the 'gem_root' path)


require File.join(GEM_ROOT, 'ext', NAME, 'extconf_common.rb')


# ========================================
# ========== add new stuff here ==========


# have_library("stdc++")



# ========================================
# ========================================



create_makefile('rubyOF/rubyOF_project')
