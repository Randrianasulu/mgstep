/*
   NSBezierPath.m

   Bezier path drawing class

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Enrico Sersale <enrico@imago.ro>
   Date:    Dec 1999
   Author:  Fred Kiefer <FredKiefer@gmx.de>
   Date:    January 2001

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSImage.h>


#define PMAX		10000
#define KAPPA		0.5522847498		// magic number = 4 *(sqrt(2) -1)/3
										// Bézier approximation for circle arc
#define CONTEXT		_CGContext()


static float __defaultLineWidth  = _CG_LINE_WIDTH;
static float __defaultFlatness   = _CG_FLATNESS;
static float __defaultMiterLimit = _CG_MITER_LIMIT;
static NSLineJoinStyle __defaultLineJoinStyle = _CG_LINE_JOIN_STYLE;
static NSLineCapStyle  __defaultLineCapStyle  = _CG_LINE_CAP_STYLE;
static NSWindingRule   __defaultWindingRule   = _CG_WINDING_RULE;



@implementation NSBezierPath

+ (NSBezierPath *) bezierPath
{
	return [[self new] autorelease];
}

+ (NSBezierPath *) bezierPathWithRect:(NSRect)aRect
{
	NSBezierPath *bp = [[self new] autorelease];
	
	CGPathAddRect(bp->_path, NULL, aRect);
	
	return bp;
}

+ (NSBezierPath *) bezierPathWithOvalInRect:(NSRect)rect
{
	NSBezierPath *bp = [[self new] autorelease];
	
	CGPathAddEllipseInRect(bp->_path, NULL, rect);
	
	return bp;
}

+ (void) fillRect:(NSRect)r						// Immediate mode drawing
{
	CGContextFillRect(CONTEXT, r);
}

+ (void) strokeRect:(NSRect)r
{
	CGContextStrokeRect (CONTEXT, r);
}

+ (void) clipRect:(NSRect)aRect
{
	PSrectclip(NSMinX(aRect), NSMinY(aRect), NSWidth(aRect), NSHeight(aRect));
}

+ (void) strokeLineFromPoint:(NSPoint)point1  toPoint:(NSPoint)point2
{
	NSBezierPath *path = [[self new] autorelease];
	
	[path moveToPoint: point1];
	[path lineToPoint: point2];
	[path stroke];
}

+ (void) drawPackedGlyphs:(const char *)packedGlyphs  atPoint:(NSPoint)aPoint
{
	NSBezierPath *path = [[self new] autorelease];
	
	[path moveToPoint: aPoint];
	[path appendBezierPathWithPackedGlyphs: packedGlyphs];
	[path stroke];  
}

+ (void) setDefaultFlatness:(float)flatness	{ __defaultFlatness = flatness; }
+ (void) setDefaultLineWidth:(float)w		{ __defaultLineWidth = w; }
+ (void) setDefaultMiterLimit:(float)limit	{ __defaultMiterLimit = limit; }
+ (float) defaultMiterLimit					{ return __defaultMiterLimit; }
+ (float) defaultLineWidth					{ return __defaultLineWidth; }
+ (float) defaultFlatness					{ return __defaultFlatness; }
+ (NSWindingRule) defaultWindingRule		{ return __defaultWindingRule; }
+ (NSLineCapStyle) defaultLineCapStyle		{ return __defaultLineCapStyle; }
+ (NSLineJoinStyle) defaultLineJoinStyle	{ return __defaultLineJoinStyle; }

+ (void) setDefaultWindingRule:(NSWindingRule)windingRule
{
	__defaultWindingRule = windingRule;
}

+ (void) setDefaultLineCapStyle:(NSLineCapStyle)style
{
	__defaultLineCapStyle = style;
}

+ (void) setDefaultLineJoinStyle:(NSLineJoinStyle)style
{
	__defaultLineJoinStyle = style;
}

- (id) init
{
	if ((self = [super init]))
		{
		_lineWidth = __defaultLineWidth;
		_flatness = __defaultFlatness;
		_bz.lineCapStyle = __defaultLineCapStyle;
		_bz.lineJoinStyle = __defaultLineJoinStyle;
		_bz.windingRule = __defaultWindingRule;
		_miterLimit = __defaultMiterLimit;
		_bz.flat = YES;
		_path = CGPathCreateMutable();
		}
	
	return self;
}

- (void) dealloc
{
	[_cacheImage release], 	_cacheImage = nil;
	
	if (_dashPattern != NULL)
		free(_dashPattern),	_dashPattern = NULL;

	CGPathRelease(_path),	_path = NULL;

	[super dealloc];
}

- (void) moveToPoint:(NSPoint)p
{
	CGPathMoveToPoint(_path, NULL, p.x, p.y);
	_bz.unknownBounds = YES;
}

- (void) lineToPoint:(NSPoint)p
{
	CGPathAddLineToPoint(_path, NULL, p.x, p.y);
	_bz.unknownBounds = YES;
}

- (void) curveToPoint:(NSPoint)p
		 controlPoint1:(NSPoint)cp1
		 controlPoint2:(NSPoint)cp2
{
	CGPathAddCurveToPoint(_path, NULL, cp1.x, cp1.y, cp2.x, cp2.y, p.x, p.y);
	_bz.flat = NO;
	_bz.unknownBounds = YES;
}

- (void) closePath
{
	CGPathCloseSubpath(_path);
	_bz.unknownBounds = YES;
}

- (void) removeAllPoints
{
	((CGPath *)_path)->_count = 0;
	_bz.unknownBounds = YES;
}

- (void) relativeMoveToPoint:(NSPoint)aPoint
{
	NSPoint p = CGPathGetCurrentPoint(_path);

	CGPathMoveToPoint(_path, NULL, p.x + aPoint.x, p.y + aPoint.y);
}

- (void) relativeLineToPoint:(NSPoint)aPoint
{
	NSPoint p = CGPathGetCurrentPoint(_path);

	CGPathAddLineToPoint(_path, NULL, p.x + aPoint.x, p.y + aPoint.y);
}

- (void) relativeCurveToPoint:(NSPoint)aPoint
				controlPoint1:(NSPoint)controlPoint1
				controlPoint2:(NSPoint)controlPoint2
{
	NSPoint p = CGPathGetCurrentPoint(_path);
	NSPoint cp1 = {p.x + controlPoint1.x, p.y + controlPoint1.y};
	NSPoint cp2 = {p.x + controlPoint2.x, p.y + controlPoint2.y};

	p.x = p.x + aPoint.x;
	p.y = p.y + aPoint.y;

	CGPathAddCurveToPoint(_path, NULL, cp1.x, cp1.y, cp2.x, cp2.y, p.x, p.y);
	_bz.flat = NO;
	_bz.unknownBounds = YES;
}

- (float) lineWidth								{ return _lineWidth; }
- (float) flatness								{ return _flatness; }
- (float) miterLimit							{ return _miterLimit; }
- (NSLineJoinStyle) lineJoinStyle				{ return _bz.lineJoinStyle; }
- (NSLineCapStyle) lineCapStyle					{ return _bz.lineCapStyle; }
- (NSWindingRule) windingRule					{ return _bz.windingRule; }
- (void) setLineWidth:(float)lineWidth			{ _lineWidth = lineWidth; }
- (void) setFlatness:(float)flatness			{ _flatness = flatness; }
- (void) setLineCapStyle:(NSLineCapStyle)ls		{ _bz.lineCapStyle = ls; }
- (void) setLineJoinStyle:(NSLineJoinStyle)lj	{ _bz.lineJoinStyle = lj; }
- (void) setWindingRule:(NSWindingRule)wr		{ _bz.windingRule = wr; }
- (void) setMiterLimit:(float)limit				{ _miterLimit = limit; }

- (void) getLineDash:(float *)pattern count:(int *)count phase:(float *)phase
{
	if (count != NULL)
		*count = _dashCount;
	if (pattern == NULL)
		return;
	if (phase != NULL)
		*phase = _dashPhase;
	memcpy(pattern, _dashPattern, _dashCount * sizeof(float));
}

- (void) setLineDash:(const float *)pattern count:(int)count phase:(float)phase
{
	if ((pattern == NULL) || (count == 0))
		{
		if (_dashPattern != NULL)
			free(_dashPattern);
		_dashPattern = NULL;
		_dashCount = 0;
		_dashPhase = 0.0;

		return;
		}
	
	_dashCount = count;
	_dashPhase = phase;
	_dashPattern = realloc(_dashPattern, count * sizeof(CGFloat));
	memcpy(_dashPattern, pattern, _dashCount * sizeof(CGFloat));
}

- (void) stroke
{
	PSsetlinewidth(_lineWidth);
	PSsetlinejoin(_bz.lineJoinStyle);
	PSsetlinecap(_bz.lineCapStyle);
	PSsetmiterlimit(_miterLimit);
	PSsetflat(_flatness);
	PSsetdash(_dashPattern, _dashCount, _dashPhase);
	PSnewpath();
	CGContextAddPath(CONTEXT, _path);
	CGContextStrokePath(CONTEXT);
}

- (void) fill
{
	if(_bz.cachesBezierPath) 
		{
		NSRect bounds = [self bounds];
		NSPoint origin = bounds.origin;
										// FIX ME: I don't see how this
		if(_cacheImage == nil)			// should work with color changes
			{
			_cacheImage = [[NSImage alloc] initWithSize: bounds.size];		
			[_cacheImage lockFocus];
			PStranslate(-origin.x, -origin.y);
			PSnewpath();
			CGContextAddPath(CONTEXT, _path);
			if (_bz.windingRule == NSNonZeroWindingRule)
				PSfill();
			else
				PSeofill();
			[_cacheImage unlockFocus];
			}
		[_cacheImage compositeToPoint: origin operation: NSCompositeCopy];
		} 
	else 
		{
		PSnewpath();
		CGContextAddPath(CONTEXT, _path);
		if (_bz.windingRule == NSNonZeroWindingRule)
			PSfill();
		else
			PSeofill();
		}
}

- (void) addClip
{
	PSnewpath();
	CGContextAddPath(CONTEXT, _path);
	if (_bz.windingRule == NSNonZeroWindingRule)
		PSclip();
	else
		PSeoclip();
}

- (void) setClip
{
	PSinitclip();
	PSnewpath();
	CGContextAddPath(CONTEXT, _path);
	if (_bz.windingRule == NSNonZeroWindingRule)
		PSclip();
	else
		PSeoclip();
}

- (NSBezierPath *) bezierPathByFlatteningPath
{
	NSBezierPath *bp = [isa bezierPath];
	CGPathRef p = CGPathCreateCopyByStrokingPath( _path, NULL,
												  _lineWidth,
												  _bz.lineCapStyle,
												  _bz.lineJoinStyle,
												  _miterLimit);
	bp->_path = (CGMutablePathRef)p;

	return bp;
}

- (NSBezierPath *) bezierPathByReversingPath
{
	NSBezierPath *path = [isa bezierPath];
	NSBezierPathElement type, last_type = NSMoveToBezierPathElement;
	NSPoint pts[3];
	NSPoint p, cp1, cp2;
	int i, j;
	BOOL closed = NO;
	
	for(i = ((CGPath *)_path)->_count - 1; i >= 0; i--)
		{
		switch((type = [self elementAtIndex: i associatedPoints: pts])) 
			{
			case NSMoveToBezierPathElement:
				p = pts[0];
				break;
			case NSLineToBezierPathElement:
				p = pts[0];
				break;
			case NSCurveToBezierPathElement:
				cp1 = pts[0];
				cp2 = pts[1];
				p = pts[2];      
				break;
			case NSClosePathBezierPathElement:		// FIX ME looks wrong
				for (j = i - 1; j >= 0; j--) // find the first point of segment
					{
					type = [self elementAtIndex: i associatedPoints: pts];
					if (type == NSMoveToBezierPathElement)
						{
						p = pts[0];
						break;
					}	}   
				// FIXME: What to do if we don't find a move element?
			default:
				break;
			}
		
		switch(last_type) 
			{
			case NSMoveToBezierPathElement:
				if (closed)
					{
					[path closePath];
					closed = NO;
					}
				[path moveToPoint: p];
				break;
			case NSLineToBezierPathElement:
				[path lineToPoint: p];
				break;
			case NSCurveToBezierPathElement:
				[path curveToPoint: p controlPoint1: cp2 controlPoint2: cp1];	      
				break;
			case NSClosePathBezierPathElement:
				closed = YES;
			default:
				break;
			}
		last_type = type;
		}
	
	if (closed)
		[path closePath];

	return self;
}

- (void) transformUsingAffineTransform:(NSAffineTransform *)transform
{
	CGAffineTransform tm = [transform transformStruct];
	CGMutablePathRef p = CGPathCreateMutableCopyByTransformingPath(_path, &tm);
	
	CGPathRelease(_path);
	_path = p;
	_bz.unknownBounds = YES;
	[_cacheImage release], 	_cacheImage = nil;
}

- (NSPoint) currentPoint
{
	if (!((CGPath *)_path)->_count)
		[NSException raise: NSGenericException
					 format: @"No current Point in NSBezierPath"];
	
	return ((CGPath *)_path)->_p0;
}

- (NSRect) controlPointBounds
{
	if (_bz.unknownBounds)
		[self bounds];

	return _controlPointBounds;
}

- (NSRect) bounds
{
	if (_bz.unknownBounds)
		{
		NSPoint p, last_p;
		NSPoint pts[3];
		// This will compute three intermediate points per curve
		double x, y, t, k = 0.25;
		float maxx, minx, maxy, miny;
		float cpmaxx, cpminx, cpmaxy, cpminy;	
		int i, count;
		BOOL first = YES;

		if(!(count = ((CGPath *)_path)->_count))
			return _bounds = _controlPointBounds = NSZeroRect;

		maxx = maxy = cpmaxx = cpmaxy = -1E9;		// Some big starting values
		minx = miny = cpminx = cpminy = 1E9;

		for(i = 0; i < count; i++) 
			{
			switch([self elementAtIndex: i associatedPoints: pts]) 
				{
				case NSMoveToBezierPathElement:
					last_p = pts[0];							// NO BREAK
				case NSLineToBezierPathElement:
					if (first)
						{
						maxx = minx = cpmaxx = cpminx = pts[0].x;
						maxy = miny = cpmaxy = cpminy = pts[0].y;
						last_p = pts[0];
						first = NO;
						}
					else
						{
						if(pts[0].x > maxx) maxx = pts[0].x;
						if(pts[0].x < minx) minx = pts[0].x;
						if(pts[0].y > maxy) maxy = pts[0].y;
						if(pts[0].y < miny) miny = pts[0].y;
						
						if(pts[0].x > cpmaxx) cpmaxx = pts[0].x;
						if(pts[0].x < cpminx) cpminx = pts[0].x;
						if(pts[0].y > cpmaxy) cpmaxy = pts[0].y;
						if(pts[0].y < cpminy) cpminy = pts[0].y;
						}
					
					p = pts[0];
					break;
					
				case NSCurveToBezierPathElement:
					if (first)
						{
						maxx = minx = cpmaxx = cpminx = pts[0].x;
						maxy = miny = cpmaxy = cpminy = pts[0].y;
						p = last_p = pts[0];
						first = NO;
						}
					
					if(pts[2].x > maxx) maxx = pts[2].x;
					if(pts[2].x < minx) minx = pts[2].x;
					if(pts[2].y > maxy) maxy = pts[2].y;
					if(pts[2].y < miny) miny = pts[2].y;
					
					if(pts[0].x > cpmaxx) cpmaxx = pts[0].x;
					if(pts[0].x < cpminx) cpminx = pts[0].x;
					if(pts[0].y > cpmaxy) cpmaxy = pts[0].y;
					if(pts[0].y < cpminy) cpminy = pts[0].y;
					if(pts[1].x > cpmaxx) cpmaxx = pts[1].x;
					if(pts[1].x < cpminx) cpminx = pts[1].x;
					if(pts[1].y > cpmaxy) cpmaxy = pts[1].y;
					if(pts[1].y < cpminy) cpminy = pts[1].y;
					if(pts[2].x > cpmaxx) cpmaxx = pts[2].x;
					if(pts[2].x < cpminx) cpminx = pts[2].x;
					if(pts[2].y > cpmaxy) cpmaxy = pts[2].y;
					if(pts[2].y < cpminy) cpminy = pts[2].y;
																				
					for(t = k; t <= 1+k; t += k) 
						{
						x = (p.x+t*(-p.x*3+t*(3*p.x-p.x*t)))+
							t*(3*pts[0].x+t*(-6*pts[0].x+pts[0].x*3*t))+
							t*t*(pts[1].x*3-pts[1].x*3*t)+pts[2].x*t*t*t;
						y = (p.y+t*(-p.y*3+t*(3*p.y-p.y*t)))+
							t*(3*pts[0].y+t*(-6*pts[0].y+pts[0].y*3*t))+
							t*t*(pts[1].y*3-pts[1].y*3*t)+pts[2].y*t*t*t;
						
						if(x > cpmaxx) cpmaxx = x;
						if(x < cpminx) cpminx = x;
						if(y > cpmaxy) cpmaxy = y;
						if(y < cpminy) cpminy = y;
						}
						
						p = pts[2];
					break;
					
				case NSClosePathBezierPathElement:
					p = last_p;							// Changes current point
				default:
					break;
			}	}
	
		_bounds = NSMakeRect(minx, miny, maxx - minx, maxy - miny);
		_controlPointBounds = NSMakeRect(cpminx, cpminy, 
										 cpmaxx - cpminx, cpmaxy - cpminy);
		_bz.unknownBounds = NO;
		}

	return _bounds;
}

- (BOOL) isEmpty						{ return CGPathIsEmpty(_path); }
- (int) elementCount					{ return ((CGPath *)_path)->_count; }

- (NSBezierPathElement) elementAtIndex:(int)index
						associatedPoints:(NSPoint *)points
{
	CGPathElement *e;

	if (index < 0 || index >= ((CGPath *)_path)->_count)
		[NSException raise: NSRangeException format: @"Bad Index"];

	e = &((CGPath *)_path)->_pe[index];
	if (points != NULL)
		{
		NSBezierPathElement t = e->type;
		
		if (t == NSMoveToBezierPathElement || t == NSLineToBezierPathElement)
			points[0] = e->points[0];
		else if(t == NSCurveToBezierPathElement) 
			{
			points[0] = e->points[0];
			points[1] = e->points[1];
			points[2] = e->points[2];
		}	}

	return e->type;
}

- (NSBezierPathElement) elementAtIndex:(int)index
{
	return [self elementAtIndex: index associatedPoints: NULL];	
}

- (void) appendBezierPath:(NSBezierPath *)aPath
{
	CGPathAddPath( _path, NULL, aPath->_path);
	_bz.flat = _bz.flat && aPath->_bz.flat;
	_bz.unknownBounds = YES;
}

- (void) appendBezierPathWithRect:(NSRect)rect
{
	[self appendBezierPath: [isa bezierPathWithRect: rect]];
}

- (void) appendBezierPathWithPoints:(NSPoint *)points count:(int)count
{
	CGPathAddLines( _path, NULL, points, count);
}

- (void) appendBezierPathWithOvalInRect:(NSRect)aRect
{
	[self appendBezierPath: [isa bezierPathWithOvalInRect: aRect]];
}

- (void) appendBezierPathWithArcWithCenter:(NSPoint)center  
									radius:(float)radius
								startAngle:(float)startAngle
								  endAngle:(float)endAngle
								 clockwise:(BOOL)clockwise
{												// startAngle and endAngle are
	float startAngle_rad, endAngle_rad, diff;	// in degrees, counterclockwise,
	NSPoint p0, p1, p2, p3;						// from the x axis

	/* We use the Postscript prescription for managing the angles and
		drawing the arc.  See the documentation for `arc' and `arcn' in
		the Postscript Reference. */
	if (clockwise)
		{	// This modification of the angles is the postscript prescription.
		while (startAngle < endAngle)
			endAngle -= 360;
		
		/* This is used when we draw a clockwise quarter of
		circumference.  By adding diff at the starting angle of the
		quarter, we get the ending angle.  diff is negative because
		we draw clockwise. */
		diff = -M_PI / 2;
		}
	else
		{	// This modification of the angles is the postscript prescription.
		while (endAngle < startAngle)
			endAngle += 360;
		
		/* This is used when we draw a counterclockwise quarter of
		circumference.  By adding diff at the starting angle of the
		quarter, we get the ending angle.  diff is positive because
		we draw counterclockwise. */
		diff = M_PI / 2;
		}
	
	/* Convert the angles to radians */
	startAngle_rad = M_PI * startAngle / 180;
	endAngle_rad = M_PI * endAngle / 180;
	
	/* Start point */
	p0 = NSMakePoint (center.x + radius * cos (startAngle_rad), 
					  center.y + radius * sin (startAngle_rad));
	if ([self elementCount] == 0)
		[self moveToPoint: p0];
	else
		{
		NSPoint ps = [self currentPoint];
		
		if (p0.x != ps.x  ||  p0.y != ps.y)
			[self lineToPoint: p0];
		}
	
	while ((clockwise) ? (startAngle_rad > endAngle_rad) 
					   : (startAngle_rad < endAngle_rad))
		{
		/* Add a quarter circle */
		if ((clockwise) ? (startAngle_rad + diff >= endAngle_rad) 
						: (startAngle_rad + diff <= endAngle_rad))
			{
			float sin_start = sin (startAngle_rad);
			float cos_start = cos (startAngle_rad);
			float sign = (clockwise) ? -1.0 : 1.0;
			
			p1 = NSMakePoint (center.x + radius * (cos_start - KAPPA * sin_start * sign),
							  center.y + radius * (sin_start + KAPPA * cos_start * sign));
			p2 = NSMakePoint (center.x + radius * (-sin_start * sign + KAPPA * cos_start),
							  center.y + radius * (cos_start * sign + KAPPA * sin_start));
			p3 = NSMakePoint (center.x + radius * (-sin_start * sign),
							  center.y + radius * cos_start * sign);
			
			[self curveToPoint: p3  controlPoint1: p1  controlPoint2: p2];
			startAngle_rad += diff;
			}
		else
			{/*	Add the missing bit.
				We require that the arc be less than a semicircle.
				The arc may go either clockwise or counterclockwise.
				The approximation is a very simple one: a single curve
				whose middle two control points are a fraction F of the way
				to the intersection of the tangents, where
				   F = (4/3) / (1 + sqrt (1 + (d / r)^2))
				where r is the radius and d is the distance from either tangent
				point to the intersection of the tangents. This produces
				a curve whose center point, as well as its ends, lies on
				the desired arc.
			*/
			NSPoint ps = [self currentPoint];
				/* tangent is the tangent of half the angle */
			float tangent = tan ((endAngle_rad - startAngle_rad) / 2);
				/* trad is the distance from either tangent point to the
					intersection of the tangents */
			float trad = radius * tangent;
				/* pt is the intersection of the tangents */
			NSPoint pt = NSMakePoint (ps.x - trad * sin (startAngle_rad),
									  ps.y + trad * cos (startAngle_rad));
				/* This is F - in this expression we need to compute 
				(trad/radius)^2, which is simply tangent^2 */
			float f = (4.0 / 3.0) / (1.0 + sqrt (1.0 + (tangent * tangent)));
			
			p1 = NSMakePoint (ps.x + (pt.x - ps.x) * f, ps.y + (pt.y - ps.y) * f);
			p3 = NSMakePoint(center.x + radius * cos (endAngle_rad),
							 center.y + radius * sin (endAngle_rad));
			p2 = NSMakePoint (p3.x + (pt.x - p3.x) * f, p3.y + (pt.y - p3.y) * f);
			[self curveToPoint: p3  controlPoint1: p1  controlPoint2: p2];
			break;
			}
		}
}

