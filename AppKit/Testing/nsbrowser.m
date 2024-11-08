/*
   nsbrowser.m
   
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Author:	Scott Christley <scottc@net-community.com>
   Date: 	October 1997
   
   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSFileManager.h>
#import <AppKit/AppKit.h>


@interface PassiveBrowserDelegate : NSObject			// passive row creation

- (int) browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column;
- (void) browser:(NSBrowser *)sender 
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column;
- (NSString *) browser:(NSBrowser *)sender titleOfColumn:(int)column;

@end

@implementation PassiveBrowserDelegate

- (int) browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *files = [fm directoryContentsAtPath: @"/"];

	return [files count];
}

- (void) browser:(NSBrowser *)sender 
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *files = [fm directoryContentsAtPath: @"/"];
	int count = [files count];
	BOOL exists = NO, is_dir = NO;
	NSMutableString *s=[[[NSMutableString alloc] initWithCString:"/"] autorelease];

	if (row >= count)
		return;
	
	[s appendString: [files objectAtIndex: row]];
	exists = [fm fileExistsAtPath: s isDirectory: &is_dir];
	
	if ((exists) && (is_dir))
		[cell setLeaf: NO];
	else
		[cell setLeaf: YES];
	
	[cell setStringValue: [files objectAtIndex: row]];
}

- (NSString *) browser:(NSBrowser *)sender titleOfColumn:(int)column
{
	if (column == 0)
		return @"Column 0";
	if (column == 1)
		return @"Column 1";
	if (column == 2)
		return @"Column 2";

	return @"";
}

@end

@interface ActiveBrowserDelegate : NSObject				// active row creation 

- (void) browser:(NSBrowser*)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix;
- (void) browser:(NSBrowser *)sender 
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column;
@end

@implementation ActiveBrowserDelegate

- (void) browser:(NSBrowser*)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *ptc = [sender pathToColumn: column];
	NSArray *files = [fm directoryContentsAtPath: ptc];
	int i, count = [files count];

	[matrix renewRows:count columns:1];				// create necessary cells
	[matrix sizeToCells];	

	if (count == 0)
		return;

	for (i = 0; i < count; ++i)
		{
		id cell;
		BOOL is_dir = NO;
		NSMutableString *s = [[NSMutableString alloc] initWithString: ptc];

		[s autorelease];

		cell = [matrix cellAtRow: i column: 0];
		[cell setStringValue: [files objectAtIndex: i]];

		[s appendString: @"/"];
		[s appendString: [files objectAtIndex: i]];
		[fm fileExistsAtPath: s isDirectory: &is_dir];

		[cell setLeaf: (!(is_dir))];
		}
}

- (void) browser:(NSBrowser *)sender
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column							{}

- (BOOL) browser:(NSBrowser *)sender
		 selectCellWithString:(NSString *)title
		 inColumn:(int)column						{}

- (BOOL) fileManager:(NSFileManager*)fileManager
		 shouldProceedAfterError:(NSDictionary*)errorDictionary
{  
	return YES;  
}

- (void) fileManager:(NSFileManager*)fileManager
		 willProcessPath:(NSString*)path			{}

@end


@interface Controller : NSObject
@end

@implementation Controller

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	PassiveBrowserDelegate *pbd = [PassiveBrowserDelegate new];
	ActiveBrowserDelegate *abd = [ActiveBrowserDelegate new];
	NSRect winRect = {{100, 100}, {550, 400}};
	NSBrowser *browser;
	NSWindow *window;

	window = [[NSWindow alloc] initWithContentRect:winRect
							   styleMask:_NSCommonWindowMask
							   backing:NSBackingStoreBuffered
							   defer:NO];
	
	browser = [[NSBrowser alloc] initWithFrame: (NSRect){{20,20}, {500,335}}];
	[browser setTitle: @"Column 0" ofColumn: 0];
	[browser setDelegate: abd];
    [browser setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	[browser setMaxVisibleColumns: 3];
	[browser setMinColumnWidth: 150];
	[browser setAllowsMultipleSelection:NO];
	
	[[window contentView] addSubview: browser];
	
	[window setTitle:@"NSBrowser"];
	[window display];
	[window orderFront:nil];
}

@end

int
main(int argc, const char **argv)
{
    return NSApplicationMain(argc, argv);
}
