/*
   NSColorWell.h

   Color selection and display control.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSColorWell
#define _mGSTEP_H_NSColorWell

#include <AppKit/NSControl.h>

@class NSColor;


@interface NSColorWell : NSControl  <NSCoding>
{
	NSColor *_color;

	struct __ColorWellFlags {
		unsigned int isActive:1;
		unsigned int isBordered:1;
		unsigned int reserved:6;
	} _cw;
}

- (void) drawWellInside:(NSRect)insideRect;				// Drawing

- (void) activate:(BOOL)exclusive;						// Activation
- (void) deactivate;
- (BOOL) isActive;

- (NSColor *) color;									// Managing Color
- (void) setColor:(NSColor *)color;
- (void) takeColorFrom:(id)sender;

- (BOOL) isBordered;									// Graphic attributes
- (void) setBordered:(BOOL)bordered;

@end

#endif /* _mGSTEP_H_NSColorWell */
