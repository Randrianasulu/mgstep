#
#	Makefile for OpenAL plugin
# 
#
TOP = ../../..

LIBS = $(AL_LIBS)

# Bundles to be built
BUNDLES = AL

# Bundle Principal class
AL_PRINCIPAL_CLASS = _NSSoundOpenAL

## Files to be compiled for each bundle
AL_OBJS = al.o

AL_EXTENSION = .audio

#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp AL.audio ..

clean::
	rm -rf *.audio
