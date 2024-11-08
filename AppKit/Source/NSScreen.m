/*
   NSScreen.m

   Display screen management.

   Copyright (C) 1999-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    July 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSScreen.h>



@implementation NSScreen

+ (NSScreen *) mainScreen
{
	CGContext *cx = (CGContext *)CGDisplayGetDrawingContext(CGMainDisplayID());

	return (NSScreen *)cx->_display;
}

+ (NSScreen *) deepestScreen	{ return [self mainScreen]; }
+ (NSArray *) screens			{ return nil; /* CGGetActiveDisplayList */ }

+ (id) alloc
{
	return NSAllocateObject([_NSScreen class]);
}

- (void) dealloc
{
	_CGCloseDisplay((CGDisplay *)self);
	[super dealloc];
}

- (NSRect) frame				{ return _frame; }
- (NSWindowDepth) depth			{ return _depth; }

- (NSDictionary *) deviceDescription
{
	return [NSDictionary dictionaryWithObjectsAndKeys: \
						[NSValue valueWithRect:_frame], @"FrameRect", \
						[NSNumber numberWithInt:_depth], @"NSWindowDepth", nil];
}

- (NSRect) convertRectToBacking:(NSRect)r		// assumes flipped device space
{
	NSPoint screen;

	screen.x = _frame.origin.x + r.origin.x;
	screen.y = _frame.size.height - (_frame.origin.y + r.origin.y);

	return (NSRect){screen, r.size};
}

- (NSRect) convertRectFromBacking:(NSRect)r
{
	NSPoint base;

	base.x = r.origin.x - _frame.origin.x;
	base.y = _frame.size.height - r.origin.y - _frame.origin.y;

	return (NSRect){base, r.size};
}

@end  /* NSScreen */
