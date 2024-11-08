/*
   AXBase.m

   AppKit graphics and utility functions.

   Copyright (C) 1998-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    December 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSImage.h>


#define CONTEXT		((CGContextRef)_CGContext())
#define ISFLIPPED	((CGContext *) _CGContext())->_gs->isFlipped



int
NSApplicationMain(int argc, const char **argv)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	[[NSApplication sharedApplication] run];
	[pool release];

    return 0;
}

NSEvent *
_NSAppKitEvent(void)
{
	static NSEvent *__appKitEvent = nil;

	if (!__appKitEvent)
		__appKitEvent = [[NSEvent otherEventWithType:NSAppKitDefined
								  location:NSZeroPoint
								  modifierFlags:0
								  timestamp:(NSTimeInterval)0
								  windowNumber:0
								  context:[NSApp context]
								  subtype:0xcace
								  data1:0
								  data2:0] retain];
	return __appKitEvent;
}

/* ****************************************************************************

	NSRect drawing and clipping functions

** ***************************************************************************/

void
NSRectClip(NSRect r)
{
	CGContextClipToRect(CONTEXT, r);
}

void
NSRectFillUsingOperation(NSRect r, NSCompositingOperation op)
{
	CGContextRef cx = CONTEXT;
	CGBlendMode bm = ((CGContext *) cx)->_gs->blendMode;

	if (bm != (CGBlendMode)op)
		CGContextSetBlendMode(cx, (CGBlendMode)op);
	CGContextFillRect(cx, r);
	if (bm != ((CGContext *) cx)->_gs->blendMode)
		CGContextSetBlendMode(cx, bm);
}

void
NSRectFill(NSRect r)
{
	NSRectFillUsingOperation(r, NSCompositeCopy);
}

void
NSHighlightRect(NSRect r)
{
	NSRectFillUsingOperation(r, NSCompositeHighlight);
}

void
NSEraseRect(NSRect r)
{														// fill rect with white
	CGContextRef cx = _CGContext();
	NSColor *c = ((CGContext *) cx)->_gs->fill.color;

	CGContextSetRGBFillColor(cx, 1.0, 1.0, 1.0, 1.0);
	NSRectFill(r);										// w/o changing color
	[c set];
}

void
NSRectFillList(const NSRect *rects, int count)
{														// Fill an array of 
	int i;												// rects with the
    													// current color.
    for (i = 0; i < count; i++)
		NSRectFill(rects[i]);
}

void
NSRectClipList(const NSRect *rects, int count)
{
	int i;
    
    for (i = 0; i < count; i++)
		NSRectClip(rects[i]);
}

void
NSRectFillListUsingOperation(const NSRect *r, int c, NSCompositingOperation op)
{
	int i;

	for (i = 0; i < c; i++)
		NSRectFillUsingOperation(r[i], op);
}

void
NSRectFillListWithColorsUsingOperation(const NSRect *rects,
									   NSColor **colors,
									   int c,
									   NSCompositingOperation op)
{
	int i;

	for (i = 0; i < c; i++)
		{
		[colors[i] setFill];
		NSRectFillUsingOperation(rects[i], op);
		}
}

void
NSRectFillListWithGrays(const NSRect *rects, const float *grays, int c)
{
	int i;

	for (i = 0; i < c; i++)						// Fills each rectangle in the
		{										// array rects[] with the gray 
		PSsetgray(grays[i]);					// value stored in the parallel 
		NSRectFill(rects[i]);					// array grays[].
		}
}

void
NSRectFillListWithColors(const NSRect *rects, NSColor **colors, int c)
{
	int i;

	for (i = 0; i < c; i++)
		{
		[colors[i] setFill];
		NSRectFill(rects[i]);
		}
}

/* ****************************************************************************

	Draws frame around inside of rect with current fill color using compositing 
	operation op. Frame is visible if drawing is clipped to rect.

** ***************************************************************************/

void
NSFrameRectWithWidthUsingOperation(NSRect r, float w, NSCompositingOperation op)
{
	CGContextRef cx = CONTEXT;
	CGBlendMode bm = ((CGContext *) cx)->_gs->blendMode;

	if (bm != (CGBlendMode)op)
		CGContextSetBlendMode(cx, (CGBlendMode)op);
	CGContextStrokeRectWithWidth(cx, r, w);
	if (bm != ((CGContext *) cx)->_gs->blendMode)
		CGContextSetBlendMode(cx, bm);
}

void 													// draw rect of width
NSFrameRectWithWidth(NSRect r, float frameWidth) 		// using current color
{
	NSFrameRectWithWidthUsingOperation(r, frameWidth, NSCompositeCopy);
}

void
NSFrameRect(NSRect r)									// FIX ME draw inside
{														// rect w/fill color
	NSFrameRectWithWidth(r, 1.0);
}

/* ****************************************************************************

	Draws an unfilled rect, clipped by clipRect, whose border is defined by
	the parallel arrays sides[] and grays[] of length count. Each element of 
	sides specifies an edge of the rectangle which is drawn with a width of 1.0 
	using the corresponding gray level from the grays[].  Any recurring edges
	are inset within the previous edge.  Returns interior rectangle.

** ***************************************************************************/

