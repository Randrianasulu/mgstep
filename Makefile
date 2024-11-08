#
#	mGSTEP Makefile
#
#	Author:	Felipe A. Rodriguez <far@illumenos.com>
#	Date:	January 1999
#
###############################################################################

MAJOR_VERSION = 2
MINOR_VERSION = 07
MGSTEP_VERSION = $(MAJOR_VERSION).$(MINOR_VERSION)

CONFIGURE = Build/scripts/configure
CONFIG_MK = Build/config.make
CONFIG = .config

INSTALL_PATH = /usr/local/mGSTEP


all::	$(CONFIG_MK) $(CONFIG)
	cd CoreFoundation;      $(MAKE) all
	cd Security;            $(MAKE) all
	cd Foundation/Source;   $(MAKE) all
	- cd Foundation/DO;     $(MAKE) all
	cd Foundation/Plugins;  $(MAKE) all
	cd CoreGraphics;        $(MAKE) all
	cd CoreText;            $(MAKE) all
	cd AppKit/Source;       $(MAKE) all
	cd AppKit/Model;        $(MAKE) all
	cd AppKit/Plugins;      $(MAKE) all

config  $(CONFIG_MK) $(CONFIG):
	@($(CONFIGURE) $(MAJOR_VERSION) $(MINOR_VERSION))

tests::
	cd Foundation/Testing;  $(MAKE) all
	cd AppKit/Testing;      $(MAKE) all

export::
	@(echo "##"; echo "## Exporting mGSTEP environment"; echo "##";\
	$(MAKE) -f Build/install.make export;)

install::
	@(echo "##"; echo "## Installing mGSTEP"; echo "##";)
	@(echo '   Install path: [$(INSTALL_PATH)]';/bin/echo -n "> "; read REPLY;\
	  if [ "$$REPLY" = "" ]; then REPLY="$(INSTALL_PATH)"; fi; \
	  $(MAKE) -f Build/install.make install DESTDIR="$$REPLY";)

install_links::
	@(echo "##"; echo "## Installing mGSTEP"; echo "##";)
	@(echo '   Install path: [$(INSTALL_PATH)]';/bin/echo -n "> "; read REPLY;\
	  if [ "$$REPLY" = "" ]; then REPLY="$(INSTALL_PATH)"; fi; \
	  $(MAKE) -f Build/install.make install_links DESTDIR="$$REPLY";)

install_user::
	@(echo "##"; echo "## Installing .mGSTEP user home: $(HOME)"; echo "##";\
	$(MAKE) -f Build/install.make install_user;)

clean::
	cd CoreFoundation;      $(MAKE) clean
	cd Security;            $(MAKE) clean
	cd Foundation/Source;   $(MAKE) clean
	cd Foundation/DO;       $(MAKE) clean
	cd Foundation/Plugins;  $(MAKE) clean
	cd CoreGraphics;        $(MAKE) clean
	cd CoreText;            $(MAKE) clean
	cd AppKit/Source;       $(MAKE) clean
	cd AppKit/Model;        $(MAKE) clean
	cd AppKit/Plugins;      $(MAKE) clean
	cd Foundation/Testing;  $(MAKE) clean;	$(MAKE) distclean
	cd AppKit/Testing;      $(MAKE) clean

distclean::
	- rm $(CONFIG) $(CONFIG)-tmp ld-export
	$(MAKE) clean
	- rm $(CONFIG_MK)
	- rm Build/config.h

pkg::
	PKG="mgstep" PKG_VERSION=$(MGSTEP_VERSION)  Build/scripts/pkg
