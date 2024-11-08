/*
   CGDirectDisplay.h

   mini Core Graphics display interface

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGDirectDisplay
#define _mGSTEP_H_CGDirectDisplay

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/CGError.h>


typedef UInt32  CGDirectDisplayID;


extern CGDirectDisplayID  CGMainDisplayID(void);

// CGError  CGGetDisplaysWithPoint()
// CGError  CGGetDisplaysWithRect()
// CGError  CGGetDisplaysWithOpenGLDisplayMask()

extern CGRect CGDisplayBounds( CGDirectDisplayID d );	// upper left corner
extern size_t CGDisplayPixelsWide( CGDirectDisplayID d );
extern size_t CGDisplayPixelsHigh( CGDirectDisplayID d );

/* ****************************************************************************

	CGGetActiveDisplayList()

	Returns countDisplays if activeDisplays is NULL.  Otherwise activeDisplays
	if filled with upto maxDisplay entries.  First display in list is main.

** ***************************************************************************/

extern CGError CGGetActiveDisplayList(  UInt32 maxDisplays,
										CGDirectDisplayID *activeDisplays,
										UInt32 *countDisplays );

extern CGImageRef CGDisplayCreateImage( CGDirectDisplayID d );
extern CGImageRef CGDisplayCreateImageForRect( CGDirectDisplayID d, CGRect r );

extern CGError CGDisplayHideCursor( CGDirectDisplayID d );
extern CGError CGDisplayShowCursor( CGDirectDisplayID d );
extern CGError CGDisplayMoveCursorToPoint( CGDirectDisplayID d, CGPoint p);

extern CGContextRef CGDisplayGetDrawingContext( CGDirectDisplayID d );

extern void CGGetLastMouseDelta( int *dX, int *dY );

#endif /* _mGSTEP_H_CGDirectDisplay */
