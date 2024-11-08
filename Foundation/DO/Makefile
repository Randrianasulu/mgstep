#
#	Distributed Objects Makefile
# 
TOP = ../..

#
#	Lib mdo Files
# 
OBJS = $(DO_OBJS)

DO_OBJS = \
NSPort.o \
NSPortMessage.o \
NSPortNameServer.o \
NSPortCoder.o \
NSProxy.o \
NSDistantObject.o \
NSConnection.o \
Stream.o \
FileHandle.o \


LIBRARY = $(DO_LIBRARY)

#
#	List of Tools to build
# 
TOOLS = $(DO_TOOLS)

DO_TOOLS = \
client \
server \
domap

#
#	Include Makefiles 
# 
include $(TOP)/Build/library.make
include $(TOP)/Build/tool.make
