/*
   Workspace.m

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include "Controller.h"


@implementation Controller (AppDelegate)

- (void) createMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Workspace"];
	NSMenu *info = [NSMenu new];
	NSMenu *file = [NSMenu new];
	NSMenu *edit = [NSMenu new];
	NSMenu *windows = [NSMenu new];
	NSMenu *view = [NSMenu new];
	NSMenu *tools = [NSMenu new];
	SEL a = @selector(method:);

	[menu addItemWithTitle:@"Workspace" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"File" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"Edit" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"View" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"Tools" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"Windows" action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"Help" action:a keyEquivalent:@"?"];
	
	[menu setSubmenu:info forItem:[menu itemWithTitle:@"Workspace"]];
	[info addItemWithTitle:@"About" action:@selector(openAboutPanel:) keyEquivalent:@""];
	[info addItemWithTitle:@"Preferences..." action:a keyEquivalent:@""];
	[info addItemWithTitle:@"Services" action:a keyEquivalent:@""];
	[info addItemWithTitle:@"Hide" action:@selector(hide:) keyEquivalent:@"h"];
	[info addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	
	[file addItemWithTitle:@"Open..." action:@selector(openFile:) keyEquivalent:@"o"];
	[file addItemWithTitle:@"Open Folder..." 
		  action:@selector(openFolder:)
		  keyEquivalent:@"O"];
	[file addItemWithTitle:@"New Folder..." action:a keyEquivalent:@"n"];
	[file addItemWithTitle:@"Duplicate" action:@selector(duplicate:) keyEquivalent:@"d"];
	[file addItemWithTitle:@"Compress" action:a keyEquivalent:@""];
	[file addItemWithTitle:@"Destroy" action:@selector(destroy:) keyEquivalent:@"r"];
	[file addItemWithTitle:@"Empty Recycler" action:a keyEquivalent:@""];
	[file addItemWithTitle:@"Print" action:a keyEquivalent:@"p"];
	[menu setSubmenu:file forItem:[menu itemWithTitle:@"File"]];
	
	[edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
	[edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
	[edit addItemWithTitle:@"Paste" 
		  action:@selector(paste:) 
		  keyEquivalent:@"v"];
	[edit addItemWithTitle:@"Delete" 
		  action:@selector(delete:) 
		  keyEquivalent:@""];
	[edit addItemWithTitle:@"Select All" 
		  action:@selector(selectAll:) 
		  keyEquivalent:@"a"];
	[menu setSubmenu:edit forItem:[menu itemWithTitle:@"Edit"]];

	[view addItemWithTitle:@"New" action:NULL keyEquivalent:@""];
	[view addItemWithTitle:@"Update" 
		  action:@selector(updateViewer:)
		  keyEquivalent:@""];
	[view addItemWithTitle:@"Toggle"
		  action:@selector(toggleView:)
		  keyEquivalent:@""];
	[menu setSubmenu:view forItem:[menu itemWithTitle:@"View"]];

	[tools addItemWithTitle:@"Inspector" action:NULL keyEquivalent:@""];
	[tools addItemWithTitle:@"Finder" action:@selector(openFinder:) keyEquivalent:@"f"];
	[tools addItemWithTitle:@"Tasks..." action:NULL keyEquivalent:@""];
	[tools addItemWithTitle:@"XTerm" action:@selector(openXTerm:) keyEquivalent:@""];
	[menu setSubmenu:tools forItem:[menu itemWithTitle:@"Tools"]];

//	[go addItemWithTitle:@"Connect server..." action:a keyEquivalent:@"n"];
//	[menu setSubmenu:go forItem:[menu itemWithTitle:@"Go"]];

	[windows addItemWithTitle:@"Arrange" 
			 action:@selector(arrangeInFront:) 
			 keyEquivalent:@""];
	[windows addItemWithTitle:@"Miniaturize" action:a keyEquivalent:@"m"];
	[windows addItemWithTitle:@"Close" action:a keyEquivalent:@"w"];
	[menu setSubmenu:windows forItem:[menu itemWithTitle:@"Windows"]];

	[NSApp setMainMenu:menu];
	[NSApp setServicesMenu: nil];
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];
	[self createMenu];

	return self;
}

@end


int
main(int argc, const char **argv, char **env)
{
    return NSApplicationMain(argc, argv);
}
