/*
   CGLayer.h

   mini Core Graphics drawing layer

   Copyright (C) 2010-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Mar 2010

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGLayer
#define _mGSTEP_H_CGLayer

#include <CoreGraphics/CGContext.h>


typedef const struct _CGLayer *CGLayerRef;


typedef struct _CGLayer {

	void *class_pointer;
	void *cf_pointer;

	CGContextRef context;
	CGLayerRef   _prev;						// nested layer

	CGPoint _origin;
	CGSize  _size;

	struct __LayerFlags {
		unsigned int dontFree:1;			// alloc'd as struct, don't free
		unsigned int hasContext:1;
		unsigned int active:1;
		unsigned int reserved:5;
	} _ly;

} CGLayer;


extern CGLayerRef CGLayerCreateWithContext( CGContextRef c,
											CGSize z,
											CFDictionaryRef auxInfo);

extern CGLayerRef CGLayerRetain( CGLayerRef ly);		// accepts NULL layer
extern void 	  CGLayerRelease( CGLayerRef ly);
											// return layer's draw context, not
											// context specified at creation
extern CGContextRef CGLayerGetContext( CGLayerRef ly);

extern CGSize CGLayerGetSize( CGLayerRef ly);

extern CFTypeID CGLayerGetTypeID(void);

/* ****************************************************************************

	CGContextDrawLayerInRect

	Draw contents of layer onto context rect, scaling the contents if necessary

** ***************************************************************************/

extern void CGContextDrawLayerInRect( CGContextRef cx, CGRect r, CGLayerRef ly);

/* ****************************************************************************

	CGContextDrawLayerAtPoint

	Draw contents of layer onto context rect at point.  Equivalent to calling
	CGContextDrawLayerInRect with origin at point and size equal to layer size

** ***************************************************************************/

extern void CGContextDrawLayerAtPoint(CGContextRef cx, CGPoint p, CGLayerRef ly);

#endif /* _mGSTEP_H_CGLayer */
