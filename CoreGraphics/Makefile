#
#	CoreGraphics Makefile
#
TOP = ..

#
#	CoreGraphics objects
#
OBJS = \
CGBase.o \
CGBlend.o \
CGColor.o \
CGContext.o \
CGContextPath.o \
CGContextRaster.o \
CGDirectDisplay.o \
CGFilter.o \
CGFont.o \
CGImage.o \
CGLayer.o \
CGPath.o \
CGPathConvert.o \
CGPostscript.o \
CGRender.o \
CGShading.o \
_CGContextCairo.o \
_CGContextFB.o \
_CGContextX11.o \
_CGEventFB.o \
_CGEventX11.o \
_CGWindowFB.o \
_CGWindowX11.o \


LIBRARY = libCoreGraphics


#
#	Include Makefiles
#
include $(TOP)/Build/library.make


#
# General Rules
#
clean::
	- rm cgtest

cgtest::  $(OBJS_DIR)  cgtest.o
	cd $(OBJS_DIR); $(CC) $(LFLAGS) -o ../cgtest cgtest.o $(LIBS) $(APP_LIBS)
