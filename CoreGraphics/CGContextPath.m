/*
   CGContextPath.m

   Graphics context path management

   Copyright (C) 2006-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGPath.h>

#include <AppKit/NSWindow.h>


#define CTX				((CGContext *)cx)
#define PATH			((CGContext *)cx)->_path
#define PATH_ORIGIN		((CGContext *)cx)->_path->_p0
#define PATH_E			((CGContext *)cx)->_path->_pe
#define XCANVAS			((CGContext *)cx)->_gs->xCanvas
#define ISFLIPPED		((CGContext *)cx)->_gs->isFlipped
#define CTM				((CGContext *)cx)->_gs->hasCTM
#define GSTATE			((CGContext *)cx)->_gs



CGPoint
CGContextGetPathCurrentPoint (CGContextRef cx)
{
	return CGPathGetCurrentPoint( PATH );
}

CGRect
CGContextGetPathBoundingBox (CGContextRef cx)
{
	return CGPathGetBoundingBox( PATH );
}

bool
CGContextIsPathEmpty (CGContextRef cx)
{
	return CGPathIsEmpty( PATH );
}

bool
CGContextPathContainsPoint ( CGContextRef cx, CGPoint p, CGPathDrawingMode m)
{
	bool eoFill = (m == kCGPathEOFill || m == kCGPathEOFillStroke);
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	return CGPathContainsPoint( PATH, &tm, p, eoFill);
}

void
CGContextMoveToPoint(CGContextRef cx, float x, float y)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	DBLog(@" CGContextMoveToPoint: x,y  %f %f\n", x, y);
	if (!PATH)
		{
		NSLog(@" ********** CGContextMoveToPoint: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathMoveToPoint( PATH, &tm, x, y );
}

void
CGContextAddLineToPoint(CGContextRef cx, float x, float y)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	DBLog(@" CGContextAddLineToPoint: x,y  %f %f\n", x, y);
	if (!PATH)
		{
		NSLog(@" ********** CGContextAddLineToPoint: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathAddLineToPoint( PATH, &tm, x, y );
}

void
CGContextBeginPath( CGContextRef cx)				// PS newpath
{
	if (!PATH)
		PATH = CGPathCreateMutable();

	PATH->_count = 0;
	PATH->_bbox = PATH->_pbox = CGRectNull;
	PATH->_p0 = NSZeroPoint;
}

void
CGContextClosePath( CGContextRef cx)				// PS closepath
{
	CGPathCloseSubpath(PATH);
}

void
CGContextAddPath( CGContextRef cx, CGPathRef path)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (!path)
		return;

	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	if (!PATH)
		CGContextBeginPath(cx);

	CGPathAddPath(PATH, &tm, path);
}

void
CGContextReplacePathWithStrokedPath( CGContextRef cx)
{
	CGPathRef p = CGPathCreateCopyByStrokingPath( PATH, NULL,
												  GSTATE->_line.width,
												  GSTATE->_line.capStyle,
												  GSTATE->_line.joinStyle,
												  GSTATE->_line.miterLimit);
	CGPathRelease(PATH);
	PATH = (CGMutablePathRef)p;
}

void
CGContextAddArc( CGContextRef cx,
				 float x,
				 float y,
				 float radius,
				 float startAngle,
				 float endAngle,
				 int clockwise)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	if (!PATH)
		{
		NSLog(@" ********** CGContextAddArc: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathAddArc( PATH, &tm, x, y, radius, startAngle, endAngle, clockwise);
}

void
CGContextAddArcToPoint( CGContextRef cx,
						CGFloat x1, CGFloat y1,
						CGFloat x2, CGFloat y2,
						CGFloat radius)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	if (!PATH)
		{
		NSLog(@" ********** CGContextAddArcToPoint: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathAddArcToPoint( PATH, &tm, x1, y1, x2, y2, radius);
}

void
CGContextAddQuadCurveToPoint( CGContextRef cx,
							  CGFloat cp_x, CGFloat cp_y,
							  CGFloat x, CGFloat y )
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	if (!PATH)
		{
		NSLog(@" ****** CGContextAddQuadCurveToPoint: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathAddQuadCurveToPoint( PATH, &tm, cp_x, cp_y, x, y);
}
								// append cubic Bezier curve to current path
void
CGContextAddCurveToPoint( CGContextRef cx,
						  CGFloat cp1_x, CGFloat cp1_y,
						  CGFloat cp2_x, CGFloat cp2_y,
						  CGFloat x, CGFloat y )
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	if (!PATH)
		{
		NSLog(@" ****** CGContextAddCurveToPoint: path not initialized\n");
		CGContextBeginPath(cx);
		}

	CGPathAddCurveToPoint( PATH, &tm, cp1_x, cp1_y, cp2_x, cp2_y, x, y);
}

#ifndef CAIRO_GRAPHICS

void
_CGContextScanPath (CGContextRef cx)
{
	if (PATH && PATH->_count > 1)
		{
		NSUInteger j, i;							// determine bounding box
///		float d = context->_gs->lineWidth;
		float d = 1;
		NSRect xFlushRect = (NSRect){{PATH_E[0].p1.x, PATH_E[0].p1.y}, {d,d}};
		NSRect rect = (NSRect){{0,0}, {d,d}};
		NSPoint o = xFlushRect.origin;

		for (i = 0; i < PATH->_count; i++)
			{
			switch (PATH_E[i].type)
				{
				case kCGPathElementMoveToPoint:
					{
					rect.origin = PATH_E[i].p1;
					o = PATH_ORIGIN = rect.origin;
					break;
					}

				case kCGPathElementAddLineToPoint:
				case kCGPathElementCloseSubpath:
					{
					rect.origin = PATH_E[i].p1;
					o = PATH_ORIGIN = rect.origin;
					break;
					}

				case kCGPathElementAddQuadCurveToPoint:
					{
					NSPoint cp = PATH_E[i].p1;
					NSPoint e = PATH_E[i].p2;

					o = rect.origin = PATH_ORIGIN = e;
					break;
					}

				case kCGPathElementAddCurveToPoint:
					{
					NSPoint cp1 = PATH_E[i].p1;
					NSPoint cp2 = PATH_E[i].p2;
					NSPoint e = PATH_E[i].p3;

					o = rect.origin = PATH_ORIGIN = e;
					break;
					}
				}

			xFlushRect = NSUnionRect(xFlushRect, rect);
			}

		_CGContextRectNeedsFlush(cx, xFlushRect);

		if (CTX->_f.pathClip)
			_clip_rect( cx, xFlushRect);
		}
}

void
_CGContextStrokePath (CGContextRef cx)
{
///	CGAffineTransform m = (CTM ? GSTATE->_ctm : CGAffineTransformIdentity);
	CGAffineTransform m = CGAffineTransformIdentity;

	_CGRenderPath( cx, CTX->_path, &m, NO);
	CTX->_path->_count = 0;
}

void
_CGContextFillPath( CGContextRef cx)
{
///	CGAffineTransform m = (CTM ? GSTATE->_ctm : CGAffineTransformIdentity);
	CGAffineTransform m = CGAffineTransformIdentity;

	if (!CTX->_f.pathClip)				// FIX ME same in _CGContextScanPath()
		_clip_rect(cx, GSTATE->clip);

	_CGRenderPath(cx, CTX->_path, &m, YES);
	CTX->_path->_count = 0;
}

#endif /* !CAIRO_GRAPHICS */

