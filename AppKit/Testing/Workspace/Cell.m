/*
   Cell.m

   Workspace BrowserCell, ShelfCell and SelectionCell classes.

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:	Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	July 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSArray.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSNib.h>

#include "Controller.h"
#include "Cell.h"
#include "Matrix.h"

//
// Class variables
//
static NSColor *__backColor = nil;
static NSImage *__selectImage = nil;
static NSImage *__arrowImage = nil;


/* ****************************************************************************

		ShelfCell

** ***************************************************************************/

@implementation ShelfCell

+ (void) initialize
{
	if (self == [ShelfCell class])
		{
		__selectImage = [[NSImage imageNamed: @"select.tiff"] retain];
		__arrowImage = [[NSImage imageNamed: @"browserRight.tiff"] retain];
		__backColor = [NSColor lightGrayColor];
		}
}

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell: aString]))
		{
		_c.selectable = YES;
		_browserText = [[[NSCell alloc] initTextCell: aString] retain];
		[_browserText setAlignment:NSCenterTextAlignment];
		[_browserText setEditable: YES];
		}

	return self;
}

- (void) dealloc
{
	[_browserText release];
	[super dealloc];
}

- (id) copy
{
	ShelfCell *c = [super copy];

	c->_browserText = [_browserText copy];

	return c;
}

- (void) drawInteriorWithFrame:(NSRect)cellFrame 
						inView:(NSView *)controlView
{
	NSRect title_rect = cellFrame;
	NSRect image_rect;
	NSPoint drawOrigin;
	NSCompositingOperation op = NSCompositeSourceOver;
	NSSize size;

	if(!_image)
		return;

	_controlView = controlView;							// last view drawn in

//	if (!_c.state)
		{	
		[__backColor set];								// Clear background
		NSRectFill(cellFrame);
		}

	image_rect.origin = cellFrame.origin;
	image_rect.size = (NSSize){CELL_WIDTH - 7, CELL_HEIGHT - 7};
														// center justify
	image_rect.origin.x += (cellFrame.size.width - image_rect.size.width) / 2;

	title_rect.origin.y = NSMaxY(title_rect) - 12;		// Determine title rect
	title_rect.size.height = 16;
														// Draw the title cell
	[_browserText drawInteriorWithFrame:title_rect inView:controlView];

	drawOrigin = image_rect.origin;

	if(_c.state)										// Draw selection image
		{												// known to be 66x52
		image_rect.origin.x += ((CELL_WIDTH - 7 - 66) / 2);
		image_rect.origin.y += ((CELL_HEIGHT - 7 - 52) / 2);

		[__selectImage compositeToPoint:image_rect.origin operation:op];
		op = NSCompositeHighlight;
		}

	size = [_image size];								// Draw the cell image
	drawOrigin.x += (NSWidth(image_rect) - size.width) / 2;
	drawOrigin.y += (NSHeight(image_rect) - size.height) / 2;

	[_image compositeToPoint:drawOrigin operation:op];	// display centered img
}

- (void) drawLightInteriorWithFrame:(NSRect)cellFrame 
							 inView:(NSView *)controlView
{
	NSRect title_rect = cellFrame;
	NSRect image_rect;
	NSPoint drawOrigin;

	if(!_image)
		return;

	_controlView = controlView;							// last view drawn in

	[__backColor set];									// Clear background
	NSRectFill(cellFrame);

	image_rect.origin = cellFrame.origin;
	image_rect.size = (NSSize){CELL_WIDTH - 7, CELL_HEIGHT - 7};
														// center justify
	image_rect.origin.x += (cellFrame.size.width - image_rect.size.width) / 2;

	title_rect.origin.y = NSMaxY(title_rect) - 12;		// Determine title rect
	title_rect.size.height = 17;
														// Draw the title cell
//	[_browserText drawInteriorWithFrame:title_rect inView:controlView];

	drawOrigin = image_rect.origin;

	if(_image)											// Draw the cell image
		{
		NSSize size = [_image size];

		drawOrigin.x += (NSWidth(image_rect) - size.width) / 2;
		drawOrigin.y += (NSHeight(image_rect) - size.height) / 2;
														// display centered img			
		[_image dissolveToPoint:drawOrigin fraction:0.4];
		}
}

