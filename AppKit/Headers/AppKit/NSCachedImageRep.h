/*
   NSCachedImageRep.h

   Cached image representation.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSCachedImageRep
#define _mGSTEP_H_NSCachedImageRep

#include <AppKit/NSImageRep.h>
#include <AppKit/NSGraphics.h>

@class NSWindow;

@interface NSCachedImageRep : NSImageRep
{
    NSPoint _origin;
	NSWindow *_window;
}

- (id) initWithWindow:(NSWindow *)aWindow rect:(NSRect)aRect;
- (id) initWithSize:(NSSize)aSize
			  depth:(NSWindowDepth)aDepth
			  separate:(BOOL)separate
			  alpha:(BOOL)alpha;

- (NSRect) rect;
- (NSWindow *) window;

@end

#endif /* _mGSTEP_H_NSCachedImageRep */
