#
#   install.make
#
#   Install the mgstep libraries.
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
#	Date:	Sep 2002
#
include Build/config.make

MKDIR = mkdir -p

CF_LIB   = libCoreFoundation$(SHARED_LIB_SUFFIX)
FX_LIB   = libFoundation$(SHARED_LIB_SUFFIX)
DO_LIB   = libmdo$(SHARED_LIB_SUFFIX)
SEC_LIB  = libSecurity$(SHARED_LIB_SUFFIX)
CG_LIB   = libCoreGraphics$(SHARED_LIB_SUFFIX)
CT_LIB   = libCoreText$(SHARED_LIB_SUFFIX)
APPK_LIB = libAppKit$(SHARED_LIB_SUFFIX)
MIB_LIB  = libmib$(SHARED_LIB_SUFFIX)

SECURITY_LIB  = Security/$(OBJS_DIR)/$(SEC_LIB)
CORE_GRAPHICS = CoreGraphics/$(OBJS_DIR)/$(CG_LIB)
CORE_TEXT     = CoreText/$(OBJS_DIR)/$(CT_LIB)
FOUNDATION_CF = CoreFoundation/$(OBJS_DIR)/$(CF_LIB)
FOUNDATION    = Foundation/Source/$(OBJS_DIR)/$(FX_LIB)
FOUNDATION_DO = Foundation/DO/$(OBJS_DIR)/$(DO_LIB)
APPKIT        = AppKit/Source/$(OBJS_DIR)/$(APPK_LIB)
APPKIT_MODEL  = AppKit/Model/$(OBJS_DIR)/$(MIB_LIB)

FC_PATH = Foundation/CharacterSets
FH_PATH = Foundation/Headers
FP_PATH = Foundation/Plugins
AH_PATH = AppKit/Headers
AI_PATH = AppKit/Images
AP_PATH = AppKit/Panels
AN_PATH = AppKit/Plugins

TEMPLATE_DEFAULTS = AppKit/Testing/Workspace/Resources/defaults.plist
TEMPLATE_SERVICES = AppKit/Testing/Resources/services.plist