- (void) appendBezierPathWithArcWithCenter:(NSPoint)center  
									radius:(float)radius
								startAngle:(float)startAngle
								  endAngle:(float)endAngle
{
	[self appendBezierPathWithArcWithCenter: center
		  radius: radius
		  startAngle: startAngle
		  endAngle: endAngle
		  clockwise: NO];
}

- (void) appendBezierPathWithArcFromPoint:(NSPoint)point1
								  toPoint:(NSPoint)point2
								   radius:(float)radius
{
	float x1 = point1.x;
	float y1 = point1.y;
	float dx1, dy1, dx2, dy2;
	float l, a1, a2;
	NSPoint p = [self currentPoint];

	dx1 = p.x - x1;
	dy1 = p.y - y1;
	
	if ((l = dx1*dx1 + dy1*dy1) <= 0)
		{
		[self lineToPoint: point1];
		return;
		}
	l = 1/sqrt(l);
	dx1 *= l;
	dy1 *= l;
	
	dx2 = point2.x - x1;
	dy2 = point2.y - y1;
	
	if ((l = dx2*dx2 + dy2*dy2) <= 0)
		{
		[self lineToPoint: point1];
		return;
		}
	
	l = 1/sqrt(l);
	dx2 *= l; 
	dy2 *= l;
	
	if ((l = dx1*dx2 + dy1*dy2) < -0.999)
		{
		[self lineToPoint: point1];
		return;
		}
	
	l = radius/sin(acos(l));
	p.x = x1 + (dx1 + dx2)*l;
	p.y = y1 + (dy1 + dy2)*l;
	
	if (dx1 < -1)
		a1 = 180;
	else if (dx1 > 1)
		a1 = 0;
	else
		a1 = acos(dx1)/M_PI*180;
	if (dy1 < 0)
		a1 = -a1;
	
	if (dx2 < -1)
		a2 = 180;
	else if (dx2 > 1)
		a2 = 0;
	else
		a2 = acos(dx2)/M_PI*180;
	if (dy2 < 0)
		a2 = -a2;
	
	if ((l = dx1*dy2 - dx2*dy1) < 0)
		{
		a2 = a2 - 90;
		a1 = a1 + 90;
		[self appendBezierPathWithArcWithCenter: p  
										 radius: radius
									 startAngle: a1  
									   endAngle: a2  
									  clockwise: NO];
		}
	else
		{
		a2 = a2 + 90;
		a1 = a1 - 90;
		[self appendBezierPathWithArcWithCenter: p  
										 radius: radius
									 startAngle: a1  
									   endAngle: a2  
									  clockwise: YES];
		}
}

