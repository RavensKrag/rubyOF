
SHELL = /bin/sh

# V=0 quiet, V=1 verbose.  other values don't work.
V = 0
Q1 = $(V:1=)
Q = $(Q1:0=@)
ECHO1 = $(V:1=@ :)
ECHO = $(ECHO1:0=@ echo)
NULLCMD = :

#### Start of system configuration section. ####

srcdir = .
topdir = /home/ravenskrag/.rvm/rubies/ruby-2.4.0/include/ruby-2.4.0
hdrdir = $(topdir)
arch_hdrdir = /home/ravenskrag/.rvm/rubies/ruby-2.4.0/include/ruby-2.4.0/x86_64-linux
PATH_SEPARATOR = :
VPATH = $(srcdir):$(arch_hdrdir)/ruby:$(hdrdir)/ruby

prefix = $(DESTDIR)/home/ravenskrag/.rvm/rubies/ruby-2.4.0

rubysitearchprefix = $(rubylibprefix)/$(sitearch)

rubyarchprefix = $(rubylibprefix)/$(arch)

rubylibprefix = $(libdir)/$(RUBY_BASE_NAME)

exec_prefix = $(prefix)

vendorarchhdrdir = $(vendorhdrdir)/$(sitearch)

sitearchhdrdir = $(sitehdrdir)/$(sitearch)

rubyarchhdrdir = $(rubyhdrdir)/$(arch)

vendorhdrdir = $(rubyhdrdir)/vendor_ruby

sitehdrdir = $(rubyhdrdir)/site_ruby

rubyhdrdir = $(includedir)/$(RUBY_VERSION_NAME)

vendorarchdir = $(vendorlibdir)/$(sitearch)

vendorlibdir = $(vendordir)/$(ruby_version)

vendordir = $(rubylibprefix)/vendor_ruby

sitearchdir = $(sitelibdir)/$(sitearch)

sitelibdir = $(sitedir)/$(ruby_version)

sitedir = $(rubylibprefix)/site_ruby

rubyarchdir = $(rubylibdir)/$(arch)

rubylibdir = $(rubylibprefix)/$(ruby_version)

sitearchincludedir = $(includedir)/$(sitearch)

archincludedir = $(includedir)/$(arch)

sitearchlibdir = $(libdir)/$(sitearch)

archlibdir = $(libdir)/$(arch)

ridir = $(datarootdir)/$(RI_BASE_NAME)

mandir = $(datarootdir)/man

localedir = $(datarootdir)/locale

libdir = $(exec_prefix)/lib

psdir = $(docdir)

pdfdir = $(docdir)

dvidir = $(docdir)

htmldir = $(docdir)

infodir = $(datarootdir)/info

docdir = $(datarootdir)/doc/$(PACKAGE)

oldincludedir = $(DESTDIR)/usr/include

includedir = $(prefix)/include

localstatedir = $(prefix)/var

sharedstatedir = $(prefix)/com

sysconfdir = $(DESTDIR)/etc

datadir = $(datarootdir)

datarootdir = $(prefix)/share

libexecdir = $(exec_prefix)/libexec

sbindir = $(exec_prefix)/sbin

bindir = $(exec_prefix)/bin

archdir = $(rubyarchdir)



CC = gcc
CXX = g++
LIBRUBY = $(LIBRUBY_SO)
LIBRUBY_A = lib$(RUBY_SO_NAME)-static.a
LIBRUBYARG_SHARED = -Wl,-rpath,'$${ORIGIN}/../lib' -Wl,-R'$${ORIGIN}/../lib' -l$(RUBY_SO_NAME)
LIBRUBYARG_STATIC = -Wl,-rpath,'${ORIGIN}/../lib' -Wl,-R'${ORIGIN}/../lib' -lruby-static
empty =
OUTFLAG = -o $(empty)
COUTFLAG = -o $(empty)
CSRCFLAG = $(empty)

