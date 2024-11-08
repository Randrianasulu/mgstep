/*
   NSCursor.m

   Cursor management

   Copyright (C) 2000-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSView.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSCursor.h>


#define CTX				((CGContext *)_CGContext())
#define CURSOR			CTX->_mg->_cursor
#define XDISPLAY		CTX->_display->xDisplay
#define XROOTWIN		CTX->_display->xRootWindow

#define CURSORIMG		CTX->_mg->_cursorBitmap
#define CURSOR_W		CTX->_mg->_curorWidth
#define CURSOR_H		CTX->_mg->_curorHeight
#define CURSOR_COLS		CTX->_mg->_curorNumColors


// Class variables
static NSCursor *__arrowCursor = nil;
static NSCursor *__iBeamCursor = nil;
static NSCursor *__pointingHandCursor = nil;
static NSCursor *__copyCursor = nil;
static NSCursor *__linkCursor = nil;
static NSCursor *__resizeCursor = nil;
static NSCursor *__blankCursor = nil;
static NSCursor *__hiddenCursor = nil;

static NSMutableArray *__cursorStack = nil;
static BOOL __hiddenTilMouseMoves = YES;


@implementation NSCursor

+ (void) initialize
{
	__cursorStack = [[NSMutableArray alloc] initWithCapacity: 2];
}

+ (NSCursor *) currentCursor				  { return CURSOR; }
+ (BOOL) isHiddenUntilMouseMoves			  { return __hiddenTilMouseMoves; }
+ (void) setHiddenUntilMouseMoves:(BOOL)flag  { __hiddenTilMouseMoves = flag; }

+ (void) unhide										// must be current cursor
{													// in order to unhide
	if (__blankCursor && (__blankCursor == CURSOR))
		[__hiddenCursor set];						// Revert to current cursor
}

+ (void) hide
{
	if (!__blankCursor)								// Create the blank cursor
		{
		NSImage *img = [NSImage imageNamed:@"blankCursor"];

		__blankCursor = [[NSCursor alloc] initWithImage: img
										  hotSpot:(NSPoint){0,0}];
		}

	if (__blankCursor == CURSOR)					// do nothing if hidden
		return;

	__hiddenCursor = CURSOR;						// Save the current cursor 
	[__blankCursor set];							// and set the blank cursor
	CURSOR = __blankCursor;
}

+ (void) pop
{
	int c = [__cursorStack count];
	
	if (c > 1)										// If stack isn't empty
		[__cursorStack removeLastObject];			// remove last cursor

	if (c > 0)
		[[__cursorStack lastObject] set];			// cursor remains unchanged
}

- (void) push
{
	[__cursorStack addObject: self];
	[self set];
}

+ (NSCursor *) arrowCursor							// left ptr arrow
{
	if(!__arrowCursor)
		{
		NSImage *img = [NSImage imageNamed: @"arrowCursor"];
		NSPoint h = (NSPoint){0,0};

		__arrowCursor = [[NSCursor alloc] initWithImage:img hotSpot:h];
		}
	
	return __arrowCursor;
}

+ (NSCursor *) IBeamCursor							// I-beam
{
	if (!__iBeamCursor)
		{
		NSImage *img = [NSImage imageNamed: @"iBeamCursor"];
		NSPoint h = (NSPoint){8,8};

		__iBeamCursor = [[NSCursor alloc] initWithImage:img hotSpot:h];
		}

	return __iBeamCursor;
}

+ (NSCursor *) pointingHandCursor					// pointing hand
{
	if (!__pointingHandCursor)
		{
		NSImage *img = [NSImage imageNamed: @"pointingHandCursor"];
		NSPoint h = (NSPoint){8,-8};

		__pointingHandCursor = [[NSCursor alloc] initWithImage:img hotSpot:h];
		}

	return __iBeamCursor;
}

+ (NSCursor *) dragCopyCursor
{
	if (!__copyCursor)
		{
		NSImage *img = [NSImage imageNamed:@"copyCursor"];
		NSColor *f = [NSColor greenColor];
		NSColor *b = [NSColor colorWithCalibratedRed:0 green:.6 blue:0 alpha:1];

		__copyCursor = [[NSCursor alloc] initWithImage: img
										 foregroundColorHint: f
										 backgroundColorHint: b
										 hotSpot:(NSPoint){0,0}];
		}

	return __copyCursor;
}

+ (NSCursor *) dragLinkCursor
{
	if (!__linkCursor)
		{
		NSImage *img = [NSImage imageNamed:@"linkCursor"];
		NSColor *f = [NSColor greenColor];
		NSColor *b = [NSColor blackColor];

		__linkCursor = [[NSCursor alloc] initWithImage: img 
										 foregroundColorHint: f
										 backgroundColorHint: b
										 hotSpot:(NSPoint){0,0}];
		}

	return __linkCursor;
}

+ (NSCursor *) moveCursor				{ return nil; }		// mGSTEP extension
+ (NSCursor *) resizeLeftRightCursor	{ return [NSCursor resizeCursor]; }

+ (NSCursor *) resizeCursor									// mGSTEP extension
{
	if (!__resizeCursor)
		{
		NSImage *img = [NSImage imageNamed:@"resizeCursor"];
		NSColor *f = [NSColor grayColor];
		NSColor *b = [NSColor blackColor];

		__resizeCursor = [[NSCursor alloc] initWithImage: img
										   foregroundColorHint: f
										   backgroundColorHint: b
										   hotSpot:(NSPoint){8,8}];
		}

	return __resizeCursor;
}

- (id) initWithImage:(NSImage *)image
			foregroundColorHint:(NSColor *)f
			backgroundColorHint:(NSColor *)b
			hotSpot:(NSPoint)h
{
	_hotSpot = h;
	_image = [image retain];

	return self;
}

- (id) initWithImage:(NSImage *)image hotSpot:(NSPoint)point
{
	return [self initWithImage: image 
				 foregroundColorHint: [NSColor whiteColor] 
				 backgroundColorHint: [NSColor blackColor]
				 hotSpot: point];
}

- (void) dealloc
{
	[_image release];
	[super dealloc];
}

- (NSImage *) image							{ return _image; }
- (NSPoint) hotSpot							{ return _hotSpot; }
- (void) setHotSpot:(NSPoint)spot			{ _hotSpot = spot; }
- (void) setImage:(NSImage *)newImage		{ _image = newImage; }
- (void) setOnMouseEntered:(BOOL)flag		{ _isSetOnMouseEntered = flag;}
- (void) setOnMouseExited:(BOOL)flag		{ _isSetOnMouseExited = flag; }
- (void) pop								{ [NSCursor pop]; }
- (BOOL) isSetOnMouseEntered				{ return _isSetOnMouseEntered;}
- (BOOL) isSetOnMouseExited					{ return _isSetOnMouseExited; }

- (void) mouseEntered:(NSEvent *)event
{
	if (_isSetOnMouseEntered)
		[self set];
}

- (void) mouseExited:(NSEvent *)event
{
	if (_isSetOnMouseExited)
		[self set];
}

@end  /* NSCursor */

