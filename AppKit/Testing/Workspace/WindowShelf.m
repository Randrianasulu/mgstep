/*
   WindowShelf.m

   Object that contain a window, shelf and content area

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	November 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include "Matrix.h"
#include "WindowShelf.h"
#include "Browser.h"
#include "Cell.h"


@implementation SplitView

- (id) initWithFrame:(NSRect)frameRect
{
	_textCell = [[NSTextFieldCell alloc] initTextCell: @""];
	[_textCell setAlignment:NSRightTextAlignment];
	[_textCell setFont:[NSFont userFontOfSize:9]];
	[_textCell setTextColor: [NSColor darkGrayColor]];
	[_textCell setBackgroundColor: [NSColor lightGrayColor]];
	[_textCell setBezeled: NO];

	return [super initWithFrame:frameRect];
}

- (void) dealloc
{
	[_textCell release];

	[super dealloc];
}

- (void) setFileSize:(NSObject *)fsize
{
	[_textCell setObjectValue:fsize];
	[self lockFocus];
	[_textCell drawWithFrame:_lastTextRect inView:self];
	[self unlockFocus];
	[_window flushWindow];
}

- (void) drawDividerInRect:(NSRect)aRect
{
	_lastTextRect = aRect;

	[super drawDividerInRect:aRect];

	NSMinX(_lastTextRect) = NSMidX(aRect) + 10;
	NSWidth(_lastTextRect) -= ((NSWidth(aRect)/2) + 20);
	[_textCell drawInteriorWithFrame:_lastTextRect inView:self];
	NSHeight(_lastTextRect) += 1;
}

@end /* SplitView */


@implementation WindowShelf

- (id) initWithFrame:(NSRect)winRect
				rows:(int)rows
				cols:(int)cols
				subView:(NSView *)subView
{
	NSSplitView *splitView;
	id shelfCell, cell;
	NSRect shelfRect = (NSRect){{0, 380}, { NSWidth(winRect) - 30, 170}};
	NSRect cvFrame;

	NSRect browserRect = {0};
	float div = 0;

	[self initWithContentRect:winRect							// create main
		  styleMask:_NSCommonWindowMask							// window
		  backing:NSBackingStoreBuffered
		  defer:NO];

	shelfCell = [[[ShelfCell alloc] init] autorelease];
	[shelfCell setImage:nil];
	_shelf = [[Matrix alloc] initWithFrame:shelfRect			// create top
							 mode:NSHighlightModeMatrix			// shelf matrix
							 prototype:shelfCell
							 numberOfRows:rows
							 numberOfColumns:cols];
	cell = [_shelf cellAtRow:0 column:0];
	[cell setBranchImage: [NSImage imageNamed: @"host.tiff"]];
	[cell setStringValue: [[NSProcessInfo processInfo] hostName]];
	[cell _setPath: @"/"];

	if (rows > 1)
		{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		div = [[defaults objectForKey:@"Divider"] floatValue];
		}

	browserRect.size = (NSSize){NSWidth(shelfRect), NSHeight(winRect) - 240};
	if(div > 0 && div < NSHeight(winRect) && (rows > 1))
		NSHeight(browserRect) = div;
	else
		NSHeight(browserRect) = NSHeight(winRect) - 100;

	if (!subView)												// create the
		{														// file browser
		id browserCell = [[[BrowserCell alloc] init] autorelease];

		_browser = [[Browser alloc] initWithFrame: browserRect];
		[_browser setDelegate: [IconViewDelegate new]];
		[_browser setMaxVisibleColumns: 1];
		[_browser setCellPrototype:browserCell];
		[_browser setHasHorizontalScroller:NO];
		subView = _iconView = _browser;
		}
																// configure
	[_shelf setCellSize: (NSSize){CELL_WIDTH, CELL_HEIGHT}];	// shelf matrix
	[_shelf setIntercellSpacing: (NSSize){7,5}];	
	[_shelf sizeToCells];
	[_shelf setDrawsBackground:YES];
	[_shelf setBackgroundColor:[NSColor lightGrayColor]];
	[_shelf setDelegate: subView];
	[_shelf setDoubleAction: @selector(doDoubleClick:)];
	[_shelf setTarget: [NSApp delegate]];

	cvFrame = [_contentView frame];								// configure 
	cvFrame.origin = (NSPoint){10,5};							// and create
	cvFrame.size.width -= (2 * cvFrame.origin.x);				// splitview    
	cvFrame.size.height -= (2 * cvFrame.origin.y);
	splitView = [[SplitView alloc] initWithFrame:cvFrame];

	[splitView addSubview: subView];
	[splitView addSubview: _shelf];
	[_contentView addSubview: splitView];

//	if (subView == _browser)
	[subView release];
	[splitView release];
	[_shelf release];

	[splitView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[_shelf setAutoresizingMask:NSViewNotSizable];  // resize via split view
	[subView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
	[self makeFirstResponder:subView];

	return self;
}

- (Matrix *) matrix								{ return _shelf; }
- (Browser *) browser							{ return _browser; }

@end /* WindowShelf */
