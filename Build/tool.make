#
#   tool.make
#
#   Makefile rules to build mGSTEP tools.
#
#	Author:	Felipe A. Rodriguez <far@pcmagic.net>
#	Date:	January 1999
#
###############################################################################

#
#	Include Makefiles 
# 
include $(TOP)/Build/rules.make

#
#	If TARGET is NULL this is the first pass thru this file.  
#	Set TARGET to the current target and then reinvoke make  
#	to perform the tool build rule. 
#
ifeq ($(TARGET),)	## if TARGET is NULL ##

all:: $(TOOLS)

dummy_target:
#
# 	Builds tools.  make sure tool depends on at least one object file.
#	if there is no definition of 'foo_OBJS =' assume the tool's name.
#
$(TOOLS)::	$(OBJS_DIR) dummy_target
	@(echo "#"; \
	  echo "#  building $@ tool"; \
	  echo "#"; \
	if [ '$($@_OBJS)' = '' ]; then \
		$(MAKE) $@ TARGET=$@ $@_OBJS=$@.o; \
	else \
		$(MAKE) $@ TARGET=$@; \
	fi)

endif			## endif TARGET is NULL ##

#
#   Tool build rule
#
#	tool depends on it's object files (built by suffix rules)
# 
$(TARGET):: $($(TARGET)_OBJS)
	cd $(OBJS_DIR); $(CC) $(LFLAGS) -o ../$(TARGET) $($(TARGET)_OBJS) $($(TARGET)_LIBS) $(LIBS)

clean::
	rm -rf $(TOOLS)
