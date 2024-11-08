/*
   CGPath.h

   Graphics drawing path.

   Copyright (C) 2006-2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGPath
#define _mGSTEP_H_CGPath

#include <CoreGraphics/CGGeometry.h>


typedef enum {
	kCGLineCapButt,
	kCGLineCapRound,
	kCGLineCapSquare
} CGLineCap;

typedef enum {
	kCGLineJoinMiter,
	kCGLineJoinRound,
	kCGLineJoinBevel
} CGLineJoin;

typedef enum {
	kCGPathElementMoveToPoint,
	kCGPathElementAddLineToPoint,
	kCGPathElementAddQuadCurveToPoint,	// 1 control point and a dest point
	kCGPathElementAddCurveToPoint,		// 2 control points and a dest point
	kCGPathElementCloseSubpath
} CGPathElementType;


typedef struct _CGPathElement {

	CGPathElementType type;
	union {
		CGPoint points[3];
		struct { CGPoint p1; CGPoint p2; CGPoint p3; };
	};

} CGPathElement;


typedef const struct _CGPath *CGPathRef;
typedef       struct _CGPath *CGMutablePathRef;


typedef struct _CGPath {

	void *class_pointer;
	void *cf_pointer;

	CGPoint _p0;						// current drawing origin

	CGPoint *_vrtx;						// stroked polygon vertices
	unsigned long _vrtxCount;

	CGRect _bbox;
	CGRect _pbox;						// bbox without control points

	CGPathElement *_pe;
	unsigned long _count;
	unsigned long _capacity;
	unsigned long _subpath;				// current subpath

	bool _immutable;

} CGPath;


extern CGMutablePathRef  CGPathCreateMutable(void);

extern void       CGPathRelease( CGPathRef path );
extern CGPathRef  CGPathRetain( CGPathRef path );


//  Add a line from the current point to the start point of current subpath
extern void CGPathCloseSubpath( CGMutablePathRef path);

//  Move current point to (x,y) transformed by TM and begin a new subpath
extern void CGPathMoveToPoint( CGMutablePathRef path,
							   const CGAffineTransform *m,
							   CGFloat x, CGFloat y);

extern void CGPathAddLineToPoint( CGMutablePathRef path,
								  const CGAffineTransform *m,
								  CGFloat x, CGFloat y);

//	Add quadratic curve from current point P0 to (x,y) with control point CP.
//	Moves current point to (x,y).  Transform all points by m if not NULL.
//  Curvature is defined by tangent lines from P0 to CP and CP to (x,y).
extern void CGPathAddQuadCurveToPoint( CGMutablePathRef path,
										const CGAffineTransform *m,
										CGFloat cp_x, CGFloat cp_y,
										CGFloat x, CGFloat y);

//  Add cubic Bezier curve from current point P0 to (x,y) with control points
//  CP1 and CP2.  Move current point to (x,y).  Transform points if m not NULL.
extern void CGPathAddCurveToPoint( CGMutablePathRef path,
									const CGAffineTransform *m,
									CGFloat cp1_x, CGFloat cp1_y,
									CGFloat cp2_x, CGFloat cp2_y,
									CGFloat x, CGFloat y);

extern void CGPathAddRect( CGMutablePathRef path,
						   const CGAffineTransform *m,
						   CGRect rect);

extern void CGPathAddRects( CGMutablePathRef path,
							const CGAffineTransform *m,
							const CGRect rects[],
							size_t count);

extern void CGPathAddRoundedRect( CGMutablePathRef path,
								  const CGAffineTransform *m,
								  CGRect rect,
								  CGFloat cornerWidth,
								  CGFloat cornerHeight);

//  Add lines to the path.  Move to first point and then append lines using
//  each subsequent point in the array.  Transform points if TM is not NULL.
extern void CGPathAddLines( CGMutablePathRef path,
							const CGAffineTransform *m,
							const CGPoint points[],
							size_t count);
/*
	Add an ellipse (oval) centered in rect to the path.  The ellipse forms a
	complete subpath of path (begins with a moveto and ends with a closepath)
	and has a clockwise orientation.  The ellipse is approximated with Bezier
	curves the points of which are transformed by TM if it's not NULL.
*/
extern void CGPathAddEllipseInRect( CGMutablePathRef path,
									const CGAffineTransform *m,
									CGRect rect);
