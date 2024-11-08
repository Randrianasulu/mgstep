#
#	AppKit tests Makefile
# 
TOP = ../..

# Example applications that have their own directory
SUBPROJECTS = Workspace Edit

# Applications to be built
APPS = \
buttons \
fonts \
layer \
lines \
tableview \
matrix \
scrollview \
combo \
model \
nsbrowser \
example \
coord \
quartz \
panels \
pattern \
plot \
Alert \
Viewer \

# List of Tools to build
TOOLS = \
defaults \
open \
playa

# Files to be compiled for each application
buttons_OBJS = buttons.o
combo_OBJS = combo.o
coord_OBJS = coord.o
example_OBJS = example.o
fonts_OBJS = fonts.o
layer_OBJS = layer.o
lines_OBJS = lines.o
matrix_OBJS = matrix.o
model_OBJS = model.o Controller.o
nsbrowser_OBJS = nsbrowser.o
quartz_OBJS = quartz.o
panels_OBJS = panels.o
pattern_OBJS = pattern.o
plot_OBJS = plot.o
scrollview_OBJS = scrollview.o
tableview_OBJS = tableview.o Controller.o
text_OBJS = text.o
Alert_OBJS = Alert.o
Viewer_OBJS = Viewer.o Controller.o

$(TARGET)_PRINCIPAL_CLASS = Controller
example_PRINCIPAL_CLASS = ""


# Resource files to be copied into each app's resources directory
buttons_RESOURCES = Resources/Glyphter.ttf

combo_RESOURCES = \
Resources/host.tiff \
Resources/meter.tiff

coord_RESOURCES = \
Resources/g4.tiff \
Resources/select.tiff

layer_RESOURCES = Resources/g0.tiff

tableview_RESOURCES = Resources/data.plist

Viewer_RESOURCES = \
Resources/g0.tiff \
Resources/g4.tiff

Viewer_ICON = g0.tiff

#
#	Include Makefiles 
# 
include $(TOP)/Build/app.make
include $(TOP)/Build/tool.make
include $(TOP)/Build/subproject.make


open_LIBS     := $(APP_LIBS)
playa_LIBS    := $(APP_LIBS)


example::
	if [ -d ./example.app ]; then \
	    rm -rf ./example.service; \
	    mv ./example.app ./example.service; \
	fi