RUBY_EXTCONF_H = 
cflags   = $(optflags) $(debugflags) $(warnflags)
cxxflags = $(optflags) $(debugflags) $(warnflags)
optflags = -O3 -fno-fast-math
debugflags = -ggdb3
warnflags = -Wall -Wextra -Wno-unused-parameter -Wno-parentheses -Wno-long-long -Wno-missing-field-initializers -Wno-tautological-compare -Wno-parentheses-equality -Wno-constant-logical-operand -Wno-self-assign -Wunused-variable -Wimplicit-int -Wpointer-arith -Wwrite-strings -Wdeclaration-after-statement -Wimplicit-function-declaration -Wdeprecated-declarations -Wno-packed-bitfield-compat -Wsuggest-attribute=noreturn -Wsuggest-attribute=format -Wno-maybe-uninitialized
CCDLFLAGS = -fPIC
CFLAGS   = $(CCDLFLAGS) $(cflags)  -fPIC $(ARCH_FLAG)
INCFLAGS = -I. -I$(arch_hdrdir) -I$(hdrdir)/ruby/backward -I$(hdrdir) -I$(srcdir)
DEFS     = 
CPPFLAGS =  -I/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/kiss -I/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/kiss/tools -I/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/tess2/Include  $(DEFS) $(cppflags)  -I/home/ravenskrag/.rvm/gems/ruby-2.4.0/gems/rice-2.1.1/ruby/lib/include -D_REENTRANT -pthread -I/usr/include/gstreamer-1.0 -I/usr/lib/x86_64-linux-gnu/gstreamer-1.0/include -I/usr/include/AL -I/usr/include/alsa -I/usr/include/libdrm -I/usr/include/gtk-3.0 -I/usr/include/at-spi2-atk/2.0 -I/usr/include/at-spi-2.0 -I/usr/include/dbus-1.0 -I/usr/lib/x86_64-linux-gnu/dbus-1.0/include -I/usr/include/gtk-3.0 -I/usr/include/gio-unix-2.0/ -I/usr/include/mirclient -I/usr/include/mircore -I/usr/include/mircookie -I/usr/include/cairo -I/usr/include/pango-1.0 -I/usr/include/harfbuzz -I/usr/include/pango-1.0 -I/usr/include/atk-1.0 -I/usr/include/cairo -I/usr/include/pixman-1 -I/usr/include/freetype2 -I/usr/include/libpng12 -I/usr/include/gdk-pixbuf-2.0 -I/usr/include/libpng12 -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/glm/include -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/glm/include/glm -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/glm/include/glm/gtx -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/glm/include/glm/detail -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/glm/include/glm/gtc -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/json/include -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/utf8/include -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/utf8/include/utf8 -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/types -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/app -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/events -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/communication -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/graphics -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/video -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/3d -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/math -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/sound -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/utils -I/home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworks/gl -I/home/ravenskrag/Desktop/gem_structure/ext/oF_apps/testApp/src
CXXFLAGS = $(CFLAGS)  -Wall -g -O3 -march=native -mtune=native -std=c++14 -DGCC_HAS_REGEX -DOF_USING_GTK -DOF_USING_MPG123
ldflags  = -L. -fstack-protector -rdynamic -Wl,-export-dynamic  -L/home/ravenskrag/.rvm/gems/ruby-2.4.0/gems/rice-2.1.1/ruby/lib/lib -lrice /home/ravenskrag/Desktop/gem_structure/ext/oF_apps/testApp/obj/linux64/Release/src/ofApp.o /home/ravenskrag/Desktop/gem_structure/ext/oF_apps/testApp/obj/linux64/Release/src/main.o   /home/ravenskrag/Code/Source/OpenFrameworks/git_repo/addons/obj/linux64/Release/ofxGUI/./src/ofApp.o /home/ravenskrag/Code/Source/OpenFrameworks/git_repo/addons/obj/linux64/Release/ofxGUI/./src/main.o   /home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/openFrameworksCompiled/lib/linux64/libopenFrameworks.a   -Wl,-rpath=./libs:./bin/libs:/home/ravenskrag/Desktop/gem_structure/bin/libs -Wl,--as-needed -Wl,--gc-sections   /home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/kiss/lib/linux64/libkiss.a /home/ravenskrag/Code/Source/OpenFrameworks/git_repo/libs/tess2/lib/linux64/libtess2.a -lz -lgstapp-1.0 -lgstvideo-1.0 -lgstbase-1.0 -lgstreamer-1.0 -ludev -lfontconfig -lfreetype -lsndfile -lopenal -lssl -lcrypto -lcurl -lglfw -lpulse-simple -lpulse -lasound -lGLEW -lGLU -lGL -lgtk-3 -lgdk-3 -lpangocairo-1.0 -lpango-1.0 -latk-1.0 -lcairo-gobject -lcairo -lgdk_pixbuf-2.0 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lmpg123 -lglut -lX11 -lXrandr -lXxf86vm -lXi -lXcursor -ldl -lpthread -lfreeimage -lboost_filesystem -lboost_system -lpugixml -luriparser -lXinerama -lrtaudio
dldflags = -Wl,--compress-debug-sections=zlib 
ARCH_FLAG = 
DLDFLAGS = $(ldflags) $(dldflags) $(ARCH_FLAG)
LDSHARED = g++ -shared
LDSHAREDXX = $(CXX) -shared
AR = ar
EXEEXT = 


RUBY_INSTALL_NAME = $(RUBY_BASE_NAME)

RUBY_SO_NAME = ruby

RUBYW_INSTALL_NAME = 

RUBY_VERSION_NAME = $(RUBY_BASE_NAME)-$(ruby_version)

RUBYW_BASE_NAME = rubyw

RUBY_BASE_NAME = ruby


arch = x86_64-linux
sitearch = $(arch)
ruby_version = 2.4.0
ruby = $(bindir)/$(RUBY_BASE_NAME)
RUBY = $(ruby)
ruby_headers = $(hdrdir)/ruby.h $(hdrdir)/ruby/backward.h $(hdrdir)/ruby/ruby.h $(hdrdir)/ruby/defines.h $(hdrdir)/ruby/missing.h $(hdrdir)/ruby/intern.h $(hdrdir)/ruby/st.h $(hdrdir)/ruby/subst.h $(arch_hdrdir)/ruby/config.h

