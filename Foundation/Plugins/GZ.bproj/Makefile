#
#	Makefile for zlib plugin
# 
#
TOP = ../../..

LIBS = -lz

# Bundles to be built
BUNDLES = GZ

# Bundle Principal class
GZ_PRINCIPAL_CLASS = NSData

## Files to be compiled for each bundle
GZ_OBJS = zlib.o


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp GZ.bundle ..

clean::
