/*
   CGShading.h

   Shading drawing routines.

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGShading
#define _mGSTEP_H_CGShading

#include <CoreGraphics/CGGradient.h>


typedef const struct _CGShading * CGShadingRef;


typedef struct _CGShading {

	void *class_pointer;
	void *cf_pointer;

	CGColorSpaceRef colorspace;
	CGPoint start;
	CGPoint end;
	CGFunctionRef function;

	CGFloat startRadius;
	CGFloat endRadius;

	struct __ShadingFlags {
		unsigned int extendStart:1;			// CGGradientDrawingOptions
		unsigned int extendEnd:1;
		unsigned int radial:1;
		unsigned int reserved:5;
	} _sh;

} CGShading;



CGShadingRef CGShadingCreateAxial (CGColorSpaceRef colorspace,
								   CGPoint start,
								   CGPoint end,
								   CGFunctionRef function,
								   bool extendStart,
								   bool extendEnd);

CGShadingRef CGShadingCreateRadial (CGColorSpaceRef colorspace,
									CGPoint start,
									CGFloat startRadius,
									CGPoint end,
									CGFloat endRadius,
									CGFunctionRef function,
									bool extendStart,
									bool extendEnd);

extern CGShadingRef CGShadingRetain (CGShadingRef function);
extern void         CGShadingRelease(CGShadingRef function);

#endif  /* _mGSTEP_H_CGShading */
