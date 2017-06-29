This build recipe is copied from the openframeworks apothecary

The code is copied over from the 'repo' directory, slightly further down.

source:
	https://github.com/openframeworks/apothecary/blob/4a6a3bd82b1127a02e90bad0986c6394ad407078/apothecary/formulas/kiss/Makefile.linux64
^ current 'master' branch at time of writing



This methodology is necessary to resolve the following error: 

	/home/ravenskrag/Desktop/gem_structure/ext/openFrameworks/libs/openFrameworksCompiled/lib/linux64/libopenFrameworks.a: undefined reference to `kiss_fftr_alloc'
	/home/ravenskrag/Desktop/gem_structure/ext/openFrameworks/libs/openFrameworksCompiled/lib/linux64/libopenFrameworks.a: undefined reference to `kiss_fftr'

^ That's what you get if you use the default build process. kiss_fftr is normally part of the tools, but OpenFrameworks expects it to be compiled into the libkiss.a library.
