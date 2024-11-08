#
#   library.make
#
#   Makefile rules to build mGSTEP libraries.
#
#	Author:	Felipe A. Rodriguez <far@pcmagic.net>
#	Date:	January 1999
#
###############################################################################

#
#	Include Makefiles 
# 
include $(TOP)/Build/rules.make
include $(TOP)/Build/subproject.make

#
#	If TARGET is NULL this is the first pass thru this file.  
#	Set TARGET to the current target and then reinvoke make  
#	to perform the library build rule. 
#
ifeq ($(TARGET),)  ## if TARGET is NULL ##

$(LIBRARY) all::	$(OBJS_DIR)
	@(echo "#")
	@(echo "#  building $(LIBRARY)")
	@(echo "#")
	$(MAKE) $(SHARED_LIB) TARGET='None'
	$(MAKE) $(STATIC_LIB) TARGET='None'

endif             ## endif TARGET is NULL ##

#
#   Library Build Rule
#
# library depends on it's object files (built by suffix rules)
#
$(SHARED_LIB)::	$(OBJS)             # Build shared lib if defined
	cd $(OBJS_DIR); $(BUILD_SHARED_LIB) $(OBJS) $(LD_LIBS);

$(STATIC_LIB)::	$(OBJS)             # Build static lib if defined
	cd $(OBJS_DIR); $(BUILD_STATIC_LIB) $(OBJS); 
