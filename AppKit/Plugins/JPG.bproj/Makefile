#
#	Makefile for JPG plugin
# 
#
TOP = ../../..

LIBS = -ljpeg

# Bundles to be built
BUNDLES = JPG

# Bundle Principal class
JPG_PRINCIPAL_CLASS = _NSBitmapImageRepJPEG

## Files to be compiled for each bundle
JPG_OBJS = jpg.o


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp JPG.bundle ..

clean::
