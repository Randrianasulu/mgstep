/*
   NSGeometry.h

   Geometry routines and structures

   Copyright (C) 1995-2020 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@boulder.colorado.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSGeometry
#define _mGSTEP_H_NSGeometry

#include <Foundation/NSObjCRuntime.h>
#include <CoreGraphics/CGGeometry.h>

@class NSString;


typedef CGRect	 NSRect;
typedef CGSize	 NSSize;
typedef CGPoint	 NSPoint;

typedef enum _NSRectEdge {
	NSMinXEdge,
	NSMinYEdge,
	NSMaxXEdge,
	NSMaxYEdge
} NSRectEdge;										// sides of a rectangle


extern const NSPoint NSZeroPoint;  					// zero point
extern const NSRect  NSZeroRect;    				// zero origin rectangle
extern const NSSize  NSZeroSize;    				// zero size rectangle

				// Returns NSPoint having x-coordinate X and y-coordinate Y
extern NSPoint NSMakePoint(CGFloat x, CGFloat y);
				// Returns NSSize having width WIDTH and height HEIGHT
extern NSSize  NSMakeSize(CGFloat w, CGFloat h);
				// Returns NSRect having point of origin (X, Y) and size {W, H}
extern NSRect  NSMakeRect(CGFloat x, CGFloat y, CGFloat w, CGFloat h);

#define	NSMaxX(r)	 ((r).origin.x + (r).size.width)           // max x coord
#define	NSMaxY(r)	 ((r).origin.y + (r).size.height)          // max y coord
#define	NSMidX(r)	 ((r).origin.x + (r).size.width / 2.0)     // mid x coord
#define	NSMidY(r)	 ((r).origin.y + (r).size.height / 2.0)    // mid y coord
#define	NSMinX(r)	 ((r).origin.x)                            // min x coord
#define	NSMinY(r)	 ((r).origin.y)                            // min y coord
#define	NSWidth(r)	 ((r).size.width)                          // rect width
#define	NSHeight(r)	 ((r).size.height)                         // rect height

						// Returns the rectangle obtained by moving each of
						// ARECT's horizontal sides inward by DY and each of 
						// ARECT's vertical sides inward by DX.
extern NSRect NSInsetRect(NSRect aRect, CGFloat dX, CGFloat dY);

						// Returns the rectangle obtained by translating ARECT
						// horizontally by DX and vertically by DY
extern NSRect NSOffsetRect(NSRect aRect, CGFloat dX, CGFloat dY);

						// Divide ARECT into rectangles SLICE and REMAINDER by
						// "cutting" ARECT parallel to, and a distance AMOUNT
						// from the edge v of ARECT determined by EDGE.  Pass 0
						// for SLICE or REMAINDER to avoid a return value.
extern void NSDivideRect(NSRect aRect,
						NSRect *slice,
						NSRect *remainder,		// FIX ME if NULL
						float amount,
						NSRectEdge edge);

						// Returns a rect obtained by expanding ARECT minimally
						// so that all four of its defining components are ints
extern NSRect NSIntegralRect(NSRect aRect);

						// Returns the smallest rectangle which contains both 
						// ARECT and BRECT (modulo a set of measure zero).  If 
						// either of ARECT or BRECT is an empty rectangle, then 
						// the other rectangle is returned.  If both are empty, 
						// then the empty rectangle is returned.
extern NSRect NSUnionRect(NSRect aRect, NSRect bRect);

						// Returns the largest rect which lies in both ARECT 
						// and BRECT.  If ARECT & BRECT have empty intersection 
						// (or, rather, intersection of measure zero, since 
						// this includes having their intersection be only a 
						// point or a line), then the empty rect is returned.
extern NSRect NSIntersectionRect(NSRect aRect, NSRect bRect);

						// Returns 'YES' if ARECT's and BRECT's origin and size 	
						// are the same.
extern BOOL NSEqualRects(NSRect aRect, NSRect bRect);

						// Returns 'YES' if ASIZE's and BSIZE's width and 
						// height are the same.
extern BOOL NSEqualSizes(NSSize aSize, NSSize bSize);

						// Returns 'YES' iff APOINT's and BPOINT's x- and 
						// y-coordinates are the same. */
extern BOOL NSEqualPoints(NSPoint aPoint, NSPoint bPoint);

						// Returns 'YES' iff the area of ARECT is zero (if 
						// either ARECT's width or height is negative or zero).
extern BOOL NSIsEmptyRect(NSRect aRect);

						// Returns 'YES' iff APOINT is inside ARECT.
extern BOOL NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped);
extern BOOL NSPointInRect(NSPoint aPoint, NSRect aRect);

						// Returns 'YES' if ARECT totally encloses BRECT.
						// For this to be true, BRECT can't be empty and can't
						// extend beyond ARECT in any direction.
extern BOOL NSContainsRect(NSRect aRect, NSRect bRect);

						// Returns Yes if aRect intersects bRect.
extern BOOL NSIntersectsRect(NSRect aRect, NSRect bRect);

					// Returns an NSString of the form "{x=X; y=Y}", where X  
					// and Y are the x-, y-coordinates of APOINT, respectively.
extern NSString * NSStringFromPoint(NSPoint aPoint);

					// Returns an NSString of the form "{x=X; y=Y; width=W; 
					// height=H}", where X, Y, W, and H are the x-coordinate, 
					// y-coordinate, width, and height of ARECT, respectively.
extern NSString * NSStringFromRect(NSRect aRect);

					// Returns an NSString of the form "{width=W; height=H}", 
					// where W and H are the width and height of ASIZE.
extern NSString * NSStringFromSize(NSSize aSize);

extern NSPoint NSPointFromString(NSString *string);
extern NSSize  NSSizeFromString(NSString *string);
extern NSRect  NSRectFromString(NSString *string);

static inline NSPoint NSPointFromCGPoint(CGPoint p)		{ return p; }


#ifdef USE_FLT_EPSILON					// allow for machine epsilon error
//#define CG_FLT_EPSILON	0.000001
  #define FLT_EQ(a, b)		(fabs(a - b) <= FLT_EPSILON)
  #define POINTS_EQ(a, b)	(  (fabs(a.x - b.x) <= FLT_EPSILON) \
  							&& (fabs(a.y - b.y) <= FLT_EPSILON))
  #define SIZE_EQ(a, b)		(  (fabs(a.width - b.width) <= FLT_EPSILON) \
							&& (fabs(a.height - b.height) <= FLT_EPSILON) )
#else
  #define FLT_EQ(a, b)		(a == b)
  #define POINTS_EQ(a, b)	((a.x == b.x) && (a.y == b.y))
  #define SIZE_EQ(a, b)		((a.width == b.width) && (a.height == b.height))
#endif

#endif /* _mGSTEP_H_NSGeometry */
