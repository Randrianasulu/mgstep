#
#	Foundation tests Makefile
# 
TOP = ../..

# List of tools to build
TOOLS = \
nsarchiver \
nsarray \
nsattributedstring \
nsbundle \
nsdata \
nsdate \
nsdictionary \
nsfilemanager \
nsformatter \
nshashtable \
nshost \
nsindexpath \
nsindexset \
nsmaptable \
nsnotification \
nspointerarray \
nsprocessinfo \
nsscanner \
nsset \
nsserial \
nstask \
nsthread \
nstimer \
string \
nsauto \
values \
nstimezone \
nsinvocation \
cfstring \
mget \
#diningPhilosophers \

# List of bundles to build
BUNDLES = \
LoadMe 

# Files to be compiled for each bundle
LoadMe_OBJS = LoadMe.o

mget_LIBS := -lSecurity

#
#	Include Makefiles 
# 
include $(TOP)/Build/tool.make
include $(TOP)/Build/bundle.make

#
#	Run all of the tests 
# 
run::
	@(LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:../Source/$(OBJS_DIR); \
		export LD_LIBRARY_PATH; \
		for test in $(TOOLS); do \
		echo "#"; \
		echo "#  running $$test test"; \
		echo "#"; \
		./$$test; \
	done)

baseline::
	@(LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:../Source/$(OBJS_DIR); \
		export LD_LIBRARY_PATH; \
		for test in $(TOOLS); do \
		echo "#"; \
		echo "#  running $$test test"; \
		echo "#"; \
		./$$test >$$test.baseline 2>&1 ; \
	done)

regress::
	@(LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:../Source/$(OBJS_DIR); \
		export LD_LIBRARY_PATH; \
		for test in $(TOOLS); do \
		echo "#"; \
		echo "#  running $$test test"; \
		echo "#"; \
		./$$test >$$test.out 2>&1 ; \
		diff -c2 $$test.baseline $$test.out >regress.out && echo passed || \
		echo failed; \
	done)

#
# General Rules
#
distclean::
	rm -rf *.out *.baseline *.json

