/*
   NSBezierPath.h

   Bezier drawing path class

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Enrico Sersale <enrico@imago.ro>
   Date:    Dec 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBezier
#define _mGSTEP_H_NSBezier

#include <Foundation/Foundation.h>
#include <AppKit/NSFont.h>

@class NSAffineTransform;
@class NSImage;

typedef enum {
	NSButtLineCapStyle   = 0,
	NSRoundLineCapStyle  = 1,
	NSSquareLineCapStyle = 2
} NSLineCapStyle;

typedef enum {
	NSMiterLineJoinStyle = 0,
	NSRoundLineJoinStyle = 1,
	NSBevelLineJoinStyle = 2
} NSLineJoinStyle;

typedef enum {
	NSNonZeroWindingRule,
	NSEvenOddWindingRule
} NSWindingRule;

typedef enum {
	NSMoveToBezierPathElement,
	NSLineToBezierPathElement,
	_NSQuadCurveToBezierPathElement,
	NSCurveToBezierPathElement,
	NSClosePathBezierPathElement
} NSBezierPathElement;


@interface NSBezierPath : NSObject  <NSCopying, NSCoding>
{
	NSUInteger _dashCount;
	CGFloat _dashPhase;
	CGFloat *_dashPattern;
	float _lineWidth;
	float _flatness;
	float _miterLimit;
	NSRect _bounds;
	NSRect _controlPointBounds;
	NSImage *_cacheImage;
	
	void *_path;

    struct __BezierFlags {
		NSWindingRule windingRule:2;
		NSLineCapStyle lineCapStyle:2;
		NSLineJoinStyle lineJoinStyle:2;
		unsigned int flat:1;
		unsigned int cachesBezierPath:1;
		unsigned int unknownBounds:1;
		unsigned int reserved:7;
	} _bz;
}

+ (NSBezierPath *) bezierPath;							// Create common paths
+ (NSBezierPath *) bezierPathWithRect:(NSRect)aRect;
+ (NSBezierPath *) bezierPathWithOvalInRect:(NSRect)rect;

+ (void) fillRect:(NSRect)aRect;						// Immediate drawing
+ (void) strokeRect:(NSRect)aRect;
+ (void) clipRect:(NSRect)aRect;
+ (void) strokeLineFromPoint:(NSPoint)point1 toPoint:(NSPoint)point2;
+ (void) drawPackedGlyphs:(const char *)packedGlyphs atPoint:(NSPoint)aPoint;

+ (float) defaultMiterLimit;							// Default path
+ (float) defaultLineWidth;								// rendering parameters
+ (float) defaultFlatness;
+ (void) setDefaultMiterLimit:(float)limit;
+ (void) setDefaultLineWidth:(float)lineWidth;
+ (void) setDefaultFlatness:(float)flatness;
+ (void) setDefaultWindingRule:(NSWindingRule)windingRule;
+ (void) setDefaultLineCapStyle:(NSLineCapStyle)lineCapStyle;
+ (void) setDefaultLineJoinStyle:(NSLineJoinStyle)lineJoinStyle;
+ (NSLineJoinStyle) defaultLineJoinStyle;
+ (NSLineCapStyle) defaultLineCapStyle;
+ (NSWindingRule) defaultWindingRule;

- (void) moveToPoint:(NSPoint)aPoint;					// Path construction
- (void) lineToPoint:(NSPoint)aPoint;
- (void) curveToPoint:(NSPoint)aPoint 
		 controlPoint1:(NSPoint)controlPoint1
		 controlPoint2:(NSPoint)controlPoint2;
- (void) closePath;
- (void) removeAllPoints;

//
// Relative path construction
//
- (void) relativeMoveToPoint:(NSPoint)aPoint;
- (void) relativeLineToPoint:(NSPoint)aPoint;
- (void) relativeCurveToPoint:(NSPoint)aPoint
				controlPoint1:(NSPoint)controlPoint1
				controlPoint2:(NSPoint)controlPoint2;

//
// Path rendering parameters
//
- (float) lineWidth;
- (float) flatness;
- (float) miterLimit;
- (NSLineCapStyle) lineCapStyle;
- (NSLineJoinStyle) lineJoinStyle;
- (NSWindingRule) windingRule;
- (void) setLineWidth:(float)lineWidth;
- (void) setFlatness:(float)flatness;
- (void) setMiterLimit:(float)limit;
- (void) setLineCapStyle:(NSLineCapStyle)lineCapStyle;
- (void) setLineJoinStyle:(NSLineJoinStyle)lineJoinStyle;
- (void) setWindingRule:(NSWindingRule)windingRule;
- (void) getLineDash:(float *)pattern count:(int *)count phase:(float *)phase;
- (void) setLineDash:(const float*)pattern count:(int)count phase:(float)phase;

- (void) stroke;										// Path operations
- (void) fill;
- (void) addClip;
- (void) setClip;

- (NSBezierPath *) bezierPathByFlatteningPath;			// Path modifications
- (NSBezierPath *) bezierPathByReversingPath;

- (void) transformUsingAffineTransform:(NSAffineTransform *)transform;

- (BOOL) isEmpty;										// Path info
- (NSPoint) currentPoint;
- (NSRect) controlPointBounds;
- (NSRect) bounds;
- (int) elementCount;

- (NSBezierPathElement) elementAtIndex:(int)index;		// Element access
- (NSBezierPathElement) elementAtIndex:(int)index
						associatedPoints:(NSPoint *)points;
- (void) setAssociatedPoints:(NSPoint *)points atIndex:(int)index;

//
// Appending common paths
//
- (void) appendBezierPath:(NSBezierPath *)aPath;
- (void) appendBezierPathWithRect:(NSRect)rect;
- (void) appendBezierPathWithPoints:(NSPoint *)points count:(int)count;
- (void) appendBezierPathWithOvalInRect:(NSRect)aRect;
- (void) appendBezierPathWithArcWithCenter:(NSPoint)center  
									radius:(float)radius
									startAngle:(float)startAngle
									endAngle:(float)endAngle
									clockwise:(BOOL)clockwise;
- (void) appendBezierPathWithArcWithCenter:(NSPoint)center  
									radius:(float)radius
									startAngle:(float)startAngle
									endAngle:(float)endAngle;
- (void) appendBezierPathWithArcFromPoint:(NSPoint)point1
								  toPoint:(NSPoint)point2
								  radius:(float)radius;
- (void) appendBezierPathWithGlyph:(NSGlyph)glyph inFont:(NSFont *)font;
- (void) appendBezierPathWithGlyphs:(NSGlyph *)glyphs 
							  count:(int)count
							  inFont:(NSFont *)font;
- (void) appendBezierPathWithPackedGlyphs:(const char *)packedGlyphs;

- (BOOL) containsPoint:(NSPoint)point;					// Hit detection

- (BOOL) cachesBezierPath;								// Caching
- (void) setCachesBezierPath:(BOOL)flag;

@end

#endif  /* _mGSTEP_H_NSBezier */
