require 'mkmf-rice'
require 'pathname'

GEM_ROOT = '../../../../..'

require File.expand_path('./common', GEM_ROOT)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# ^--- changed that part (needed to update the 'gem_root' path)


require File.join(GEM_ROOT, 'ext', NAME, 'extconf_common.rb')


# ========================================
# ========== add new stuff here ==========


# have_library("stdc++")



# ========================================
# ========================================



create_makefile('rubyOF/rubyOF_project')
