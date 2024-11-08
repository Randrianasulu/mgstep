/*
   CGAffineTransform.h

   mini Core Graphics affine transform.

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGAffineTransform
#define _mGSTEP_H_CGAffineTransform

#include <CoreGraphics/CGGeometry.h>


typedef struct _CGAffineTransform {

	union {
		CGFloat m[6];
		struct {
			CGFloat a;  CGFloat b;
			CGFloat c;  CGFloat d;
			CGFloat tx; CGFloat ty;
		};
	};

} CGAffineTransform;


extern const CGAffineTransform  CGAffineTransformIdentity;	// [ 1 0 0 1 0 0 ]

	// make TM:  t = [ a b c d tx ty ]
extern CGAffineTransform CGAffineTransformMake( CGFloat a, CGFloat b,
												CGFloat c, CGFloat d,
												CGFloat tx, CGFloat ty);
	// make scale TM:  t' = [ sx 0 0 sy 0 0 ]
extern CGAffineTransform CGAffineTransformMakeScale(CGFloat sw, CGFloat sh);

	// make translate TM:   t' = [ 1 0 0 1 tx ty ]
extern CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty);

	// make rotate TM:  radians t' = [ cos(r) sin(r) -sin(r) cos(r) 0 0 ]
extern CGAffineTransform CGAffineTransformMakeRotation(CGFloat radian_angle);

extern bool CGAffineTransformEqualToTransform( CGAffineTransform t1,
											   CGAffineTransform t2);

	// translate TM:  t' = [ 1 0 0 1 tx ty ] * t
extern CGAffineTransform CGAffineTransformTranslate( CGAffineTransform t,
													 CGFloat tx, CGFloat ty);
	// scale TM:  t' = [ sx 0 0 sy 0 0 ] * t
extern CGAffineTransform CGAffineTransformScale( CGAffineTransform t,
												 CGFloat sx, CGFloat sy);

	// rotate TM radians angle:  t' =  [ cos(r) sin(r) -sin(r) cos(r) 0 0 ] * t
extern CGAffineTransform CGAffineTransformRotate(CGAffineTransform t, CGFloat ra);

	// invert TM if t does not have a zero determinant
extern CGAffineTransform CGAffineTransformInvert( CGAffineTransform t);

	// concat TM t2 to t1:  t' = t1 * t2
extern CGAffineTransform CGAffineTransformConcat( CGAffineTransform t1,
												  CGAffineTransform t2);

//extern CGPoint CGPointApplyAffineTransform( CGPoint p,  CGAffineTransform t);
//extern CGSize  CGSizeApplyAffineTransform( CGSize size, CGAffineTransform t);
extern CGRect  CGRectApplyAffineTransform( CGRect rect, CGAffineTransform t);

static inline CGPoint
_CGPointApplyAffineTransform(CGPoint p, CGAffineTransform t)
{
	return (CGPoint){ (CGFloat)(t.a * p.x + t.c * p.y + t.tx),
					  (CGFloat)(t.b * p.x + t.d * p.y + t.ty) };
}

static inline CGSize
_CGSizeApplyAffineTransform(CGSize s, CGAffineTransform t)
{
	return (CGSize){ (CGFloat)(t.a * s.width + t.c * s.height),
					 (CGFloat)(t.b * s.width + t.d * s.height) };
}

#define CGPointApplyAffineTransform  _CGPointApplyAffineTransform
#define CGSizeApplyAffineTransform   _CGSizeApplyAffineTransform

#endif  /* _mGSTEP_H_CGAffineTransform */