- (BOOL) isEntryAcceptable:(NSString *)aString
{
	if (![[_browserText stringValue] isEqualToString:aString])
		{												// file was renamed
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *src = [[NSApp delegate] path];
		NSString *dest = [src stringByDeletingLastPathComponent];
		BOOL exists, is_dir;

		dest = [dest stringByAppendingPathComponent:aString];

		if ((exists = [fm fileExistsAtPath:dest isDirectory:&is_dir]))
			{
			NSString *m = @"%@ already exists.  Overwrite?";

			if (!NSRunAlertPanel(0, m, @"Yes",@"No", NULL, aString))
				return NO;
			}

		if (!exists)
			{
			if(![fm movePath:src toPath:dest handler:nil])
				{
				NSString *m = @"error moving path: %@ to path: %@";

				NSRunAlertPanel(0, m, @"Continue", NULL, NULL, src, dest);
				}
			else
				[_browserText setStringValue:aString];
		}	}

	return YES;
}

- (void) setStringValue:(NSString *)aString 
{ 
	[_browserText setStringValue: aString];
}

- (NSCell *) browserText				{ return _browserText; }
- (NSString *) stringValue				{ return [_browserText stringValue]; }
- (BOOL) isOpaque						{ return YES; }
- (void) _setPath:(NSString *)aPath		{ ASSIGN(_path, aPath); }
- (void) _setFiles:(NSArray *)files		{ ASSIGN(_files, files); }
- (NSString *) path						{ return _path;	}
- (NSArray *) files						{ return _files; }
- (NSImage *) image						{ return _image; }

- (void) setImage:(NSImage *)anImage
{
	ASSIGN(_image, anImage);
	if(!anImage)
		_c.isLeaf = YES;	
}

- (void) setBranchImage:(NSImage *)anImage
{
	_c.isLeaf = NO;
	ASSIGN(_image, anImage);		
}

- (void) setLeafImage:(NSImage *)anImage
{
	_c.isLeaf = YES;	
	ASSIGN(_image, anImage);
}

- (void) _handleKeyEvent:(NSEvent*)keyEvent
{
	fprintf(stderr, " XRBrowserCell: _handleKeyEvent --- ");
}

- (void) encodeWithCoder:aCoder							// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeObject: _browserText];
}

- (id) initWithCoder:aDecoder
{
	[super initWithCoder:aDecoder];
	
	_browserText = [aDecoder decodeObject];
	
	return self;
}

@end /* ShelfCell */

/* ****************************************************************************

		BrowserCell

** ***************************************************************************/

@implementation BrowserCell

- (BOOL) trackMouse:(NSEvent *)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView *)controlView
			 untilMouseUp:(BOOL)flag
{
	NSRect t = cellFrame;

	if(!_image)
		return NO;

	t.size.height = 17;									// Determine title rect
	t.origin.y = NSMaxY(cellFrame) - 12;

	return [_browserText trackMouse:event
						 inRect:t
						 ofView:controlView
						 untilMouseUp:NO];
}

@end /* BrowserCell */

/* ****************************************************************************

		SelectionCell

** ***************************************************************************/

@implementation SelectionCell

- (void) drawInteriorWithFrame:(NSRect)cellFrame 
						inView:(NSView *)controlView
{
	NSRect r = cellFrame;
	NSSize size;

	[super drawInteriorWithFrame:cellFrame inView:controlView];

	r.origin.x += cellFrame.size.width - 20;
	size = [__arrowImage size];
	r.origin.x += (r.size.width - size.width) / 2;
	r.origin.y += (r.size.height - size.height) / 2;		// Draw arrow image

	[__arrowImage compositeToPoint:r.origin operation:NSCompositeSourceOver];
}

@end /* SelectionCell */
