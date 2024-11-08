#
#   rules.make
#
#   Common makefile rules.
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
#	Date:	January 1999
#
###############################################################################

#
#	Include Makefiles 
# 
include $(TOP)/Build/config.make


AM_V = @		# Laconic

ifeq ($(V),1)	# Verbose
AM_V =
endif

#
# Suffix Rules
#
.SUFFIXES : .o .c .m .mm .cc .cpp

.m.o::
	$(AM_V) echo ' CM ' $*; cd $(OBJS_DIR); $(CC) -c -MD $(CMFLAGS) ../$< -o $*.o

.mm.o::
	$(AM_V) echo ' CMM ' $*; cd $(OBJS_DIR); $(CXX) -c -MD $(CMFLAGS) ../$< -o $*.o

.cc.o::
	$(AM_V) echo ' CXX ' $*; cd $(OBJS_DIR); $(CXX) -c -MD $(CXXFLAGS) ../$< -o $*.o

.cpp.o::
	$(AM_V) echo ' CXX ' $*; cd $(OBJS_DIR); $(CXX) -c -MD $(CXXFLAGS) ../$< -o $*.o

.c.o::
	$(AM_V) echo ' CC ' $*; cd $(OBJS_DIR); $(CC) -c -MD $(CFLAGS) ../$< -o $*.o

#
# General Rules
#
.PHONY:	all install clean distclean pkg dummy_target tests

all::

clean::
	rm -rf $(OBJS_DIR)
	rm -rf *~ *.o *.a *.bundle *.dat *.app *.exe core.* core *.dll *.service

$(OBJS_DIR)::
	mkdir -p  $(OBJS_DIR)

#
# Include depend
#
D_OBJECTS = $($(TARGET)_OBJS) $(OBJS)
OBJS_D = $(wildcard $(D_OBJECTS:%.o=$(OBJS_DIR)/%.d))

ifneq ($(OBJS_D),)
-include $(OBJS_D)
endif
