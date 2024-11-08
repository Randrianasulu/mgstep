#
#	Makefile for PNG plugin
# 
#
TOP = ../../..

LIBS = -lpng16

# Bundles to be built
BUNDLES = PNG

# Bundle Principal class
PNG_PRINCIPAL_CLASS = _NSBitmapImageRepPNG

## Files to be compiled for each bundle
PNG_OBJS = png.o


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp PNG.bundle ..

clean::
