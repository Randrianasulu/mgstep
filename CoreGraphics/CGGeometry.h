/*
   CGGeometry.h

   mini Core Graphics types.

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGGeometry
#define _mGSTEP_H_CGGeometry

#include <CoreFoundation/CFBase.h>

#include <float.h>
#include <math.h>


#if defined(__LP64__) && __LP64__
  typedef double      CGFloat;
  #define SCAN_FLOAT  scanDouble
#else
  typedef float       CGFloat;
  #define SCAN_FLOAT  scanFloat
#endif


#define CGRectMake   NSMakeRect
#define CGSizeMake   NSMakeSize
#define CGPointMake  NSMakePoint


typedef struct _CGPoint {
	CGFloat x;
	CGFloat y;
} CGPoint;											// Point

typedef struct _CGSize {
	CGFloat width;
	CGFloat height;
} CGSize;											// Size

typedef struct _CGRect {
	CGPoint origin;
	CGSize  size;
} CGRect;											// Rectangle

typedef enum _CGRectEdge {
	CGRectMinXEdge,
	CGRectMinYEdge,
	CGRectMaxXEdge,
	CGRectMaxYEdge
} CGRectEdge;										// sides of a rectangle


extern const CGPoint CGPointZero;  					// zero point
extern const CGSize  CGSizeZero;    				// zero size rectangle
extern const CGRect  CGRectZero;    				// zero origin rectangle

extern const CGRect  CGRectNull;
extern const CGRect  CGRectInfinite;


typedef struct _CGVector {
	CGFloat dx;
	CGFloat dy;
} CGVector;

extern CGVector  CGVectorMake(CGFloat dx, CGFloat dy);

extern bool CGRectIsEmpty( CGRect r);
extern bool CGRectIsNull( CGRect r);
extern bool CGRectIsInfinite( CGRect r);
extern bool CGRectContainsPoint(CGRect r, CGPoint p);

extern CGRect  CGRectStandardize(CGRect r);		// equiv rect with positive w,h


#endif  /* _mGSTEP_H_CGGeometry */
