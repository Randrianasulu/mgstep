#
#	Makefile for Ogg/Vorbis plugin
# 
#
TOP = ../../..

LIBS = $(OGG_LIBS)

# Bundles to be built
BUNDLES = OGG

# Bundle Principal class
OGG_PRINCIPAL_CLASS = _NSSoundOgg

## Files to be compiled for each bundle
OGG_OBJS = ogg.o

OGG_EXTENSION = .audio

#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp OGG.audio ..

clean::
	rm -rf *.audio
