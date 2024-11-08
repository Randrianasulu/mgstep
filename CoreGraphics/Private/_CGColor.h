/*
   _CGColor.h

   CG Color private interface

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _H_CGColor
#define _H_CGColor

#include <AppKit/NSColor.h>


#if !defined( FB_GRAPHICS ) && defined( _mGSTEP_H_CoreGraphics_Private )

@interface XRColor : NSColor
{
	XColor xColor;
}

@end

@interface NSColor (XRColor)

- (XColor) xColor;

@end

#endif


extern void _CGColorConvertHSBtoRGB(struct HSB_Color h, struct RGB_Color *r);
extern void _CGColorConvertHSBtoRGB_n(struct HSB_Color h, struct RGB_Color *r);

#endif /* _H_CGColor */