/*
	Add arc with center (x,y) and radius to the path.  An initial line segment
	may be added from the current point (P0) to the arc start point.  Arc is
	approximated with a sequence of Bezier curves the points of which will be
	tranformed by TM prior to adding if TM is not NULL.

	startAngle:  angle in radians counter-clock from X axis to start point
	delta:       startAngle + delta is the angle to the end point
                 draws clockwise if negative delta & counter-clock if positive
*/
extern void CGPathAddRelativeArc( CGMutablePathRef path,
								  const CGAffineTransform *m,
								  CGFloat x, CGFloat y,
								  CGFloat radius,
								  CGFloat startAngle,
								  CGFloat delta);
/*
	Add arc with center (x,y) and radius to the path.  An initial line segment
	may be added from the current point (P0) to the arc start point.  Arc is
	approximated with a sequence of Bezier curves the points of which will be
	tranformed by TM prior to adding if TM is not NULL.
	
	startAngle:  angle in radians counter-clock from X axis to start point
	endAngle:    angle in radians counter-clock from X axis to the end point
	clockwise:   drawing direction
*/
extern void CGPathAddArc( CGMutablePathRef path,
						  const CGAffineTransform *m,
						  CGFloat x, CGFloat y,
						  CGFloat radius,
						  CGFloat startAngle,
						  CGFloat endAngle,
						  bool clockwise);
/*
	Add an arc with radius to the path.  Arc is tangent to lines from current
	point (P0) to P1 and from P1 to P2, may produce an initial line segment.
	Arc is approximated with a sequence of Bezier curves the points of which
	are transformed by TM if not NULL.
*/
extern void CGPathAddArcToPoint( CGMutablePathRef path,
								 const CGAffineTransform *m,
								 CGFloat x1, CGFloat y1,
								 CGFloat x2, CGFloat y2,
								 CGFloat radius);

//  Add path2 to path1.  Transform points in path2 if TM is not NULL.
extern void CGPathAddPath( CGMutablePathRef p1,
						   const CGAffineTransform *m,
						   CGPathRef p2);

extern bool CGPathIsEmpty( CGPathRef p);			// YES if path has 0 nodes
extern bool CGPathIsRect( CGPathRef p, CGRect *r);	// YES if path is rect
extern bool CGPathEqualToPath(CGPathRef p1, CGPathRef p2);

//  Current point of current subpath of path or CGPointZero if there is none.
extern CGPoint CGPathGetCurrentPoint( CGPathRef p);

//  Bounding Box of path including control points for curves.  This is the
//  smallest rect enclosing all points.  Returns CGRectNull if path is empty.
extern CGRect CGPathGetBoundingBox( CGPathRef p);

//  Bounding Box of path NOT including control points for curves.  This is the
//  smallest rect enclosing all points.  Returns CGRectNull if path is empty.
extern CGRect CGPathGetPathBoundingBox( CGPathRef p);

//  Test whether point lies in path using either an Even-Odd or Winding rule.
//  Transform point to be tested if TM is not NULL.  TRUE if point is in path.
extern bool CGPathContainsPoint( CGPathRef p,
								 const CGAffineTransform *m,
								 CGPoint point,
								 bool eoFill);

/* ****************************************************************************

	Copy path
 
** ***************************************************************************/

extern CGMutablePathRef CGPathCreateMutableCopy( CGPathRef p);
extern CGPathRef        CGPathCreateCopy( CGPathRef p);

extern CGPathRef
CGPathCreateCopyByTransformingPath( CGPathRef p, const CGAffineTransform *m);

extern CGMutablePathRef
CGPathCreateMutableCopyByTransformingPath( CGPathRef p,
										   const CGAffineTransform *m);
extern CGPathRef
CGPathCreateCopyByStrokingPath( CGPathRef p,
								const CGAffineTransform *m,
								CGFloat lineWidth,
								CGLineCap lineCap,
								CGLineJoin lineJoin,
								CGFloat miterLimit);
extern CGPathRef
CGPathCreateCopyByDashingPath( CGPathRef p,
							   const CGAffineTransform *m,
							   CGFloat phase,
							   const CGFloat *lengths,
							   size_t count);

#endif  /* _mGSTEP_H_CGPath */
