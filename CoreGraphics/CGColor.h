/*
   CGColor.h

   Bridged to NSColor

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGColor
#define _mGSTEP_H_CGColor

#include <CoreGraphics/CGColorSpace.h>


typedef struct _NSColor * CGColorRef;


extern CGColorRef CGColorCreate(CGColorSpaceRef s, const CGFloat components[]);

extern CGColorRef CGColorCreateGenericGray(CGFloat gray, CGFloat alpha);

extern CGColorRef CGColorCreateGenericRGB( CGFloat red,
										   CGFloat green,
										   CGFloat blue,
										   CGFloat alpha);

extern CGColorRef CGColorRetain ( CGColorRef c);
extern void       CGColorRelease( CGColorRef c);

extern CGFloat CGColorGetAlpha(CGColorRef c);

extern const CGFloat * CGColorGetComponents(CGColorRef c);	// including alpha
extern size_t CGColorGetNumberOfComponents(CGColorRef c);	// including alpha

#if 0
extern const CFStringRef kCGColorWhite;				// constant color names
extern const CFStringRef kCGColorBlack;
extern const CFStringRef kCGColorClear;

extern CGColorRef CGColorGetConstantColor(CFStringRef colorName);

extern CGColorSpaceRef CGColorGetColorSpace(CGColorRef c);

#endif

#endif  /* _mGSTEP_H_CGColor */