#ifdef FB_GRAPHICS  /* ******************************************** FBCursor */

/* ****************************************************************************

	FB Cursor

** ***************************************************************************/

@implementation NSCursor  (FBCursor)

- (void) set
{
	if (CURSOR != self)
		{
		NSImageRep *rep = [_image bestRepresentationForDevice:nil];
		NSSize s = [rep size];

//		if(![NSApp keyWindow])
//			return;

		CURSOR = self;
		CURSORIMG = [(NSBitmapImageRep *)rep bitmapData];
		CURSOR_W = s.width;
		CURSOR_H = s.height;
		CURSOR_COLS = [(NSBitmapImageRep *)rep samplesPerPixel];
		FBFlushCursor(_CGContext());
		FBDrawCursor(_CGContext());
		}
}

@end  /* NSCursor  (FBCursor) */

#else  /* !FB_GRAPHICS  ******************************************* XRCursor */

/* ****************************************************************************

	XR Cursor

** ***************************************************************************/

#include <X11/cursorfont.h>


@implementation NSCursor  (XRCursor)

+ (id) alloc
{
	return NSAllocateObject([XRCursor class]);
}

+ (NSCursor *) arrowCursor							// Create the standard left
{													// pointer arrow cursor
	if (!__arrowCursor)
		{
		Cursor c = XCreateFontCursor(XDISPLAY, XC_left_ptr);

		__arrowCursor = [XRCursor alloc];
		__arrowCursor = [__arrowCursor initWithImage:nil hotSpot:NSZeroPoint];
		[(XRCursor *)__arrowCursor xSetCursor:c];
		}	 
	
	return __arrowCursor;
}

@end  /* NSCursor  (XRCursor) */


@implementation XRCursor

- (id) initWithImage:(NSImage *)image				// designated init
			foregroundColorHint:(NSColor *)fh
			backgroundColorHint:(NSColor *)bh
			hotSpot:(NSPoint)h
{
	_hotSpot = h;
	_image = [image retain];

	if (image != nil)
		{
		NSImageRep *bp = [image bestRepresentationForDevice:nil];
		Pixmap mask = (Pixmap)[(NSBitmapImageRep *)bp xPixmapMask];
		Pixmap bits = (Pixmap)[(NSBitmapImageRep *)bp xPixmapBitmap];
		XColor fg = [fh xColor];
		XColor bg = [bh xColor];

		_cursor = XCreatePixmapCursor(XDISPLAY, bits, mask, &fg, &bg, h.x, h.y);
		if (mask != None)
			XFreePixmap (XDISPLAY, mask);
		if (bits != None)
			XFreePixmap (XDISPLAY, bits);
		}

	return self;
}

- (void) set
{
	if (CURSOR != self && _cursor != None)
		{
		NSWindow *w;
		Window xw = None;

		CURSOR = self;
		if ((w = [NSApp keyWindow]))
			xw = [w xWindow];
		if (xw != None || (xw = XROOTWIN))
			XDefineCursor(XDISPLAY, xw, _cursor);
		}
}

- (void) xSetCursor:(Cursor)cursor			{ _cursor = cursor; }
- (Cursor) xCursor							{ return _cursor; }

- (void) dealloc
{
	XFreeCursor (XDISPLAY, _cursor);

	[super dealloc];
}

@end  /* XRCursor */

#endif  /* !FB_GRAPHICS */
