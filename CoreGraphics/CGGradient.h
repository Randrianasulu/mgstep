/*
   CGGradient.h

   Gradient drawing routines.

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGGradient
#define _mGSTEP_H_CGGradient

#include <CoreGraphics/CGGeometry.h>


typedef enum _CGGradientDrawingOptions {
	kCGGradientDrawsBeforeStartLocation = 1,
	kCGGradientDrawsAfterEndLocation    = 2
} CGGradientDrawingOptions;


typedef const struct CGGradient * CGGradientRef;
typedef const struct CGFunction * CGFunctionRef;


typedef struct CGGradient {

	void *class_pointer;
	void *cf_pointer;

	CGColorSpaceRef colorspace;
	
	CGFloat *components;
	CGFloat *locations;
	size_t   count;

} CGGradient;


/* ****************************************************************************

	CGGradientCreateWithColorComponents

	Creates a gradient between locations paired to colors at those locations

	components:  sets of color components in color space
	locations:   0 - 1.0, or NULL  (if NULL first color is at location 0 and
                 last is at location 1 with all others equidistant.
	count:       number of locations, components = count * colors in space

** ***************************************************************************/

extern CGGradientRef
CGGradientCreateWithColorComponents(CGColorSpaceRef colorspace,
									const CGFloat components[],
									const CGFloat locations[],
									size_t count);

extern CGGradientRef CGGradientRetain (CGGradientRef gradient);
extern         void  CGGradientRelease(CGGradientRef gradient);


#if 0

CFTypeID CGGradientGetTypeID(void)

CGGradientRef CGGradientCreateWithColorComponents(CGColorSpaceRef
    colorspace, const CGFloat components[], const CGFloat locations[], size_t count)

CGGradientRef CGGradientCreateWithColors(CGColorSpaceRef colorspace,
    CFArrayRef colors, const CGFloat locations[])

#endif


/* ****************************************************************************

	CGFunctionEvaluateCallback

	callback which evaluates using 'in' as input and puts results in 'out'

	info		parameter passed to CGFunctionCreate.
	in	*	    array of floats, size specified in domain dimension
	out *		array of floats, size specified in range dimension

** ***************************************************************************/

typedef void (*CGFunctionEvaluateCallback)(void *info, const CGFloat *in, CGFloat *out);


/* ****************************************************************************

	CGFunctionReleaseInfoCallback

	callback to release the info parameter passed to the CGFunction creation
	functions when the function is deallocated

	info   'info' param passed to CGFunctionCreate

** ***************************************************************************/

typedef void (*CGFunctionReleaseInfoCallback)(void *info);


/* ****************************************************************************

	CGFunctionCallbacks

	Structure containing the callbacks of a CGFunction.

	version		 version number of the structure passed to the CGFunction
	evaluate	 callback used to evaluate the function.
	releaseInfo	 callback used to release the info parameter (if not NULL)
 
** ***************************************************************************/

typedef struct _CGFunctionCallbacks {
    unsigned int                   version;
    CGFunctionEvaluateCallback     evaluate;
    CGFunctionReleaseInfoCallback  releaseInfo;
} CGFunctionCallbacks;


typedef struct CGFunction {

	void *class_pointer;
	void *cf_pointer;

	void   *info;
	size_t domainDimension;
	size_t rangeDimension;
	const  CGFloat *domain;
	const  CGFloat *range;
	const  CGFunctionCallbacks *callbacks;

} CGFunction;


extern CGFunctionRef
CGFunctionCreate(void *info,
				 size_t domainDimension,
				 const CGFloat *domain,
				 size_t rangeDimension,
				 const CGFloat *range,
				 const CGFunctionCallbacks *callbacks);

extern void          CGFunctionRelease (CGFunctionRef fn);
extern CGFunctionRef CGFunctionRetain  (CGFunctionRef fn);

#endif  /* _mGSTEP_H_CGGradient */