RM = rm -f
RM_RF = $(RUBY) -run -e rm -- -rf
RMDIRS = rmdir --ignore-fail-on-non-empty -p
MAKEDIRS = /bin/mkdir -p
INSTALL = /usr/bin/install
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 644
COPY = cp
TOUCH = exit >

#### End of system configuration section. ####

preload = 


CXX = g++
libpath = . $(libdir) /home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/kiss /home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/tess2/Build
LIBPATH =  -L. -L$(libdir) -Wl,-R$(libdir) -L/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/kiss -Wl,-R/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/kiss -L/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/tess2/Build -Wl,-R/home/ravenskrag/Desktop/gem_structure/ext/oF_deps/v0.9.3/custom/tess2/Build
DEFFILE = 

CLEANFILES = mkmf.log
DISTCLEANFILES = 
DISTCLEANDIRS = 

extout = 
extout_prefix = 
target_prefix = /rubyOF
LOCAL_LIBS = 
LIBS = -lstdc++ -Wl,-rpath,'${ORIGIN}/../lib' -Wl,-R'${ORIGIN}/../lib' -lruby -lpthread -lgmp -ldl -lcrypt -lm   -lc
ORIG_SRCS = Fbo.cpp Graphics.cpp TrueTypeFont.cpp app.cpp launcher.cpp oni.cpp
SRCS = $(ORIG_SRCS) 
OBJS = Fbo.o Graphics.o TrueTypeFont.o app.o launcher.o oni.o
HDRS = $(srcdir)/oni.h $(srcdir)/rice.h $(srcdir)/Graphics.h $(srcdir)/Fbo.h $(srcdir)/TrueTypeFont.h $(srcdir)/app.h $(srcdir)/launcher.h
LOCAL_HDRS = 
TARGET = rubyOF
TARGET_NAME = rubyOF
TARGET_ENTRY = Init_$(TARGET_NAME)
DLLIB = $(TARGET).so
EXTSTATIC = 
STATIC_LIB = 

TIMESTAMP_DIR = .

BINDIR        = $(bindir)

RUBYCOMMONDIR = $(sitedir)$(target_prefix)

RUBYLIBDIR    = $(sitelibdir)$(target_prefix)

RUBYARCHDIR   = $(sitearchdir)$(target_prefix)

HDRDIR        = $(rubyhdrdir)/ruby$(target_prefix)

ARCHHDRDIR    = $(rubyhdrdir)/$(arch)/ruby$(target_prefix)

TARGET_SO_DIR =
TARGET_SO     = $(TARGET_SO_DIR)$(DLLIB)
CLEANLIBS     = $(TARGET_SO) 
CLEANOBJS     = *.o  *.bak


all:    $(DLLIB)
static: $(STATIC_LIB) install-rb
.PHONY: all install static install-so install-rb
.PHONY: clean clean-so clean-static clean-rb

clean-static::
clean-rb-default::
clean-rb::
clean-so::
clean: clean-so clean-static clean-rb-default clean-rb
		-$(Q)$(RM) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES) .*.time

distclean-rb-default::
distclean-rb::
distclean-so::
distclean-static::
distclean: clean distclean-so distclean-static distclean-rb-default distclean-rb
		-$(Q)$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		-$(Q)$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)
		-$(Q)$(RMDIRS) $(DISTCLEANDIRS) 2> /dev/null || true

realclean: distclean
install: install-so install-rb

install-so: $(DLLIB) $(TIMESTAMP_DIR)/.sitearchdir.-.rubyOF.time
	$(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
clean-static::
	-$(Q)$(RM) $(STATIC_LIB)
install-rb: pre-install-rb do-install-rb install-rb-default
install-rb-default: pre-install-rb-default do-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
do-install-rb:
do-install-rb-default:
pre-install-rb-default:
	@$(NULLCMD)
$(TIMESTAMP_DIR)/.sitearchdir.-.rubyOF.time:
	$(Q) $(MAKEDIRS) $(@D) $(RUBYARCHDIR)
	$(Q) $(TOUCH) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

.SUFFIXES: .c .m .cc .mm .cxx .cpp .o .S

.cc.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cc.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.mm.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.mm.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.cxx.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cxx.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.cpp.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cpp.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.c.o:
	$(ECHO) compiling $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.c.S:
	$(ECHO) translating $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.m.o:
	$(ECHO) compiling $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.m.S:
	$(ECHO) translating $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

$(TARGET_SO): $(OBJS) Makefile
	$(ECHO) linking shared-object rubyOF/$(DLLIB)
	-$(Q)$(RM) $(@)
	$(Q) $(LDSHAREDXX) -o $@ $(OBJS) $(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): $(HDRS) $(ruby_headers)
