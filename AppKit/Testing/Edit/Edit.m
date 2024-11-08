/*
   Edit.m
   
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	July 1998
   
   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>
#import "Controller.h"
#import "Document.h"


@implementation Controller (AppDelegate)

- (void) createMenu
{
	NSMenu *menu = [NSMenu new];
	NSMenu *info = [NSMenu new];
	NSMenu *file = [NSMenu new];
	NSMenu *edit = [NSMenu new];
	NSMenu *find = [NSMenu new];
	NSMenu *form = [NSMenu new];
	NSMenu *services = [NSMenu new];
	NSMenu *windows = [NSMenu new];
	SEL na = @selector(method:);

	[menu addItemWithTitle:@"Info" action:na keyEquivalent:@""];
	[menu addItemWithTitle:@"File" action:na keyEquivalent:@""];
	[menu addItemWithTitle:@"Edit" action:na keyEquivalent:@""];
	[menu addItemWithTitle:@"Format" action:na keyEquivalent:@""];
	[menu addItemWithTitle:@"Windows" action:na keyEquivalent:@""];
	[menu addItemWithTitle:@"Help" action:na keyEquivalent:@"?"];

	[menu setTitle:@"Edit"];
	[menu setSubmenu:info forItem:[menu itemWithTitle:@"Info"]];
	[info addItemWithTitle:@"About" action:@selector(showInfoPanel:) keyEquivalent:@""];
	[info addItemWithTitle:@"Preferences..." action:na keyEquivalent:@""];
	[info addItemWithTitle:@"Services" action:na keyEquivalent:@""];
	[info addItemWithTitle:@"Hide" action:@selector(hide:) keyEquivalent:@"h"];
	[info addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	[info setSubmenu:services forItem:[info itemWithTitle:@"Services"]];

	[file addItemWithTitle:@"Open..." action:@selector(open:)
		  keyEquivalent:@"o"];
	[file addItemWithTitle:@"New" action:@selector(createNew:) 
		  keyEquivalent:@"n"];
	[file addItemWithTitle:@"Save" action:@selector(save:) keyEquivalent:@"s"];
	[file addItemWithTitle:@"Save As..." action:@selector(saveAs:) 
		  keyEquivalent:@"S"];
	[file addItemWithTitle:@"Save All" action:@selector(saveAll:) 
		  keyEquivalent:@""];
	[file addItemWithTitle:@"Revert to Saved" action:@selector(revert:) 
		  keyEquivalent:@"u"];
	[file addItemWithTitle:@"Close" action:na keyEquivalent:@""];
	[file addItemWithTitle:@"Print" action:na keyEquivalent:@"p"];
	[menu setSubmenu:file forItem:[menu itemWithTitle:@"File"]];

	[edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
	[edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
	[edit addItemWithTitle:@"Paste"
		  action:@selector(paste:) 
		  keyEquivalent:@"v"];
	[edit addItemWithTitle:@"Delete"
		  action:@selector(delete:) 
		  keyEquivalent:@""];
	[edit addItemWithTitle:@"Undelete" action:NULL keyEquivalent:@""];
	[edit addItemWithTitle:@"Find" action:na keyEquivalent:@""];
	[edit addItemWithTitle:@"Select All"
		  action:@selector(selectAll:) 
		  keyEquivalent:@"a"];
	[menu setSubmenu:edit forItem:[menu itemWithTitle:@"Edit"]];

	[find addItemWithTitle:@"Find Panel..."
		  action:@selector(orderFrontFindPanel:) 
		  keyEquivalent:@"f"];
	[find addItemWithTitle:@"Find Next" 
		  action:@selector(findNext:) 
		  keyEquivalent:@"g"];
	[find addItemWithTitle:@"Find Previous" 
		  action:@selector(findPrevious:)  
		  keyEquivalent:@"d"];
	[find addItemWithTitle:@"Enter Selection"
		  action:@selector(enterSelection:)
		  keyEquivalent:@"e"];
	[find addItemWithTitle:@"Jump to Selection" action:na keyEquivalent:@"j"];
	[find addItemWithTitle:@"Line Range..." action:na keyEquivalent:@"l"];
	[edit setSubmenu:find forItem:[edit itemWithTitle:@"Find"]];

	[form addItemWithTitle:@"Line Numbers" action:@selector(toggleLineNumbers:)
		  keyEquivalent:@""];
	[form addItemWithTitle:@"Shift Right" action:@selector(shiftRight:)
		  keyEquivalent:@"]"];
	[form addItemWithTitle:@"Shift Left" action:@selector(shiftLeft:)
		  keyEquivalent:@"["];
	[menu setSubmenu:form forItem:[menu itemWithTitle:@"Format"]];

	[windows addItemWithTitle:@"Arrange"
			 action:@selector(arrangeInFront:)
			 keyEquivalent:@""];
	[windows addItemWithTitle:@"Miniaturize"
			 action:@selector(performMiniaturize:)
			 keyEquivalent:@"m"];
	[windows addItemWithTitle:@"Close"
			 action:@selector(performClose:)
			 keyEquivalent:@"w"];
	[menu setSubmenu:windows forItem:[menu itemWithTitle:@"Windows"]];

	[NSApp setMainMenu:menu];								// set main menu
	[NSApp setServicesMenu: services];
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
	[self createMenu];

	return self;
}

@end


int
main(int argc, const char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
