#
#   app.make
#
#   Makefile rules to build mGSTEP apps.
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
#	Date:	January 1999
#
###############################################################################

#
#	If TARGET is NULL this is the first pass thru this file.  
#	Set TARGET to the current target and then reinvoke make  
#	to perform the app build rule. 
#
ifeq ($(TARGET),)  ## if TARGET is NULL ##

all:: $(APPS)	

##	rule which creates apps
$(APPS)::	$(OBJS_DIR)
	@(echo "#";\
	  echo "#  building $@ application";\
	  echo "#";)
	$(MAKE) Wrapper TARGET=$@ BUNDLE_EXT='.app'
	$(MAKE) $@.app APP=$@.app TARGET=$@
	$(MAKE) bundles BUNDLES='$($@_BUNDLES)' TARGET='' APPS=''
	$(MAKE) Resources BUNDLE_NAME='$@' BUNDLE_EXT='.app' TARGET=$@

endif              ## endif TARGET is NULL ##


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
#	App build rule
#
##	App depends on app binary within app wrapper
$(APP):: $(APP)/$(TARGET)

##	App binary depends on app's object files (built by suffix rules)
$(APP)/$(TARGET):: $($(TARGET)_OBJS) 
	cd $(OBJS_DIR);\
	$(CC) -o ../$(APP)/$(TARGET) $($(TARGET)_OBJS) $(LFLAGS) $(APP_LIBS) $(LIBS)

#
#	App bundle build rules
#
##	App bundles depend on having some defined
bundles::

Resources:: $($(BUNDLE_NAME)_BUNDLES)

$($(BUNDLE_NAME)_BUNDLES)::
	@(for bundle in $($(BUNDLE_NAME)_BUNDLES); do \
		cp -r ''$$bundle''.bundle $(BUNDLE_NAME).app/Resources; \
	done)
