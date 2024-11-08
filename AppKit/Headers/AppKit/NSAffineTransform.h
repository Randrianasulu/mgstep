/*
   NSAffineTransform.h

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSAffineTransform
#define _mGSTEP_H_NSAffineTransform

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

#include <CoreGraphics/CGAffineTransform.h>

@class NSBezierPath;


typedef CGAffineTransform  NSAffineTransformStruct;


@interface NSAffineTransform : NSObject  <NSCopying>
{
	NSAffineTransformStruct _tm;
}

+ (NSAffineTransform *) transform;

- (id) initWithTransform:(NSAffineTransform *)aTransform;

- (void) invert;

- (NSPoint) transformPoint:(NSPoint)point;
- (NSSize) transformSize:(NSSize)size;
- (NSRect) transformRect:(NSRect)rect;

- (void) rotateByDegrees:(float)angle;
- (void) rotateByRadians:(float)angle;

- (void) scaleBy:(float)scale;
- (void) scaleXBy:(float)sx yBy:(float)sy;

- (void) translateXBy:(float)deltaX yBy:(float)deltaY;

- (void) appendTransform:(NSAffineTransform *)aTransform;
- (void) prependTransform:(NSAffineTransform *)aTransform;

- (void) setTransformStruct:(NSAffineTransformStruct)aTransformStruct;
- (NSAffineTransformStruct) transformStruct;

@end


@interface NSAffineTransform  (NSAppKitAdditions)

- (void) set;
- (void) concat;

- (NSBezierPath *) transformBezierPath:(NSBezierPath *)bPath;

@end


@interface NSAffineTransform  (NotOpenStep)

- (void) scaleTo:(float)sx :(float)sy;
- (void) setFrameOrigin:(NSPoint)point;
- (void) translateToPoint:(NSPoint)point;
- (void) boundingRectFor:(NSRect)rect result:(NSRect*)result;
- (float) rotationAngle;

@end

#endif  /* _mGSTEP_H_NSAffineTransform */
