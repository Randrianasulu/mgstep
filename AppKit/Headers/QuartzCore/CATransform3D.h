/*
   CATransform3D.h

   3D transform matrix

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CATransform3D
#define _mGSTEP_H_CATransform3D

#include <CoreFoundation/CoreFoundation.h>


typedef struct _CATransform3D
{
	CGFloat m11, m12, m13, m14;
	CGFloat m21, m22, m23, m24;
	CGFloat m31, m32, m33, m34;
	CGFloat m41, m42, m43, m44;

} CATransform3D;

			// 3D identity matrix [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1]
extern const CATransform3D CATransform3DIdentity;


#if 0		// FIX ME define and implement CATransform3D

extern BOOL CATransform3DIsIdentity (CATransform3D t);

extern BOOL CATransform3DEqualToTransform (CATransform3D a, CATransform3D b);
			// t' =  [1 0 0 0; 0 1 0 0; 0 0 1 0; tx ty tz 1]. */
extern CATransform3D CATransform3DMakeTranslation (CGFloat tx, CGFloat ty, CGFloat tz);
			// t' = [sx 0 0 0; 0 sy 0 0; 0 0 sz 0; 0 0 0 1]. */
extern CATransform3D CATransform3DMakeScale (CGFloat sx, CGFloat sy, CGFloat sz);
extern CATransform3D CATransform3DMakeRotation (CGFloat angle, CGFloat x,  CGFloat y, CGFloat z);
extern CATransform3D CATransform3DTranslate (CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz);
extern CATransform3D CATransform3DScale (CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz);
extern CATransform3D CATransform3DRotate (CATransform3D t, CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
extern CATransform3D CATransform3DConcat (CATransform3D a, CATransform3D b);
extern CATransform3D CATransform3DInvert (CATransform3D t);
extern CATransform3D CATransform3DMakeAffineTransform (CGAffineTransform m);
extern BOOL CATransform3DIsAffine (CATransform3D t);
extern CGAffineTransform CATransform3DGetAffineTransform (CATransform3D t);


@interface NSValue (CATransform3DAdditions)

+ (NSValue *) valueWithCATransform3D:(CATransform3D)transform;

- (CATransform3D) CATransform3DValue;

@end

#endif

#endif /* _mGSTEP_H_CATransform3D */
