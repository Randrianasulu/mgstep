#
#	CoreText Makefile
#
TOP = ..

FT_CFLAGS = -I../FreeType/include -DFT2_BUILD_LIBRARY=1
FT_LIBS = -lpng16

#
#	Embedded FreeType objects
#
FT_OBJS = \
FreeType/truetype/truetype.o \
FreeType/raster/raster.o \
FreeType/pcf/pcf.o \
FreeType/base/ftbase.o \
FreeType/sfnt/sfnt.o \
FreeType/autofit/autofit.o \
FreeType/smooth/smooth.o \


#
#	CoreText objects
#
OBJS = \
CTFont.o \
$(FT_OBJS_DEF)


LIBRARY = libCoreText

#
#	Include Makefiles
#
include $(TOP)/Build/library.make


#
# General Rules
#
clean::
	- rm cttest

cttest::  $(OBJS_DIR)  cttest.o
	cd $(OBJS_DIR); $(CC) $(LFLAGS) -o ../cttest cttest.o $(LIBS) $(APP_LIBS)

$(OBJS_DIR)::
	mkdir -p  $(OBJS_DIR)/FreeType/truetype $(OBJS_DIR)/FreeType/raster \
			  $(OBJS_DIR)/FreeType/pcf      $(OBJS_DIR)/FreeType/base \
			  $(OBJS_DIR)/FreeType/sfnt     $(OBJS_DIR)/FreeType/autofit \
			  $(OBJS_DIR)/FreeType/smooth
