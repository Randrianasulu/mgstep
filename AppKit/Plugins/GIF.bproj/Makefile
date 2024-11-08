#
#	Makefile for GIF plugin
# 
#
TOP = ../../..

LIBS = -lgif

# Bundles to be built
BUNDLES = GIF

# Bundle Principal class
GIF_PRINCIPAL_CLASS = _NSBitmapImageRepGIF

## Files to be compiled for each bundle
GIF_OBJS = gif.o


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp GIF.bundle ..

clean::
