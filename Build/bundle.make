#
#   bundle.make
#
#   Makefile rules to build mGSTEP bundles.
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
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
#	to perform the bundle build rule. 
#
ifeq ($(TARGET),)   ## if TARGET is NULL ##
ifneq ($(BUNDLES),) ## if BUNDLES are defined ##

all bundles:: $(BUNDLES)

##	rule which creates bundles. 
$(BUNDLES)::	$(OBJS_DIR)
	@(echo "#";\
	  echo "#  building $@ bundle";\
	  echo "#";\
	if [ "$($(@)_EXTENSION)" = "" ]; then \
	  $(MAKE) Wrapper BUNDLE_EXT='.bundle' TARGET=$@; \
	  $(MAKE) $@.bundle BUNDLE=$@.bundle TARGET=$@; \
	  $(MAKE) Resources BUNDLE_NAME='$@' BUNDLE_EXT='.bundle' TARGET=$@; \
	else \
	  $(MAKE) Wrapper BUNDLE_EXT='$($(@)_EXTENSION)' TARGET=$@;\
	  $(MAKE) $@$($(@)_EXTENSION) BUNDLE=$@$($(@)_EXTENSION) TARGET=$@; \
	  $(MAKE) Resources BUNDLE_EXT='$($(@)_EXTENSION)' TARGET=$@; \
	fi;)

endif             ## endif BUNDLES are defined ##
endif             ## endif TARGET is NULL ##

#
#	Bundle build rule
#
##	Bundle depends on bundle binary within bundle wrapper directory
$(BUNDLE):: $(BUNDLE)/$(TARGET)

##	Bundle binary depends on bundle's source files
$(BUNDLE)/$(TARGET)::  $($(TARGET)_OBJS)
	cd $(OBJS_DIR);\
	$(CC) $(BUNDLE_CFLAGS) -o ../$(BUNDLE)/$(TARGET) $($(TARGET)_OBJS) $(LFLAGS) $(LIBS)

#
# Create bundle wrapper, Resources directory and Info.plist file
#
Wrapper::  $(OBJS_DIR)
	mkdir -p  $(TARGET)$(BUNDLE_EXT)/Resources
	@(echo "{"; echo '	NOTE = "Automatically generated, do not edit!";'; \
	  echo "	NSExecutable = \"$(TARGET)\";"; \
	  if [ "$(MAIN_MODEL_FILE)" = "" ]; then \
	    	echo "	NSMainNibFile = \"\";"; \
	  else \
	    	echo "	NSMainNibFile = \"`echo $(MAIN_MODEL_FILE)`\";";\
	  fi; \
	  if [ "$($(TARGET)_ICON)" = "" ]; then \
			echo "	NSIcon = \"$(TARGET).tiff\";"; \
	  else \
			echo "	NSIcon = \"$($(TARGET)_ICON)\";"; \
	  fi; \
	  if [ "$($(TARGET)_PRINCIPAL_CLASS)" = "" ]; then \
			if [ "$(BUNDLE_EXT)" = ".app" ]; then \
				echo "	NSPrincipalClass = \"NSApplication\";"; \
			else \
				echo "	NSPrincipalClass = \"$(TARGET)\";"; \
			fi; \
	  else \
	  		echo "	NSPrincipalClass = \"$($(TARGET)_PRINCIPAL_CLASS)\";"; \
	  fi; \
	  echo "}") >$(TARGET)$(BUNDLE_EXT)/Resources/Info.plist
	@(if [ ! "$(MAIN_MODEL_FILE)" = "" ] && [ -f "$(MAIN_MODEL_FILE)" ]; then \
		cp -rp $(MAIN_MODEL_FILE) $(TARGET)$(BUNDLE_EXT)/Resources; \
	fi;)

##	resources depend on having some defined
Resources:: $($(TARGET)_RESOURCES)

##	If resources are defined copy them into the bundle's resources directory
$($(TARGET)_RESOURCES)::
	@(if [ -d $(TARGET)$(BUNDLE_EXT)/Resources/$@ ]; then \
		rm -rf $(TARGET)$(BUNDLE_EXT)/Resources/$@; \
	fi; \
	cp -r ''$@'' $(TARGET)$(BUNDLE_EXT)/Resources;)

