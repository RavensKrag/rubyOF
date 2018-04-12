# Attempt to load a config.make file.
# If none is found, project defaults in config.project.make will be used.
ifneq ($(wildcard config.make),)
	include config.make
endif

# make sure the the OF_ROOT location is defined
ifndef OF_ROOT
	OF_ROOT=$(realpath ../../openFrameworks)
endif


# 
# SPECIAL OVERRIDE
# Need different path to openFrameworks directory
# than what is used to build the core project
# 
OF_ROOT = $(realpath ../../../../../../../ext/openFrameworks)



# call the project makefile!
include $(OF_ROOT)/libs/openFrameworksCompiled/project/makefileCommon/compile.project.mk

