#
#	Makefile for https plugin
# 
#
TOP = ../../..

LIBS = -lSecurity $(SSL_LIBS)

# Bundles to be built
BUNDLES = HTTPS

# Bundle Principal class
HTTPS_PRINCIPAL_CLASS = _NSURLProtocolHTTPS

## Files to be compiled for each bundle
HTTPS_OBJS = https.o


#
#	Include Makefiles 
# 
include $(TOP)/Build/bundle.make


#
# General Rules
#
all::
	cp -rp HTTPS.bundle ..

clean::