- (void) appendBezierPathWithGlyph:(NSGlyph)glyph
							inFont:(NSFont *)font					  { NIMP; }

- (void) appendBezierPathWithGlyphs:(NSGlyph *)glyphs 
							 count:(int)count
							inFont:(NSFont *)font					  { NIMP; }

- (void) appendBezierPathWithPackedGlyphs:(const char *)packedGlyphs  { NIMP; }

- (BOOL) cachesBezierPath					{ return _bz.cachesBezierPath; }

- (void) setCachesBezierPath:(BOOL)flag
{
	if(!(_bz.cachesBezierPath = flag))
		{
		_bz.unknownBounds = YES;
		[_cacheImage release], 	_cacheImage = nil;
		}
}

- (void) encodeWithCoder:(NSCoder *)aCoder			// NSCoding protocol
{
	NSBezierPathElement type;
	NSPoint pts[3];
	int i, count;
	float f = [self lineWidth];
	
	[aCoder encodeValueOfObjCType: @encode(float) at: &f];
	[aCoder encodeValueOfObjCType: @encode(unsigned int) at: &_bz];
	
	count = [self elementCount];
	[aCoder encodeValueOfObjCType: @encode(int) at: &count];
	
	for(i = 0; i < count; i++) 
		{
		type = [self elementAtIndex: i associatedPoints: pts];
		[aCoder encodeValueOfObjCType: @encode(NSBezierPathElement) at: &type];
		switch(type) 
			{
			case NSMoveToBezierPathElement:
			case NSLineToBezierPathElement:
				[aCoder encodeValueOfObjCType: @encode(NSPoint) at: &pts[0]];
				break;
			case NSCurveToBezierPathElement:
				[aCoder encodeValueOfObjCType: @encode(NSPoint) at: &pts[0]];
				[aCoder encodeValueOfObjCType: @encode(NSPoint) at: &pts[1]];
				[aCoder encodeValueOfObjCType: @encode(NSPoint) at: &pts[2]];
				break;
			case NSClosePathBezierPathElement:
			default:
				break;
		}	}
}

