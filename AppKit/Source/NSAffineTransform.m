/*
   NSAffineTransform.m

   Copyright (C) 1997-2020 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>


#define CONTEXT		_CGContext()

#define A	_tm.a
#define B	_tm.b
#define C	_tm.c
#define D	_tm.d
#define TX	_tm.tx
#define TY	_tm.ty



/* ****************************************************************************

	Affine Transform:

    [  a  b  0 ]
    [  c  d  0 ]
    [ tx ty  1 ]

** ***************************************************************************/

@implementation NSAffineTransform

+ (NSAffineTransform *) transform
{
	NSAffineTransform *m = (NSAffineTransform *)NSAllocateObject(self);

	m->A = m->D = 1;									// init identity matrix
														// which transforms any
	return [m autorelease];								// point to itself
}

+ (NSAffineTransform *) new
{
	NSAffineTransform *m = (NSAffineTransform *)NSAllocateObject(self);

	m->A = m->D = 1;									// init identity matrix

	return m;
}

- (id) initWithTransform:(NSAffineTransform *)aTransform
{
	_tm = aTransform->_tm;

	return self;
}

- (id) init
{
	A = D = 1;											// init identity matrix

	return self;
}

- (id) copy
{
	NSAffineTransform *new = [isa alloc];

	memcpy (&new->_tm, &_tm, sizeof(NSAffineTransformStruct));

	return new;
}

- (void) concat							{ CGContextConcatCTM(CONTEXT, _tm); }
- (void) set							{ CGContextSetCTM(CONTEXT, _tm); }

- (void) scaleBy:(float)scale
{
	A *= scale;
	D *= scale;
}

- (void) scaleXBy:(float)sx yBy:(float)sy
{
	A *= sx;
	D *= sy;
}

- (void) translateXBy:(float)deltaX yBy:(float)deltaY
{
	TX += deltaX;
	TY += deltaY;
}

- (void) rotateByDegrees:(float)angle
{
	float angleRad = M_PI * angle / 180;

	_tm = CGAffineTransformRotate(_tm, angleRad);
}

- (void) rotateByRadians:(float)angleRad
{
	_tm = CGAffineTransformRotate(_tm, angleRad);
}

- (void) prependTransform:(NSAffineTransform*)other
{
	_tm = CGAffineTransformConcat(_tm, other->_tm);
}

- (void) appendTransform:(NSAffineTransform*)other
{
	_tm = CGAffineTransformConcat(other->_tm, _tm);
}

- (void) invert
{
	_tm = CGAffineTransformInvert(_tm);
}

- (NSPoint) transformPoint:(NSPoint)point
{
	NSPoint p;
	
	p.x = A * point.x + C * point.y + TX;
	p.y = B * point.x + D * point.y + TY;
	
	return p;
}

- (NSSize) transformSize:(NSSize)size
{
	NSSize new;
	
	new.width = A * size.width + C * size.height;
	new.height = B * size.width + D * size.height;
	
	return new;
}

- (NSRect) transformRect:(NSRect)rect
{
	NSRect new;

	new.origin.x = A * rect.origin.x + C * rect.origin.y + TX;
	new.origin.y = B * rect.origin.x + D * rect.origin.y + TY;
	new.size.width = A * rect.size.width + C * rect.size.height;
	new.size.height = B * rect.size.width + D * rect.size.height;

	return new;
}

- (NSString *) description
{
	NSString *fmt = @"NSAffineTransform ((%f, %f) (%f, %f) (%f, %f))";

	return [NSString stringWithFormat: fmt, A, B, C, D, TX, TY];
}

- (NSAffineTransformStruct) transformStruct
{
	return _tm;
}

- (void) setTransformStruct:(NSAffineTransformStruct)tms
{
	memcpy(&_tm, &tms, sizeof(NSAffineTransformStruct));
}

- (NSBezierPath *) transformBezierPath:(NSBezierPath *)bp
{
	NSBezierPath *np = [bp copy];

	[np transformUsingAffineTransform: self];

	return np;
}

@end  /* NSAffineTransform */


@implementation NSAffineTransform  (AppKitExtensions)

- (void) scaleTo:(float)sx :(float)sy
{
	double angle = 0;

	if (!(C == 0 && A >= 0))					// if rotated determine angle
		angle = atan2(C, A) * 180.0 / M_PI;

	A = sx; B = 0;
	C = 0; D = sy;

	if (angle != 0) 
		[self rotateByDegrees:angle];
}

- (void) setFrameOrigin:(NSPoint)point
{
	float dx = point.x - TX;
	float dy = point.y - TY;

	TX = dx * A + dy * C + TX;						// translate to point
	TY = dx * B + dy * D + TY;
}

- (float) rotationAngle
{
	return (C == 0 && A >= 0) ? 0.0 : atan2(C, A) * 180.0 / M_PI;
}

- (void) translateToPoint:(NSPoint)point
{
	TX = point.x * A + point.y * C + TX;
	TY = point.x * B + point.y * D + TY;
}

- (void) boundingRectFor:(NSRect)rect result:(NSRect*)new
{
	if (C == 0 && A >= 0)				// rotation == 0
		*new = rect;
	else
		{
		double rotationAngle = atan2(C, A) * 180.0 / M_PI;
		int a = (int)(rotationAngle / 360);
		float angle = rotationAngle - a * rotationAngle;
		float angleRad = M_PI * angle / 180;
		float angle90Rad = M_PI * (angle + 90) / 180;
		float cosWidth = cos(angleRad);
		float cosHeight = cos(angle90Rad);
		float sinWidth = sin(angleRad);
		float sinHeight = sin(angle90Rad);
		float x = rect.origin.x;		// Shortcuts of the usual rect values
		float y = rect.origin.y;
		float width = rect.size.width;
		float height = rect.size.height;

		if (angle <= 90) 
			{
			new->origin.x = x + height * cosHeight;
			new->origin.y = y;
			new->size.width = width * cosWidth - height * cosHeight;
			new->size.height = width * sinWidth + height * sinHeight;
			}
		else if (angle <= 180) 
			{
			new->origin.x = x + width * cosWidth + height * cosHeight;
			new->origin.y = y + height * sinHeight;
			new->size.width = -width * cosWidth - height * cosHeight;
			new->size.height = width * sinWidth - height * sinHeight;
			}
		else if (angle <= 270) 
			{
			new->origin.x = x + width * cosWidth;
			new->origin.y = y + width * sinWidth + height * sinHeight;
			new->size.width = -width * cosWidth + height * cosHeight;
			new->size.height = -width * sinWidth - height * sinHeight;
			}
		else 
			{
			new->origin.x = x;
			new->origin.y = y;
			new->size.width = width * cosWidth + height * cosHeight;
			new->size.height = width * sinWidth + height * sinHeight;
		}	}
}

@end  /* NSAffineTransform (AX_Extensions) */
