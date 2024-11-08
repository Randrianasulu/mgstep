#
#   subproject.make
#
#   Makefile rules to build mGSTEP subprojects.
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
#	Date:	January 1999
#
###############################################################################

#
#	If TARGET is NULL this is the first pass thru this file.  
#
ifeq ($(TARGET),) 		## if TARGET is NULL ##

#
#	Include Makefiles 
# 
include $(TOP)/Build/rules.make


ifneq ($(SUBPROJECTS),)	## if SUBPROJECTS are defined ##

#	If subprojects are defined build them
all::	
	@(for subproj in $(SUBPROJECTS); do \
		echo "#"; \
		echo "#  building $$subproj subproject"; \
		echo "#"; \
		cd ''$$subproj''; $(MAKE) all; \
		cd -; \
	done)

#	build subprojects individually (eg. make mySubproject)
$(SUBPROJECTS)::
		cd $@; $(MAKE) all;

clean::
	@(for subproj in $(SUBPROJECTS); do \
		echo "#"; \
		echo "#  cleaning $$subproj subproject"; \
		echo "#"; \
		cd ''$$subproj''; $(MAKE) clean; \
		cd -; \
	done)

endif ## endif SUBPROJECTS are defined ##
endif ## endif TARGET is NULL ##