- (id) initWithCoder:(NSCoder *)aCoder
{
	NSBezierPathElement type;
	NSPoint pts[3];
	int i, count;
	float f;
	
	[self init];
	
	[aCoder decodeValueOfObjCType: @encode(float) at: &f];
	[self setLineWidth: f];
	[aCoder decodeValueOfObjCType: @encode(unsigned int) at: &_bz];
	_bz.unknownBounds = YES;
	
	[aCoder decodeValueOfObjCType: @encode(int) at: &count];
	
	for(i = 0; i < count; i++) 
		{
		[aCoder decodeValueOfObjCType: @encode(NSBezierPathElement) at: &type];
		switch(type) 
			{
			case NSMoveToBezierPathElement:
				[aCoder decodeValueOfObjCType: @encode(NSPoint) at: &pts[0]];
				[self moveToPoint: pts[0]];
			case NSLineToBezierPathElement:
				[aCoder decodeValueOfObjCType: @encode(NSPoint) at: &pts[0]];
				[self lineToPoint: pts[0]];
				break;
			case NSCurveToBezierPathElement:
				[aCoder decodeValueOfObjCType: @encode(NSPoint) at: &pts[0]];
				[aCoder decodeValueOfObjCType: @encode(NSPoint) at: &pts[1]];
				[aCoder decodeValueOfObjCType: @encode(NSPoint) at: &pts[2]];
				[self curveToPoint: pts[0] controlPoint1: pts[1] controlPoint2: pts[2]];
				break;
			case NSClosePathBezierPathElement:
				[self closePath];
			default:
				break;
		}	}
	
	return self;
}

