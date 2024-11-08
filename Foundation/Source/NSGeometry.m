/*
   NSGeometry.m

   Geometry routines and structures

   Copyright (C) 1995-2017 Free Software Foundation, Inc.

   Author:	Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSGeometry.h>
#include <Foundation/NSString.h>
#include <Foundation/NSScanner.h>


const NSPoint NSZeroPoint = (NSPoint){0, 0};
const NSSize  NSZeroSize  = (NSSize) {0, 0};
const NSRect  NSZeroRect  = (NSRect) {0, 0, 0, 0};


NSPoint	 NSMakePoint( CGFloat x, CGFloat y)    { return (NSPoint){x, y}; }
NSSize   NSMakeSize ( CGFloat w, CGFloat h)    { return (NSSize) {w, h}; }
NSRect   NSMakeRect ( CGFloat x, CGFloat y,
					  CGFloat w, CGFloat h)    { return (NSRect){x, y, w, h}; }

NSRect 	
NSOffsetRect(NSRect r, CGFloat dX, CGFloat dY)
{
	return (NSRect){{NSMinX(r) + dX, NSMinY(r) + dY}, r.size};
}

NSRect 	
NSInsetRect(NSRect r, CGFloat dX, CGFloat dY)
{
	return (NSRect){{ NSMinX(r) + dX, NSMinY(r) + dY },
					{ NSWidth(r) - (2 * dX), NSHeight(r) - (2 * dY) }};
}

void 	
NSDivideRect(NSRect r,
             NSRect *slice,
             NSRect *remainder,
             float amount,
             NSRectEdge edge)
{
	if (NSIsEmptyRect(r))
		{
		*slice = NSZeroRect;
		*remainder = NSZeroRect;

		return;
		}

	switch (edge)
		{
		case NSMinXEdge:
			if (amount > r.size.width)
				{
				*slice = r;
				*remainder = (NSRect){NSMaxX(r), NSMinY(r), 0, NSHeight(r)};
				}
			else
				{
				*slice = (NSRect){NSMinX(r), NSMinY(r), amount, NSHeight(r)};
				*remainder = (NSRect){NSMaxX(*slice), NSMinY(r), 
									  NSMaxX(r) - NSMaxX(*slice), NSHeight(r)};
				}
			break;

		case NSMinYEdge:
			if (amount > r.size.height)
				{
				*slice = r;
				*remainder = (NSRect){r.origin.x, NSMaxY(r), r.size.width, 0};
				}
			else
				{
				*slice = (NSRect){r.origin,{r.size.width, amount}};
				*remainder = (NSRect){r.origin.x, NSMaxY(*slice), 
									 r.size.width, NSMaxY(r) - NSMaxY(*slice)};
				}
			break;

		case NSMaxXEdge:
			if (amount > r.size.width)
				{
				*slice = r;
				*remainder = (NSRect){r.origin, {0, r.size.height}};
				}
			else
				{
				*slice = (NSRect){NSMaxX(r) - amount, r.origin.y,
									amount, r.size.height};
				*remainder = (NSRect){r.origin,{NSMinX(*slice) - NSMinX(r),
									  r.size.height}};
				}
			break;

		case NSMaxYEdge:
			if (amount > r.size.height)
				{
				*slice = r;
				*remainder = (NSRect){r.origin, {r.size.width, 0}};
				}
			else
				{
				*slice = (NSRect){r.origin.x, NSMaxY(r) - amount, 
								  r.size.width, amount};
				*remainder = (NSRect){r.origin, {r.size.width, 
									  NSMinY(*slice) - r.origin.y}};
				}

		default:
			break;
		}
}

NSRect 	
NSIntegralRect(NSRect r)
{
	NSRect rect;

	if (NSIsEmptyRect(r))
		return NSZeroRect;
	
	rect.origin.x = floor(r.origin.x);
	rect.origin.y = floor(r.origin.y);
	rect.size.width = ceil(r.size.width);
	rect.size.height = ceil(r.size.height);

	return rect;
}

NSRect 	
NSUnionRect(NSRect aRect, NSRect bRect)
{
	NSRect rect;

	if (NSIsEmptyRect(aRect))
		return (NSIsEmptyRect(bRect)) ? NSZeroRect : bRect;

	if (NSIsEmptyRect(bRect))
		return aRect;
	
	rect = (NSRect){MIN(NSMinX(aRect), NSMinX(bRect)), 
					MIN(NSMinY(aRect), NSMinY(bRect)), 0, 0};

	return (NSRect){NSMinX(rect), NSMinY(rect),
					MAX(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(rect),
					MAX(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(rect)};
}

BOOL
NSIntersectsRect(NSRect a, NSRect b)				// Intersection at a line
{													// or a point doesn't count
	return (NSMaxX(a) <= NSMinX(b)
			|| NSMaxX(b) <= NSMinX(a)
			|| NSMaxY(a) <= NSMinY(b)
			|| NSMaxY(b) <= NSMinY(a)) ? NO : YES;
}

NSRect   
NSIntersectionRect (NSRect aRect, NSRect bRect)
{
	NSRect rect;

	if (!NSIntersectsRect(aRect, bRect))
    	return NSZeroRect;

	if (NSMinX(aRect) <= NSMinX(bRect))
		{
		rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(bRect);
		rect.origin.x = NSMinX(bRect);
		}
	else
		{
		rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(aRect);
		rect.origin.x = NSMinX(aRect);
		}

	if (NSMinY(aRect) <= NSMinY(bRect))
		{
		rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(bRect);
		rect.origin.y = NSMinY(bRect);
		}
	else
		{
		rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(aRect);
		rect.origin.y = NSMinY(aRect);
		}

	return rect;
}

BOOL NSEqualRects(NSRect a, NSRect b)
{
	return POINTS_EQ(a.origin, b.origin) && SIZE_EQ(a.size, b.size) ? 1 : 0;
}

BOOL NSEqualSizes(NSSize a, NSSize b)		{ return SIZE_EQ(a, b)   ? 1 : 0; }
BOOL NSEqualPoints(NSPoint a, NSPoint b)	{ return POINTS_EQ(a, b) ? 1 : 0; }
BOOL NSPointInRect(NSPoint p, NSRect r)		{ return NSMouseInRect(p, r, YES); }

BOOL
NSMouseInRect(NSPoint p, NSRect r, BOOL flipped)
{
	if (flipped)
		return ((p.x >= NSMinX(r))
				&& (p.y >= NSMinY(r))
				&& (p.x < NSMaxX(r))
				&& (p.y < NSMaxY(r))) ? YES : NO;

	return ((p.x >= NSMinX(r))
			&& (p.y > NSMinY(r))
			&& (p.x < NSMaxX(r))
			&& (p.y <= NSMaxY(r))) ? YES : NO;
}

BOOL NSIsEmptyRect(NSRect r)
{
	return ((NSWidth(r) > 0) && (NSHeight(r) > 0)
			&& !NSEqualSizes(r.size, NSZeroSize)) ? NO : YES;
}

BOOL
NSContainsRect(NSRect aRect, NSRect bRect)
{
	return (!NSIsEmptyRect(bRect)
			&& (NSMinX(aRect) <= NSMinX(bRect))
			&& (NSMinY(aRect) <= NSMinY(bRect))
			&& (NSMaxX(aRect) >= NSMaxX(bRect))
			&& (NSMaxY(aRect) >= NSMaxY(bRect))) ? YES : NO;
}

NSString *
NSStringFromPoint(NSPoint p)
{
	return [NSString stringWithFormat:@"{%g, %g}", p.x, p.y];
}

NSString *
NSStringFromRect(NSRect r)
{
	return [NSString stringWithFormat: @"{{%g, %g}, {%g, %g}}",
							NSMinX(r), NSMinY(r), NSWidth(r), NSHeight(r)];
}

NSString *
NSStringFromSize(NSSize z)
{
	return [NSString stringWithFormat:@"{%g, %g}", z.width, z.height];
}

NSPoint	NSPointFromString(NSString *string)		// { x, y }
{
	NSScanner *s = [NSScanner scannerWithString:string];
	NSPoint point;

	if ([s scanString:@"{" intoString:NULL]
			&& [s SCAN_FLOAT:&point.x]
			&& [s scanString:@"," intoString:NULL]
			&& [s SCAN_FLOAT:&point.y]
			&& [s scanString:@"}" intoString:NULL])
		return point;

	return NSZeroPoint;
}

NSSize NSSizeFromString(NSString *string)		// { width, height }
{
	NSScanner *s = [NSScanner scannerWithString:string];
	NSSize size;  

	if ([s scanString:@"{" intoString:NULL]
			&& [s SCAN_FLOAT:&size.width]
			&& [s scanString:@"," intoString:NULL]
			&& [s SCAN_FLOAT:&size.height]
			&& [s scanString:@"}" intoString:NULL])
		return size;

	return NSZeroSize;
}

NSRect _NSRectFromString(NSString *string)		// deprecated prop list style
{
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSRect rect;
  
	if ([scanner scanString:@"{" intoString:NULL]
			&& [scanner scanString:@"x" intoString:NULL]
			&& [scanner scanString:@"=" intoString:NULL]
			&& [scanner SCAN_FLOAT:&rect.origin.x]
			&& [scanner scanString:@";" intoString:NULL]
			&& [scanner scanString:@"y" intoString:NULL]
			&& [scanner scanString:@"=" intoString:NULL]
			&& [scanner SCAN_FLOAT:&rect.origin.y]
			&& [scanner scanString:@";" intoString:NULL]
			&& [scanner scanString:@"width" intoString:NULL]
			&& [scanner scanString:@"=" intoString:NULL]
			&& [scanner SCAN_FLOAT:&rect.size.width]
			&& [scanner scanString:@";" intoString:NULL]
			&& [scanner scanString:@"height" intoString:NULL]
			&& [scanner scanString:@"=" intoString:NULL]
			&& [scanner SCAN_FLOAT:&rect.size.height]
			&& [scanner scanString:@"}" intoString:NULL])
		return rect;

	return NSMakeRect(0, 0, 0, 0);
}

NSRect NSRectFromString_NEW(NSString *string)	// {{ x, y }, { width, height }}
{
	NSScanner *s = [NSScanner scannerWithString:string];
	NSRect rect;
				// FIX ME more efficient but does not handle deprecated format
	if ([s scanString:@"{" intoString:NULL]
			&& [s scanString:@"{" intoString:NULL]
			&& [s SCAN_FLOAT: &rect.origin.x]
			&& [s scanString:@"," intoString:NULL]
			&& [s SCAN_FLOAT: &rect.origin.y]
			&& [s scanString:@"}" intoString:NULL]
			&& [s scanString:@"," intoString:NULL]
			&& [s scanString:@"{" intoString:NULL]
			&& [s SCAN_FLOAT: &rect.size.width]
			&& [s scanString:@"," intoString:NULL]
			&& [s SCAN_FLOAT: &rect.size.height]
			&& [s scanString:@"}" intoString:NULL])
		return rect;

	return NSZeroRect;	// invalid
}

NSRect NSRectFromString(NSString *string)	// {{ x, y }, { width, height }}
{
	NSScanner *s = [NSScanner scannerWithString:string];
	NSRect rect;

	if ([s scanString:@"{" intoString:NULL])
		{
		if (![s scanString:@"{" intoString:NULL])
			return _NSRectFromString(string);	// deprecated prop list style

		if ( [s SCAN_FLOAT: &rect.origin.x]
				&& [s scanString:@"," intoString:NULL]
				&& [s SCAN_FLOAT: &rect.origin.y]
				&& [s scanString:@"}" intoString:NULL]
				&& [s scanString:@"," intoString:NULL]
				&& [s scanString:@"{" intoString:NULL]
				&& [s SCAN_FLOAT: &rect.size.width]
				&& [s scanString:@"," intoString:NULL]
				&& [s SCAN_FLOAT: &rect.size.height]
				&& [s scanString:@"}" intoString:NULL])
			return rect;
		}

	return NSZeroRect;	// invalid
}
