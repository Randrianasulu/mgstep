#
#	Makefile for Edit
# 
TOP = ../../..

# Applications to be built
APPS = \
Edit \

# Files to be compiled for each application
Edit_OBJS = \
Edit.o \
Document.o \
DocumentReadWrite.o \
TextFinder.o \
Controller.o

$(TARGET)_PRINCIPAL_CLASS = Controller

# Resource files to be copied into the app's resources directory
Edit_RESOURCES = Resources/text.tiff $(TOP)/README Resources/Edit.tiff \
					
#
#	Include Makefiles 
# 
include $(TOP)/Build/app.make


all::
	if [ -L ../Edit.app ]; then \
		rm ../Edit.app; \
	fi								
	if [ -d ./Edit.app ]; then \
	    cd ..; ln -s Edit/Edit.app .; \
	fi