void
CGContextDrawPath( CGContextRef cx, CGPathDrawingMode mode)
{
	if (PATH && PATH->_count > 1)
		{
		_CGContextScanPath(cx);

//		if (CTX->_gs->_shadowColor)
//			FIX ME stroke path shadow

		switch ((CTX->_f.draw = mode))
			{
			case kCGPathFill:			_CGContextFillPath(cx);		break;
			case kCGPathFillStroke: 	_CGContextFillPath(cx);
			case kCGPathStroke:			_CGContextStrokePath(cx);	break;

			case kCGPathEOFill:			_CGContextFillPath(cx);		break;
			case kCGPathEOFillStroke:	_CGContextFillPath(cx);
										_CGContextStrokePath(cx);	break;
			}

		CGContextBeginPath(cx);
		}
}

void
CGContextStrokePath (CGContextRef cx)
{
	CGContextDrawPath(cx, kCGPathStroke);
}

void
CGContextFillPath( CGContextRef cx)
{
	CGContextDrawPath(cx, kCGPathFill);
}

void
CGContextEOFillPath( CGContextRef cx)
{
	CGContextDrawPath(cx, kCGPathEOFill);
}

void CGContextFillEllipseInRect(CGContextRef cx, CGRect r)
{
	CGContextAddEllipseInRect( cx, r);
	CGContextFillPath(cx);
}

void CGContextStrokeEllipseInRect(CGContextRef cx, CGRect r)
{
	CGContextAddEllipseInRect( cx, r);
	CGContextStrokePath(cx);
}

void
CGContextAddEllipseInRect( CGContextRef cx, CGRect r)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	CGPathAddEllipseInRect( PATH, &tm, r );
}

void
CGContextAddRect( CGContextRef cx, CGRect r)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	CGPathAddRect( PATH, &tm, r );
}

void
CGContextAddRects( CGContextRef cx, const CGRect rects[], size_t count)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	CGPathAddRects( PATH, &tm, rects, count);
}

void
CGContextAddLines(CGContextRef cx, const CGPoint points[], size_t count)
{
	CGAffineTransform tm = {1, 0, 0, (ISFLIPPED ? 1 : -1), NSMinX(XCANVAS),
							NSHeight(XCANVAS) - NSMinY(XCANVAS)};
	if (CTM)
		tm = CGAffineTransformConcat(GSTATE->_ctm, tm);

	CGPathAddLines( PATH, &tm, points, count);
}
