CC ?= gcc
CFLAGS=-I. -fPIC
RANLIB ?= ranlib

LIB=libkiss.a
LIBDEST=./lib/$(TARGET_DIR)/

LIBSRC=kiss_fft.c tools/kiss_fftr.c

LIBOBJ=$(LIBSRC:.c=.o)

install: $(LIB)
	@echo lib Makefile - installing $(LIB)
	@mkdir -p $(LIBDEST)
	@install -m 644 $(LIB) $(LIBDEST)

$(LIB): $(LIBOBJ)
	@echo lib Makefile - archiving $(LIB)
	@$(AR) r $(LIB) $(LIBOBJ)
	@$(RANLIB) $(LIB)

%.o: %.c
	@echo lib Makefile - compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@



# src: https://github.com/openframeworks/apothecary/blob/4a6a3bd82b1127a02e90bad0986c6394ad407078/apothecary/formulas/kiss/Makefile

# NOTE: There is also a "Makefile.64" version, but that does not work as expected. It does not produce the expected output, and expects a different directory structure. Very odd.

# NOTE: 'clean' task below was added, and so was the -fPIC flag above.


clean:
	rm -f *.o
	rm -f tools/*.o