install::
	$(MKDIR) $(HOME)/.mGSTEP
	- cp $(TEMPLATE_DEFAULTS) $(HOME)/.mGSTEP
	- cp $(TEMPLATE_SERVICES) $(HOME)/.mGSTEP
	echo 'export LD_LIBRARY_PATH=$(DESTDIR)/lib' > $(HOME)/.mGSTEP/exports
	echo 'export MGSTEP_ROOT=$(DESTDIR)'        >> $(HOME)/.mGSTEP/exports

	@(echo "##"; echo "## Installing mGSTEP to $(DESTDIR)"; echo "##")
	$(MKDIR) $(DESTDIR)/lib
	cp $(FOUNDATION)       $(DESTDIR)/lib/$(FX_LIB).$(MGSTEP_VERSION)
	- cp $(FOUNDATION_DO)  $(DESTDIR)/lib/$(DO_LIB).$(MGSTEP_VERSION)
	cp $(FOUNDATION_CF)    $(DESTDIR)/lib/$(CF_LIB).$(MGSTEP_VERSION)
	cp $(CORE_GRAPHICS)    $(DESTDIR)/lib/$(CG_LIB).$(MGSTEP_VERSION)
	cp $(CORE_TEXT)        $(DESTDIR)/lib/$(CT_LIB).$(MGSTEP_VERSION)
	cp $(SECURITY_LIB)     $(DESTDIR)/lib/$(SEC_LIB).$(MGSTEP_VERSION)
	cp $(APPKIT)           $(DESTDIR)/lib/$(APPK_LIB).$(MGSTEP_VERSION)
	cp $(APPKIT_MODEL)     $(DESTDIR)/lib/$(MIB_LIB).$(MGSTEP_VERSION)
	cd $(DESTDIR)/lib;\
	ln -sf ./$(CF_LIB).$(MGSTEP_VERSION)   $(CF_LIB);\
	ln -sf ./$(FX_LIB).$(MGSTEP_VERSION)   $(FX_LIB);\
	ln -sf ./$(DO_LIB).$(MGSTEP_VERSION)   $(DO_LIB);\
	ln -sf ./$(CG_LIB).$(MGSTEP_VERSION)   $(CG_LIB);\
	ln -sf ./$(CT_LIB).$(MGSTEP_VERSION)   $(CT_LIB);\
	ln -sf ./$(SEC_LIB).$(MGSTEP_VERSION)  $(SEC_LIB);\
	ln -sf ./$(APPK_LIB).$(MGSTEP_VERSION) $(APPK_LIB);\
	ln -sf ./$(MIB_LIB).$(MGSTEP_VERSION)  $(MIB_LIB)

	$(MKDIR) $(DESTDIR)/Security
	$(MKDIR) $(DESTDIR)/CoreText
	$(MKDIR) $(DESTDIR)/CoreGraphics/Private
	$(MKDIR) $(DESTDIR)/CoreFoundation
	install -m 644 CoreFoundation/C*.h  $(DESTDIR)/CoreFoundation
	install -m 644 CoreGraphics/C*.h    $(DESTDIR)/CoreGraphics
	install -m 644 CoreText/C*.h        $(DESTDIR)/CoreText
	install -m 644 Security/S*.h        $(DESTDIR)/Security
	install -m 644 CoreGraphics/Private/[_PX]*.h $(DESTDIR)/CoreGraphics/Private

	$(MKDIR) $(DESTDIR)/$(FC_PATH)
	$(MKDIR) $(DESTDIR)/$(FH_PATH)
	$(MKDIR) $(DESTDIR)/$(FP_PATH)
	(cd $(FH_PATH); tar cf - .) | (cd $(DESTDIR)/$(FH_PATH); tar xfp -)
	(cd $(FC_PATH); cp -r *.dat    $(DESTDIR)/$(FC_PATH))
	(cd $(FP_PATH); tar cf - *.bundle) | (cd $(DESTDIR)/$(FP_PATH); tar xfp -)

	$(MKDIR) $(DESTDIR)/$(AP_PATH)
	$(MKDIR) $(DESTDIR)/$(AH_PATH)
	$(MKDIR) $(DESTDIR)/$(AI_PATH)
	$(MKDIR) $(DESTDIR)/$(AN_PATH)
	(cd $(AH_PATH); tar cf - .) | (cd $(DESTDIR)/$(AH_PATH); tar xfp -)
	(cd $(AI_PATH); tar cf - .) | (cd $(DESTDIR)/$(AI_PATH); tar xfp -)
	(cd $(AP_PATH); tar cf - .) | (cd $(DESTDIR)/$(AP_PATH); tar xfp -)
	(cd $(AN_PATH); tar cf - *.bundle) | (cd $(DESTDIR)/$(AN_PATH); tar xfp -)
	(cd $(AN_PATH); tar cf - *.audio)  | (cd $(DESTDIR)/$(AN_PATH); tar xfp -)

	cp -r Build $(DESTDIR)
	cp  .config $(DESTDIR)
	$(MKDIR) $(DESTDIR)/{bin,sbin}
	install -m 700 Foundation/DO/domap   $(DESTDIR)/sbin
	- install AppKit/Testing/open        $(DESTDIR)/bin
	- install AppKit/Testing/playa       $(DESTDIR)/bin
	- install AppKit/Testing/defaults    $(DESTDIR)/bin
	- install AppKit/Testing/run         $(DESTDIR)/bin
	sed -e "s#MGSTEP = .*#MGSTEP = $(DESTDIR)#g" \
		-e 's#-L$$(MGSTEP)/Foundation/DO.*#-L$$(MGSTEP)/lib#' \
		-e 's#-L$$(MGSTEP)/F.*##' -e 's#-L$$(MGSTEP)/A.*##' \
		-e 's#-L$$(MGSTEP)/C.*##' -e 's#-L$$(MGSTEP)/S.*##' \
			Build/config.make > $(DESTDIR)/Build/config.make

export::
	echo "export MGSTEP_ROOT=$(MGSTEP)" > ld-export
	echo "export LD_LIBRARY_PATH=$(MGSTEP)/CoreFoundation/$(OBJS_DIR):$(MGSTEP)/Foundation/DO/$(OBJS_DIR):$(MGSTEP)/Foundation/Source/$(OBJS_DIR):$(MGSTEP)/Security/$(OBJS_DIR):$(MGSTEP)/CoreGraphics/$(OBJS_DIR):$(MGSTEP)/CoreText/$(OBJS_DIR):$(MGSTEP)/AppKit/Model/$(OBJS_DIR):$(MGSTEP)/AppKit/Source/$(OBJS_DIR)" >> ld-export

install_links::
	@(echo "##"; echo "## Installing mGSTEP links in $(DESTDIR)"; echo "##")
	$(MKDIR) $(DESTDIR)/lib
	ln -s $(PWD)/$(FOUNDATION)     $(DESTDIR)/lib/libFoundation.so
	ln -s $(PWD)/$(FOUNDATION_DO)  $(DESTDIR)/lib/libmdo.so
	ln -s $(PWD)/$(FOUNDATION_CF)  $(DESTDIR)/lib/libCoreFoundation.so
	ln -s $(PWD)/$(SECURITY_LIB)   $(DESTDIR)/lib/$(SEC_LIB)
	ln -s $(PWD)/$(CORE_GRAPHICS)  $(DESTDIR)/lib/libCoreGraphics.so
	ln -s $(PWD)/$(CORE_TEXT)      $(DESTDIR)/lib/libCoreText.so
	ln -s $(PWD)/$(APPKIT)         $(DESTDIR)/lib/libAppKit.so
	ln -s $(PWD)/$(APPKIT_MODEL)   $(DESTDIR)/lib/libmib.so

install_user::
	$(MKDIR) $(HOME)/.mGSTEP
	- cp $(TEMPLATE_DEFAULTS) $(HOME)/.mGSTEP
	- cp $(TEMPLATE_SERVICES) $(HOME)/.mGSTEP

