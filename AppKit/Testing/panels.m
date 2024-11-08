/*
   panels.m

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	December 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


@interface Controller : NSObject
@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

- (void) buttonAction1:(id)sender
{
	int result;

	NSLog (@"buttonAction1:");
	
	result = NSRunAlertPanel(@"A Title",
							 @"Some message text",
							 @"default",
							 @"alternate",
							 @"other");
	switch(result)
		{
		case NSAlertDefaultReturn:	 NSLog (@"NSAlertDefaultReturn:");	break;
		case NSAlertAlternateReturn: NSLog (@"NSAlertAlternateReturn:");break;
		case NSAlertOtherReturn:	 NSLog (@"NSAlertOtherReturn:");	break;
		case NSAlertErrorReturn:	 NSLog (@"NSAlertErrorReturn:");	break;
		}
}

- (void) buttonAction2:(id)sender
{
	[[NSColorPanel sharedColorPanel] display];
	[[NSColorPanel sharedColorPanel] orderFront:self];
}

- (void) buttonAction3:(id)sender
{
	[[NSFontPanel sharedFontPanel] display];
	[[NSFontPanel sharedFontPanel] orderFront:self];
}

- (void) buttonAction4:(id)sender
{
	NSPanel *p;
	NSKeyedArchiver *a;

	NSLog (@"buttonAction4:");
	
	p = NSGetAlertPanel(@"A Title",
						@"Some message text",
						@"default",
						@"alternate",
						@"other");
	a = [NSKeyedArchiver new];
	[a encodeRootObject: p withName: @"AlertPanel"];
	[a writeToFile: @"archivedPanel"];
	[a release];
}

- (void) buttonAction5:(id)sender
{
	NSLog (@"buttonAction5:");

	[[NSSavePanel savePanel] runModal];
}

- (void) buttonAction6:(id)sender
{
	NSLog (@"buttonAction6:");

	[[NSOpenPanel openPanel] runModal];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *win;
	NSRect wf = {{650, 300}, {200, 300}};
	NSView *v;
	NSRect bf = {{10, 210}, {80, 80}};
	id button;

	NSLog(@"Starting the application\n");
	
	win = [[NSWindow alloc] initWithContentRect: wf
							styleMask: _NSCommonWindowMask
							backing: NSBackingStoreBuffered  
							defer: NO];
	
	[win setTitle: @"mGSTEP Alert panel"];
	
	v = [win contentView];
	
	NSLog(@"Create the panel buttons\n");
	
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Std Panel"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction1:)];
	[v addSubview: button];
	[button release];
	
	bf.origin.x += 100;
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Color Panel"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction2:)];
	[v addSubview: button];
	[button release];
	
	bf.origin.y -= 100;
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Make archive"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction4:)];
	[v addSubview: button];
	[button release];
	
	bf.origin.x -= 100;
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Font Panel"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction3:)];
	[v addSubview: button];
	[button release];
	
	bf.origin.y -= 100;
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Save panel"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction5:)];
	[v addSubview: button];
	[button release];
	
	bf.origin.x += 100;
	button = [[NSButton alloc] initWithFrame: bf];
	[button setTitle: @"Open Panel"];
	[button setTarget:self];
	[button setAction:@selector(buttonAction6:)];
	[v addSubview: button];
	[button release];

	[v display];
	[win orderFront: nil];

	[self buttonAction3:nil];
}

@end

int
main(int argc, const char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
