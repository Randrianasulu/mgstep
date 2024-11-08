#
#	Makefile for Workspace
# 
TOP = ../../..

LIBS := -lutil

# Applications to be built
APPS = \
Workspace \

# Files to be compiled for each application
Workspace_OBJS = \
Workspace.o \
Cell.o \
Browser.o \
Matrix.o \
FileManager.o \
Finder.o \
WindowShelf.o \
Controller.o

$(TARGET)_PRINCIPAL_CLASS = Controller

# Resource files to be copied into the app's resources directory
Workspace_RESOURCES = \
Resources/folder.tiff \
../Resources/host.tiff \
../Resources/select.tiff \
../Edit/Resources/text.tiff \
../Edit/Resources/rtf.tiff \
../Edit/Resources/rtfd.tiff \

Workspace_ICON = cabinet.tiff

#
#	Include Makefiles 
# 
include $(TOP)/Build/app.make


all::
	if [ -L ../Workspace.app ]; then \
		rm ../Workspace.app; \
	fi
	if [ -d ./Resources ]; then \
	    cp ./Resources/*.tiff ./Workspace.app/Resources; \
	fi
	if [ -d ./Workspace.app ]; then \
	    cd ..; ln -s Workspace/Workspace.app .; \
	fi