- (id) copy											// NSCopying Protocol
{
	NSBezierPath *bp = (NSBezierPath*) NSCopyObject(self);
	
	if(_bz.cachesBezierPath && _cacheImage)
		bp->_cacheImage = [_cacheImage copy];
	
	if (_dashPattern != NULL)
		{
		CGFloat *pattern = malloc(_dashCount * sizeof(CGFloat));
		
		memcpy(pattern, _dashPattern, _dashCount * sizeof(CGFloat));
		bp->_dashPattern = pattern;
		}
	
	bp->_path = CGPathCreateMutableCopy(_path);

	return bp;
}

- (void) setAssociatedPoints:(NSPoint *)points atIndex:(int)index
{
	CGPathElement *e;

	if (index < 0 || index >= ((CGPath *)_path)->_count)
		[NSException raise: NSRangeException format: @"Bad Index"];

	e = &((CGPath *)_path)->_pe[index];
	switch(e->type)
		{
		case NSMoveToBezierPathElement:
		case NSLineToBezierPathElement:
			e->points[0] = points[0];
			break;
		case NSCurveToBezierPathElement:
			e->points[0] = points[0];
			e->points[1] = points[1];
			e->points[2] = points[2];
			break;
		case NSClosePathBezierPathElement:
		default:
			break;
		}

	_bz.unknownBounds = YES;
	[_cacheImage release], 	_cacheImage = nil;
}

