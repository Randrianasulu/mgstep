/*
   Finder.m

   File system search tool

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	November 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include "Finder.h"
#include "Controller.h"
#include "Matrix.h"
#include "Cell.h"

static Finder *__finder = nil;


@implementation Finder

+ (Finder *) sharedFinder
{
	return (!__finder) ? [Finder new] : __finder;
}

- (id) init
{
	NSRect wr = (NSRect){{50, 50}, {340, 580}};
	NSRect tRect = (NSRect){{50, 305}, {270, 20}};
	NSRect bRect = (NSRect){{0, 0}, {320, 280}};
	NSRect buttonRect = (NSRect){{0, 287}, {40, 40}};
	NSBox *box = [[NSBox alloc] initWithFrame:(NSRect){{0,0},{330,340}}];
	NSBox *groov = [[NSBox alloc] initWithFrame:(NSRect){{0,335},{330,2}}];
	NSTextFieldCell *cell = [NSBrowserCell new];

	_scrollView = [[NSScrollView alloc] initWithFrame: bRect];
	[_scrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
	[_scrollView setHasVerticalScroller: YES];
	bRect.size = [_scrollView contentSize];
	_scrollViewMatrix = [[FinderMatrix alloc] initWithFrame: bRect];
	[_scrollViewMatrix setAutoresizingMask: NSViewWidthSizable];
	[_scrollViewMatrix setCellSize:(NSSize){NSWidth(bRect), 17}];
	[_scrollViewMatrix setPrototype:cell];
	[_scrollViewMatrix setTarget: [NSApp delegate]];
	[_scrollViewMatrix setAction: @selector(doClick:)];
	[_scrollViewMatrix setDoubleAction: @selector(doDoubleClick:)];
	[_scrollViewMatrix setAllowsEmptySelection: YES];
	[_scrollViewMatrix setAutosizesCells: YES];
	[box setTitlePosition: NSNoTitle];
	[box setContentViewMargins: (NSSize){0,0}];
	[box setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
	[box setBorderType: NSNoBorder];
	[groov setTitlePosition: NSNoTitle];
	[groov setContentViewMargins: (NSSize){0,0}];
	[groov setBorderType: NSGrooveBorder];
	_searchButton = [[NSButton alloc] initWithFrame: buttonRect];
	[_searchButton setButtonType:NSToggleButton];
	[_searchButton setImage: [NSImage imageNamed: @"search.tiff"]];
	[_searchButton setAlternateImage: [NSImage imageNamed: @"stop.tiff"]];
	[_searchButton setImagePosition: NSImageOnly];
	[_searchButton setTarget:self];
	[_searchButton setAction:@selector(search:)];
	textField = [[NSTextField alloc] initWithFrame: tRect];
	[textField setTarget:_searchButton];
	[textField setAction:@selector(performClick:)];
	[groov setAutoresizingMask: NSViewMinYMargin | NSViewWidthSizable];
	[textField setAutoresizingMask: NSViewMinYMargin | NSViewWidthSizable];
	[_searchButton setAutoresizingMask: NSViewMinYMargin | NSViewMaxXMargin];
	[box addSubview: groov];
	[box addSubview: _scrollView]; 
	[box addSubview: _searchButton]; 
	[box addSubview: textField]; 
	[_scrollView setDocumentView: _scrollViewMatrix]; 
	__finder = [self initWithFrame:wr rows:3 cols:4 subView:box];
	_browser = nil;
	[self setReleasedWhenClosed:NO];
	[self setTitle:@"Finder"];
//	[_shelf setMode:NSListModeMatrix];
	[_shelf setMode:NSHighlightModeMatrix];
	[_shelf setIsFinderShelf:YES];

	return self;
}

- (void) readSubprocessOutput:(id)sender
{
	int nread;
	char buf[1024];

	if ((nread = read(_master, buf, 1024)) <= 0)
		{														// EOF or ERROR
		CFSocketInvalidate(_cfSocket);
		CFRelease(_cfSocket), _cfSocket = nil;
		_master = -1;
		_searchTask = nil;
		[_searchButton setState:0];
		[_scrollViewMatrix display];
		}
	else
		{
		NSString *s;
		NSArray *subStrings;
		int i, count;
		NSRect c;
		NSCell *cell;

		buf[nread] = '\0';
		s = [NSString stringWithCString:buf];
		subStrings = [s componentsSeparatedByString:@"\r\n"];
		[_scrollViewMatrix lockFocus];
		for (i = 0, count = [subStrings count]; i < count; i++)
			{
			[_scrollViewMatrix insertRow: _rowCount];
			c = [_scrollViewMatrix cellFrameAtRow:_rowCount column:0];
			cell = [_scrollViewMatrix cellAtRow:_rowCount++ column:0];
			[cell setStringValue:[subStrings objectAtIndex:i]];
			[cell drawWithFrame:c inView:_scrollViewMatrix];
			}
		[self flushWindow];
		[_scrollViewMatrix unlockFocus];
		if(NSMaxY(c) > NSMaxY([_scrollViewMatrix bounds]))
			[_scrollViewMatrix sizeToCells];
		}
}

- (void) search:(id)sender
{
	NSString *s, *root, *searchString;
	NSString *format = @"%@ ( -type f ) -exec /usr/bin/grep -l -e %@ {} ;";
	NSArray *args;
	int slave;

	if(_searchTask && [_searchTask isRunning])
		{
		[_searchTask terminate];
		_searchTask = nil;
		return;
		}

	if(_rowCount)											// reset the matrix
		{													// if necessary
		_rowCount = 0;
		[_scrollViewMatrix renewRows:0 columns:0];
		[_scrollViewMatrix setFrameSize: [_scrollView contentSize]];
		[[_scrollView contentView] setBoundsOrigin:(NSPoint){0,0}];	
		[_scrollView display];
		}

	if([(searchString = [textField stringValue]) isEqualToString:@""])
		{
		[_searchButton setState:0];
		return;
		}

	if(!(root = [[_shelf selectedCell] path]))
		root = @"/";

	if (openpty(&_master, &slave, NULL, NULL, NULL) == -1)
		NSLog(@"unable to open a psuedo terminal pair");
	else
		{
		CFOptionFlags fl = kCFSocketReadCallBack;
		CFSocketContext cx = { 0, self, NULL, NULL, NULL };
		SEL scb = @selector(readSubprocessOutput:);
		CFSocketCallBack cb = (CFSocketCallBack)scb;
		CFRunLoopSourceRef rs;

		_cfSocket = CFSocketCreateWithNative(NULL, _master, fl, cb, &cx);

		if ((rs = CFSocketCreateRunLoopSource(NULL, _cfSocket, 0)) == NULL)
			[NSException raise:NSGenericException format:@"CFSocket init error"];
		CFRunLoopAddSource(CFRunLoopGetCurrent(), rs, (CFStringRef)NSDefaultRunLoopMode);
		CFRelease(rs);

		s = [NSString stringWithFormat:format, root, [textField stringValue]];
		args = [s componentsSeparatedByString:@" "];

		_searchTask = [[NSTask new] autorelease];
		[_searchTask setCurrentDirectoryPath:root];
		[_searchTask setLaunchPath:@"/usr/bin/find"];
		[_searchTask setArguments:args];
		[_searchTask _setStandardOutput:slave];
		[_searchTask _setStandardError:slave];
		[_searchTask launch];

		(void) close(slave);
		}
}

- (void) doClick:(id)sender						{}

@end /* Finder */