NSRect
NSDrawTiledRects( NSRect boundsRect,
				  NSRect clipRect,
				  const NSRectEdge *sides,
				  const float *grays,
				  int count)
{
	NSRect slice, remainder = boundsRect;
	NSRect rects[count];
	int i;

	if (!NSIntersectsRect(boundsRect, clipRect))
		return NSZeroRect;

	for (i = 0; i < count; i++)
		{
		NSDivideRect(remainder, &slice, &remainder, 1.0, sides[i]);
		rects[i] = NSIntersectionRect(slice, clipRect);
		}

	NSRectFillListWithGrays(rects, grays, count);

	return remainder;
}

NSRect
NSDrawColorTiledRects( NSRect boundsRect,
					   NSRect clipRect,
					   const NSRectEdge *sides,
					   NSColor **colors,
					   int count)
{
	NSRect slice, remainder = boundsRect;
	NSRect rects[count];
	int i;

	if (!NSIntersectsRect(boundsRect, clipRect))
		return NSZeroRect;

	for (i = 0; i < count; i++)
		{
		NSDivideRect(remainder, &slice, &remainder, 1.0, sides[i]);
		rects[i] = NSIntersectionRect(slice, clipRect);
		}

	NSRectFillListWithColors(rects, colors, count);

	return remainder;
}

void
NSDrawButton(NSRect aRect, NSRect clipRect)
{
	float grays[] = { NSBlack, NSBlack, NSWhite, NSWhite, NSDarkGray, NSDarkGray };
	NSRectEdge *edges = (ISFLIPPED) ? BUTTON_EDGES_FLIPPED : BUTTON_EDGES_NORMAL;
	NSRect rect = NSDrawTiledRects(aRect, clipRect, edges, grays, 6);

	PSsetgray(NSLightGray);
	NSRectFill(rect);
}

void
_NSImageFramePhoto(NSRect aRect, NSRect clipRect)
{
	float grays[] = {NSDarkGray,NSDarkGray,NSDarkGray,NSDarkGray,NSBlack,NSBlack};
	NSRectEdge *edges = (ISFLIPPED) ? BUTTON_EDGES_FLIPPED : BUTTON_EDGES_NORMAL;
	NSRect rect = NSDrawTiledRects(aRect, clipRect, edges, grays, 6);

	PSsetgray(NSLightGray);
	NSRectFill(rect);
}

void
NSDrawGrayBezel(NSRect aRect, NSRect clipRect)
{
	float grays[] = { NSWhite, NSWhite, NSDarkGray, NSDarkGray,
					  NSLightGray, NSLightGray, NSBlack, NSBlack };
	NSRect rect;

	if (ISFLIPPED)
    	{
 		rect = NSDrawTiledRects(aRect, clipRect, BEZEL_EDGES_FLIPPED, grays,8);
		PSsetgray(NSDarkGray);
		NSRectFill(NSMakeRect(NSMinX(aRect) + 1., NSMaxY(aRect) - 2., 1., 1.));
		}
	else
		{
		rect = NSDrawTiledRects(aRect, clipRect, BEZEL_EDGES_NORMAL, grays, 8);
		PSsetgray(NSDarkGray);
		NSRectFill(NSMakeRect(NSMinX(aRect) + 1., NSMinY(aRect) + 1., 1., 1.));
		}

	PSsetgray(NSLightGray);
	NSRectFill(NSIntersectionRect(rect, clipRect));
}

void
NSDrawWhiteBezel(NSRect aRect, NSRect clipRect)			// like a TextField
{
	float grays[] = { NSWhite, NSWhite, NSDarkGray, NSDarkGray,
					  NSLightGray, NSLightGray, NSDarkGray, NSDarkGray };
	NSRectEdge *edges = (ISFLIPPED) ? BEZEL_EDGES_FLIPPED : BEZEL_EDGES_NORMAL;
	NSRect rect = NSDrawTiledRects(aRect, clipRect, edges, grays, 8);

	PSsetgray(NSWhite);
	NSRectFill(NSIntersectionRect(rect, clipRect));
}

void
NSDrawGroove(NSRect aRect, NSRect clipRect)
{
	NSRectEdge norm[] = { NSMinXEdge, NSMaxYEdge, NSMinXEdge, NSMaxYEdge,
						  NSMaxXEdge, NSMinYEdge, NSMaxXEdge, NSMinYEdge };
	NSRectEdge flip[] = { NSMinXEdge, NSMinYEdge, NSMinXEdge, NSMinYEdge, 
						  NSMaxXEdge, NSMaxYEdge, NSMaxXEdge, NSMaxYEdge };
	float grays[] = { NSDarkGray, NSDarkGray, NSWhite, NSWhite,
					  NSWhite, NSWhite, NSDarkGray, NSDarkGray };
	NSRectEdge *edges = (ISFLIPPED) ? flip : norm;
	NSRect rect = NSDrawTiledRects(aRect, clipRect, edges, grays, 8);

	PSsetgray(NSLightGray);
	NSRectFill(NSIntersectionRect(rect, clipRect));
}


#if 0  /* not implemented */

void 
NSFrameLinkRect(NSRect aRect, BOOL isDestination)
{										// Draw a Distinctive Outline 
}										// around Linked Data

float 
NSLinkFrameThickness(void)
{
	return 0;							// Thickness of frame link
}

void 
NSTextFontInfo(id fid, float *ascender, float *descender, float *lineHeight)
{										// Calculate Font Ascender, Descender, 
}										// and Line Height (in Text Object)

#endif
