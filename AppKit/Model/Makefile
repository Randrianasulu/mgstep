#
#	AppKit mib Makefile 
# 
TOP = ../..

#
#	Lib mib Files
# 
OBJS = \
IMConnectors.o \
IMLoading.o \
IMKeyedArchiving.o \
IMModelArchiving.o \
NSKeyedArchiver.o \
NSNibLoading.o \
NSNibConnectors.o \
NSKeyValueCoding.o \

LIBRARY = libmib

#
#	List of Tools to build
# 
TOOLS = \
test

test_OBJS = test.o Controller.o 


NO_OSX = YES

#
#	Include Makefiles 
# 
include $(TOP)/Build/library.make
include $(TOP)/Build/tool.make


LIBS := $(APP_LIBS) $(LIBS)
CMFLAGS := -I.. -I../.. $(CMFLAGS)
