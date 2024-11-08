/*
   CGPattern.h

   mini Core Graphics pattern drawing paint

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Mar 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGPattern
#define _mGSTEP_H_CGPattern

#include <CoreGraphics/CGContext.h>


typedef struct _CGPattern * CGPatternRef;


typedef enum {
	kCGPatternTilingNoDistortion,
	kCGPatternTilingConstantSpacingMinimalDistortion,
	kCGPatternTilingConstantSpacing
} CGPatternTiling;


typedef void (*CGPatternDrawPatternCallback)(void *info, CGContextRef c);
typedef void (*CGPatternReleaseInfoCallback)(void *info);

typedef struct {
	unsigned int version;
	CGPatternDrawPatternCallback drawPattern;
	CGPatternReleaseInfoCallback releaseInfo;
} CGPatternCallbacks;


typedef struct _CGPattern {

	void *class_pointer;
	void *cf_pointer;

	CGRect bounds;
	
	CGFloat xStep;
	CGFloat yStep;

	CGImageRef bitmap;						// pattern buffer

	const CGPatternCallbacks *callbacks;

	void *info;

	struct __PatternFlags {
		unsigned int dontFree:1;			// alloc'd as struct, don't free
		CGPatternTiling patternTiling:2;
		unsigned int isColored:1;
		unsigned int reserved:4;
	} _pf;

} CGPattern;


extern CGPatternRef CGPatternCreate(void *info,
									CGRect bounds,
									CGAffineTransform m,
									CGFloat xStep, CGFloat yStep,
									CGPatternTiling pt,
									bool isColored,
									const CGPatternCallbacks *callbacks);

extern CGPatternRef CGPatternRetain ( CGPatternRef pat);
extern void 	    CGPatternRelease( CGPatternRef pat);

extern CFTypeID CGPatternGetTypeID(void);


extern void CGContextSetFillPattern(CGContextRef c,
									CGPatternRef p,
									const CGFloat components[]);
extern void CGContextSetStrokePattern(CGContextRef c,
									  CGPatternRef p,
									  const CGFloat components[]);

extern CGColorRef CGColorCreateWithPattern( CGColorSpaceRef s,
											CGPatternRef p,
											const CGFloat components[]);

#endif /* _mGSTEP_H_CGPattern */