- (BOOL) containsPoint:(NSPoint)point
{
	NSPoint draftPolygon[PMAX];
	int i, pcount = 0;
	double cx, cy;						// Coordinates of the current point
	double lx, ly;						// Coordinates of the last point
	int Rcross = 0;
	int Lcross = 0;	
	NSPoint p, pts[3];
	double x, y, t, k = 0.25;
	
	if (!((CGPath *)_path)->_count || !NSPointInRect(point, [self bounds]))
		return NO;
							// FIX ME: This does not handle multiple segments!
	for(i = 0; i < ((CGPath *)_path)->_count; i++)
		{
		NSBezierPathElement e = [self elementAtIndex: i associatedPoints: pts];
		
		if(e == NSMoveToBezierPathElement || e == NSLineToBezierPathElement) 
			{
			draftPolygon[pcount].x = pts[0].x;
			draftPolygon[pcount].y = pts[0].y;
			
			pcount++;
			} 
		else if(e == NSCurveToBezierPathElement) 
			{
			if(pcount) 
				{
				p.x = draftPolygon[pcount -1].x;
				p.y = draftPolygon[pcount -1].y;
				} 
			else 
				{
				p.x = pts[0].x;
				p.y = pts[0].y;
				}
			
			for(t = k; t <= 1+k; t += k) 
				{
				x = (p.x+t*(-p.x*3+t*(3*p.x-p.x*t)))+
				t*(3*pts[0].x+t*(-6*pts[0].x+pts[0].x*3*t))+
				t*t*(pts[1].x*3-pts[1].x*3*t)+pts[2].x*t*t*t;
				y = (p.y+t*(-p.y*3+t*(3*p.y-p.y*t)))+
					t*(3*pts[0].y+t*(-6*pts[0].y+pts[0].y*3*t))+
					t*t*(pts[1].y*3-pts[1].y*3*t)+pts[2].y*t*t*t;
				
				draftPolygon[pcount].x = x;
				draftPolygon[pcount].y = y;
				pcount++;
				}
			}

		if (pcount == PMAX)						// Simple overflow check
			return NO;
		}  
	
	lx = draftPolygon[pcount - 1].x - point.x;
	ly = draftPolygon[pcount - 1].y - point.y;
	for(i = 0; i < pcount; i++) 
		{
		cx = draftPolygon[i].x - point.x;
		cy = draftPolygon[i].y - point.y;
		if(cx == 0 && cy == 0)							// on a vertex
			return NO;
		
		if((cy > 0)  && !(ly > 0)) 
			{
			if (((cx * ly - lx * cy) / (ly - cy)) > 0)
				Rcross++;
			}
		if((cy < 0 ) && !(ly < 0)) 
			{ 
			if (((cx * ly - lx * cy) / (ly - cy)) < 0)
				Lcross++;		
			}
		lx = cx;
		ly = cy;
		}
	
	if((Rcross % 2) != (Lcross % 2))
		return NO;										// On the border

	return ((Rcross % 2) == 1) ? YES : NO;
}

@end  /* NSBezierPath */
