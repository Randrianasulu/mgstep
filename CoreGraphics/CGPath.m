/*
   CGPath.m

   Graphics drawing path.

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/NSBezierPath.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGPath.h>
#include <CoreFoundation/CFRuntime.h>


#define CTX			((CGContext *)_CGContext())



static void _CGPathReleaseCache( CGPath *path )
{
	if (path->_vrtx != NULL)
		free(path->_vrtx), path->_vrtx = NULL;
}

static void __CGPathDeallocate(CFTypeRef cf)
{
	if (cf && ((CGPathRef)cf)->_pe)
		{
		free(((CGPathRef)cf)->_pe);
		((CGPath *)cf)->_pe = NULL;
		_CGPathReleaseCache(((CGPath *)cf));
		}
}

static const CFRuntimeClass __CGPathClass = {
	_CF_VERSION,
	"CGPath",
	__CGPathDeallocate
};


static void
_CGPathMakeImmutable( CGPathRef p )
{
	((CGPath *)p)->_immutable = YES;
///	((CGPath *)p)->_capacity = ((CGPath *)p)->_count;
}

static CGMutablePathRef
_CGPathExtend( CGMutablePathRef path, unsigned long size)
{
	if (((CGPath *)path)->_immutable == YES)
		NSLog(@"WARNING: CGPath is immutable **");
///		[NSException raise: NSGenericException format: @"CGPath is immutable"];

	path->_capacity += ((size > 8) ? size : size * 4) + path->_capacity;
	path->_pe = realloc(path->_pe, path->_capacity * sizeof(CGPathElement));
	memset (path->_pe + path->_count, 0, path->_capacity - path->_count);

    return path;
}

CGMutablePathRef
CGPathCreateMutable(void)
{
	CGPath *p = CFAllocatorAllocate(NULL, sizeof(CGPath) + 8, 0);

    if (p)
		{
		p->cf_pointer = (void *)&__CGPathClass;
		p->_capacity = 10;
		p->_pe = malloc((p->_capacity) * sizeof(CGPathElement));
		memset (p->_pe, 0, p->_capacity);
		}

    return p;
}

CGMutablePathRef
CGPathCreateMutableCopy( CGPathRef p)
{
    if (p != NULL)
		{
		CGPath *mp = CFAllocatorAllocate(NULL, sizeof(CGPath) + 8, 0);

		mp->cf_pointer = (void *)&__CGPathClass;
		mp->_p0 = p->_p0;
		mp->_bbox = p->_bbox;
		mp->_pbox = p->_pbox;
		mp->_capacity = p->_capacity;
		mp->_count = p->_count;
		mp->_pe = malloc((mp->_capacity) * sizeof(CGPathElement));
		memcpy (mp->_pe, p->_pe, ((mp->_count) * sizeof(CGPathElement)));

    	return mp;
		}

    return NULL;
}

CGPathRef
CGPathCreateCopy( CGPathRef p)
{
	if ((p = CGPathCreateMutableCopy(p)) != NULL)
		_CGPathMakeImmutable(p);

	return p;
}

void
CGPathRelease( CGPathRef path )
{
	if (path)
		CFRelease(path);
}

CGPathRef
CGPathRetain( CGPathRef path )
{
	return (path) ? CFRetain(path) : path;
}

static void
_CGPathAddLineToPoint( rCTX *s, CGPoint a)
{
	CGPathAddLineToPoint(s->copy, s->ctm, a.x, a.y);
}

static void
_CGPathDashLineToPoint( rCTX *r, CGPoint b)
{
 	CGPoint a = r->org;
	_CGPathDash *dash = r->dash;
	CGFloat segLen;
    CGFloat dx = b.x - a.x;
    CGFloat dy = b.y - a.y;
	CGFloat m0, lineLen;
	
	if (dx == 0)
		m0 = dy;
	else if (dy == 0)
		m0 = dx;
	else
		m0 = sqrt(dx * dx + dy * dy);			// length
	lineLen = m0 = ABS(m0);

	if (dash->phase > 0)
		{
		segLen = MIN(dash->phase, lineLen);
		a.x += dx * segLen / m0;
		a.y += dy * segLen / m0;
		CGPathAddLineToPoint(r->copy, r->ctm, a.x, a.y);		// ON
		lineLen -= segLen;
		dash->phase -= segLen;
		}

	for (; lineLen > 0; dash->cursor++)			// line extends beyond phase
		{
		unsigned int j = (dash->cursor % dash->count);

		segLen = MIN(dash->lengths[j], lineLen);
		 a.x += dx * segLen / m0;
		 a.y += dy * segLen / m0;

		if (j % 2)
			CGPathMoveToPoint(r->copy, r->ctm, a.x, a.y);		// OFF
		else
			CGPathAddLineToPoint(r->copy, r->ctm, a.x, a.y);	// ON
		lineLen -= segLen;
		}

	r->org = a;
}

void
CGPathCloseSubpath( CGMutablePathRef p)
{
	if (p->_count > 1)
		{
		if (p->_pe[p->_count-1].type == kCGPathElementCloseSubpath)
			NSLog(@" ****** CGPathCloseSubpath called twice for same path\n");
		else if (p->_count >= p->_capacity)
			p = _CGPathExtend(p, 1);
		p->_pe[p->_count].p1 = p->_pe[p->_subpath].p1;
		p->_pe[p->_count++].type = kCGPathElementCloseSubpath;
		p->_p0 = p->_pe[p->_subpath].p1;
		p->_subpath = 0;

		if (p->_vrtx != NULL)
			_CGPathReleaseCache(p);
		}
	else
		NSLog(@" ****** CGPathCloseSubpath called with an empty path\n");
}

void
CGPathMoveToPoint( CGMutablePathRef path,
				   const CGAffineTransform *m,
				   CGFloat x, CGFloat y)
{
	CGPoint a = (CGPoint){x,y};

	if (path->_count >= (path->_capacity - 2))
		path = _CGPathExtend(path, 2);

	path->_pbox = NSUnionRect(path->_pbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){a, {1,1}});

	if (path->_vrtx != NULL)
		_CGPathReleaseCache(path);

	if (m)
		a = CGPointApplyAffineTransform(a, *m);

	path->_pe[path->_count].type = kCGPathElementMoveToPoint;
	path->_pe[path->_count].p1 = a;
	path->_subpath = path->_count++;
	path->_p0 = (CGPoint){x,y};
}

void
CGPathAddLineToPoint( CGMutablePathRef path,
					  const CGAffineTransform *m,
					  CGFloat x, CGFloat y)
{
	CGPoint a = (CGPoint){x,y};

	if (path->_count >= (path->_capacity - 2))
		path = _CGPathExtend(path, 1);

	path->_pbox = NSUnionRect(path->_pbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){a, {1,1}});

	if (path->_vrtx != NULL)
		_CGPathReleaseCache(path);

	if (m)
		a = CGPointApplyAffineTransform(a, *m);

	path->_pe[path->_count].type = kCGPathElementAddLineToPoint;
	path->_pe[path->_count++].p1 = a;
	path->_p0 = (CGPoint){x,y};
}

/* ****************************************************************************

	Add quadratic curve from current point to x,y with control point.  Moves
	current point to x,y.  Transform all points by m first (if not NULL).
 
** ***************************************************************************/

void
CGPathAddQuadCurveToPoint( CGMutablePathRef path,
							const CGAffineTransform *m,
							CGFloat cp_x, CGFloat cp_y,
							CGFloat x, CGFloat y)
{
	CGPoint a = {x, y};
	CGPoint b = {cp_x, cp_y};

	if (path->_count >= (path->_capacity - 2))
		path = _CGPathExtend(path, 3);

	path->_pbox = NSUnionRect(path->_pbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){b, {1,1}});

	if (path->_vrtx != NULL)
		_CGPathReleaseCache(path);

	if (m)
		{
		a = CGPointApplyAffineTransform(a, *m);
		b = CGPointApplyAffineTransform(b, *m);
		}

	path->_pe[path->_count].type = kCGPathElementAddQuadCurveToPoint;
	path->_pe[path->_count].p1 = b;
	path->_pe[path->_count++].p2 = a;
	path->_p0 = (CGPoint){x,y};
}

/* ****************************************************************************

	Add cubic Bezier curve from current point P0 to (x,y) with control points
	CP1 and CP2.  Move current point to (x,y).  Transform points if m not NULL.

** ***************************************************************************/

void
CGPathAddCurveToPoint( CGMutablePathRef path,
					   const CGAffineTransform *m,
					   CGFloat cp1_x, CGFloat cp1_y,
					   CGFloat cp2_x, CGFloat cp2_y,
					   CGFloat x, CGFloat y)
{
	NSPoint a = (NSPoint){x, y};
	NSPoint b = (NSPoint){cp1_x, cp1_y};
	NSPoint c = (NSPoint){cp2_x, cp2_y};

	if (path->_count >= (path->_capacity - 2))
		path = _CGPathExtend(path, 4);

	path->_pbox = NSUnionRect(path->_pbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){a, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){b, {1,1}});
	path->_bbox = NSUnionRect(path->_bbox, (NSRect){c, {1,1}});

	if (path->_vrtx != NULL)
		_CGPathReleaseCache(path);

	if (m)
		{
		a = CGPointApplyAffineTransform(a, *m);
		b = CGPointApplyAffineTransform(b, *m);
		c = CGPointApplyAffineTransform(c, *m);
		}

	path->_pe[path->_count].type = kCGPathElementAddCurveToPoint;
	path->_pe[path->_count].p1 = b;
	path->_pe[path->_count].p2 = c;
	path->_pe[path->_count++].p3 = a;
	path->_p0 = (CGPoint){x,y};
}

void
CGPathAddArc( CGMutablePathRef path,
			  const CGAffineTransform *m,
			  CGFloat x, CGFloat y,
			  CGFloat radius,
			  CGFloat startAngle,
			  CGFloat endAngle,
			  bool clockwise)
{
    CGFloat delta;
	CGFloat termAngle;
	unsigned int segments = 1;

//	printf("ARC angles %f %f #\n", startAngle, endAngle);

	if (startAngle < 0.0)
		while (startAngle < 0.0)			startAngle += 2.0 * M_PI;
	else
		while (startAngle > 2.0 * M_PI)		startAngle -= 2.0 * M_PI;

	if (clockwise)		// normalize angles so that delta is less than 2*PI
		{
		while (startAngle < endAngle)
			endAngle -= M_PI * 2.0;
		}
	else
		{
		while (endAngle < startAngle)
			endAngle += M_PI * 2.0;
		}

	delta = endAngle - startAngle;
//	printf("ARC normal angles %f %f  DELTA %f\n", startAngle, endAngle, delta);

    CGVector v0 = { cos(startAngle) * radius, sin(startAngle) * radius };
    CGPoint p0 = { v0.dx + x, v0.dy + y };			// arc start point

    if (CGPathIsEmpty(path))		// move current point to arc start point
        CGPathMoveToPoint(path, m, p0.x, p0.y);
    else
        CGPathAddLineToPoint(path, m, p0.x, p0.y);

   if (fabs(delta) > M_PI_2)		// splice arcs to less than half a PI
   		{
		segments = fabs(delta) / M_PI_2 + 1;
		termAngle = endAngle;
		endAngle = startAngle + (M_PI_2 * (delta < 0 ? -1.0 : 1.0));
		delta = endAngle - startAngle;
		}

	while (segments--)
		{
    	CGVector v3 = {cos(endAngle) * radius, sin(endAngle) * radius};
    	CGPoint p3  = {v3.dx + x, v3.dy + y};

		// Calc CP offset for mid curve point that lies on circle from angle
		CGFloat cp_offset = (4.0 / 3.0) * tan(delta / 4.0);
//		CGFloat cp_offset = 0.552284777 * (delta < 0 ? -1.0 : 1.0);
		CGFloat cp1x = p0.x - (cp_offset * v0.dy);
		CGFloat cp1y = p0.y + (cp_offset * v0.dx);
		CGFloat cp2x = p3.x + (cp_offset * v3.dy);
		CGFloat cp2y = p3.y - (cp_offset * v3.dx);

    	CGPathAddCurveToPoint(path, m, cp1x, cp1y, cp2x, cp2y, p3.x, p3.y);

		if (segments)
			{
			startAngle = endAngle;
			if (segments <= 1)
				endAngle = termAngle;
			else
				endAngle += delta + (delta < 0 ? -0.005 : 0.005);
///				endAngle += (M_PI_2 * (delta < 0 ? -1.0 : 1.0));
			delta = endAngle - startAngle;
			v0 = (CGVector){cos(startAngle) * radius, sin(startAngle) * radius};
			p0 = (CGPoint){v0.dx + x, v0.dy + y};
			}
		}
}

void
CGPathAddArcToPoint( CGMutablePathRef path,			// convert to Polar coords
					 const CGAffineTransform *m,
					 CGFloat x1, CGFloat y1,
					 CGFloat x2, CGFloat y2,
					 CGFloat radius)
{
    CGFloat dx0 = path->_p0.x - x1;					// find tan line vectors
    CGFloat dy0 = path->_p0.y - y1;
    CGFloat dx1 = x2 - x1;
    CGFloat dy1 = y2 - y1;
	CGFloat rotation = dy0 * dx1 - dx0 * dy1;		// cross product vector

	if (rotation == 0)
		CGPathAddLineToPoint(path, m, x1, y1);		// tan lines are parallel
	else											// OSX draws point of width
		{
		CGFloat m0 = sqrt(dx0 * dx0 + dy0 * dy0);	// vector lengths
		CGFloat m1 = sqrt(dx1 * dx1 + dy1 * dy1);
		CGFloat cx, cy, sx, sy, ex, ey, s, e, t;

		if (rotation < 0)							// normalize to atan period
			{
			sx = -dy0 / m0;							// clockwise arc
			sy =  dx0 / m0;
			ex =  dy1 / m1;
			ey = -dx1 / m1;
			}
		else
			{
			sx =  dy0 / m0;
			sy = -dx0 / m0;
			ex = -dy1 / m1;
			ey =  dx1 / m1;
			}

		t = (dx1 * ey - dx1 * sy - dy1 * ex + dy1 * sx) / rotation;
		cx = x1 + radius * (t * dx0 + sx);			// arc center
		cy = y1 + radius * (t * dy0 + sy);
		s = atan2(-sy, -sx);						// start/end angles
		e = atan2(-ey, -ex);						// in range -PI to +PI

//	printf("ARC v0 %f %f v1 %f %f\n", dx0, dy0, dx1, dy1);
//	printf("ARC n0 %f %f n1 %f %f  mags %f %f\n", sx, sy, ex, ey, m0, m1);
//	printf("ARC tx %f ty %f\n", (t * dx0 + sx), (t * dy0 + sy));

		CGPathAddArc( path, m, cx, cy, radius, s, e, (rotation < 0) );
		path->_p0 = (CGPoint){x2, y2};
		}
}

void
CGPathAddRoundedRect( CGMutablePathRef p,
					  const CGAffineTransform *m,
					  CGRect r,
					  CGFloat cornerWidth,
					  CGFloat cornerHeight)
{
	float mx = NSMaxX(r);
	float my = NSMaxY(r);
	float radius = cornerWidth;		// FIX ME

	CGPathMoveToPoint(p, m, r.origin.x, r.origin.y + radius);
	CGPathAddLineToPoint(p, m, r.origin.x, my - radius);
	CGPathAddArc(p, m, r.origin.x + radius, my - radius, radius, M_PI, M_PI / 2, 1);
	CGPathAddLineToPoint(p, m, mx - radius, my);
	CGPathAddArc(p, m, mx - radius, my - radius, radius, M_PI / 2, 0.0, 1);
	CGPathAddLineToPoint(p, m, mx, r.origin.y + radius);
	CGPathAddArc(p, m, mx - radius, r.origin.y + radius, radius, 0.0, -M_PI / 2, 1);
	CGPathAddLineToPoint(p, m, r.origin.x + radius, r.origin.y);
	CGPathAddArc(p, m, r.origin.x + radius, r.origin.y + radius, radius, -M_PI / 2, M_PI, 1);
	CGPathCloseSubpath(p);
}

void
CGPathAddRect( CGMutablePathRef p, const CGAffineTransform *m, CGRect r)
{
	float mx = NSMaxX(r);
	float my = NSMaxY(r);

	CGPathMoveToPoint(p, m, r.origin.x, r.origin.y);
	CGPathAddLineToPoint(p, m, r.origin.x, my);
	CGPathAddLineToPoint(p, m, mx, my);
	CGPathAddLineToPoint(p, m, mx, r.origin.y);
	CGPathCloseSubpath(p);
}

void
CGPathAddRects( CGMutablePathRef p,
				const CGAffineTransform *m,
				const CGRect rects[],
				size_t count)
{
	int i;
	
	if (rects && p)
		for (i = 0; i < count; i++)
			CGPathAddRect(p, m, rects[i]);
}

void
CGPathAddLines( CGMutablePathRef p,
				const CGAffineTransform *m,
				const CGPoint points[],
				size_t count)
{
	int i;

	if (points && p)
		for (i = 0; i < count; i++)
			{
			if (i % 2)
				CGPathAddLineToPoint(p, m, points[i].x, points[i].y);
			else
				CGPathMoveToPoint(p, m, points[i].x, points[i].y);
			}
}

void
CGPathAddEllipseInRect( CGMutablePathRef path,
						const CGAffineTransform *m,
						CGRect rect)
{
	double dx = rect.size.width / 2.0 * 0.55191502449;		// or 0.552284777
	double dy = rect.size.height / 2.0 * 0.55191502449;
	CGFloat mx = NSMaxX(rect);
	CGFloat my = NSMaxY(rect);
	CGFloat x  = NSMinX(rect);
	CGFloat y  = NSMinY(rect);
	CGFloat x2 = NSMidX(rect);
	CGFloat y2 = NSMidY(rect);

	CGPathMoveToPoint(path, m, x2, my);
	CGPathAddCurveToPoint(path, m, x2 - dx, my, x, y2 + dy, x, y2);
	CGPathAddCurveToPoint(path, m, x, y2 - dy, x2 - dx, y, x2, y);
	CGPathAddCurveToPoint(path, m, x2 + dx, y, mx, y2 - dy, mx, y2);
	CGPathAddCurveToPoint(path, m, mx, y2 + dy, x2 + dx, my, x2, my);
	CGPathCloseSubpath(path);
}

void
CGPathAddPath( CGMutablePathRef p1, const CGAffineTransform *m, CGPathRef p2)
{
	int i;

	if (!p1 || !p2 || p2->_count == 0)
		return;

	if (p1->_count + p2->_count >= (p1->_capacity - 2))
		p1 = _CGPathExtend(p1, p2->_count + 4);

	if (!m)
		{
		memcpy(&p1->_pe[p1->_count], &p2->_pe[0], p2->_count * sizeof(CGPathElement));
		p1->_count += p2->_count;
		return;
		}

	for (i = 0; i < p2->_count; i++)				// transform while adding
		{
		CGPathElement *e = &((CGPath *)p2)->_pe[i];

		switch (e->type)
			{
			case NSMoveToBezierPathElement:
				CGPathMoveToPoint(p1, m, e->points[0].x, e->points[0].y);
				break;

			case NSLineToBezierPathElement:
				CGPathAddLineToPoint(p1, m, e->points[0].x, e->points[0].y);
				break;

			case _NSQuadCurveToBezierPathElement:
				CGPathAddQuadCurveToPoint(p1, m, e->points[0].x, e->points[0].y,
												 e->points[1].x, e->points[1].y);
				break;

			case NSCurveToBezierPathElement:
				CGPathAddCurveToPoint(p1, m, e->points[0].x, e->points[0].y,
											 e->points[1].x, e->points[1].y,
											 e->points[2].x, e->points[2].y);
				break;

			case NSClosePathBezierPathElement:
				CGPathCloseSubpath(p1);
			default:
				break;
		}	}
}

CGPoint
CGPathGetCurrentPoint( CGPathRef p)
{
	return (p == NULL || p->_count == 0) ? CGPointZero : p->_p0;
}

bool
CGPathIsEmpty( CGPathRef p)
{
	return (p == NULL || p->_count == 0) ? YES : NO;
}

bool
CGPathIsRect( CGPathRef p, CGRect *r)
{
	if (p == NULL || p->_count < 5)
		return NO;

	if (p->_pe[0].type == kCGPathElementMoveToPoint)
		{
		float mx;
		float my;
		int i;

		r->origin = p->_pe[0].p1;

		for (i = 1; i < 5; i++)
			{
			if (p->_pe[i].type != kCGPathElementAddLineToPoint)
				break;

			mx = MAX(mx, p->_pe[i].p1.x);
			my = MAX(my, p->_pe[i].p1.y);
			}

		if (i == 4)
			{
			r->size = (CGSize){mx - r->origin.x, my - r->origin.y};

			return YES;
			}
		}

	return NO;			// FIX ME more than 4 elements, rounded rect ?
}

bool
CGPathEqualToPath(CGPathRef p1, CGPathRef p2)
{
	NSUInteger i, j, typePoints;

	if (p1 == p2)
		return YES;
	if (!p1 || !p2 || p1->_count != p2->_count)
		return NO;

	for (i = 0; i < p1->_count; i += j)
		{
		if (p1->_pe[i].type != p2->_pe[i].type)
			return NO;

		switch (p1->_pe[i].type)
			{
			default:
			case kCGPathElementCloseSubpath:
			case kCGPathElementMoveToPoint:
			case kCGPathElementAddLineToPoint:		typePoints = 1;	 break;
			case kCGPathElementAddQuadCurveToPoint:	typePoints = 2;  break;
			case kCGPathElementAddCurveToPoint:		typePoints = 3;  break;
			}

		for (j = 0; j < typePoints; j++)
			if (!NSEqualPoints(p1->_pe[i].points[j], p2->_pe[i].points[j]))
				return NO;
		}

	return YES;
}

/* ****************************************************************************

	Recursive subdivision until flat  (De Casteljau's algorithm).

	This criteria for flatness is based on code from Libart with copyright:

	Libart_LGPL - library of basic graphic primitives
	Copyright (C) 1998 Raph Levien

** ***************************************************************************/

static void
_CGPathStrokeCurve( rCTX *s, NSPoint pts[])
{
	bool flat = YES;
	double x3_0 = pts[3].x - pts[0].x;
	double y3_0 = pts[3].y - pts[0].y;
	double x3_2 = pts[3].x - pts[2].x;
	double y3_2 = pts[3].y - pts[2].y;
	double x1_0 = pts[1].x - pts[0].x;
	double y1_0 = pts[1].y - pts[0].y;
	double z3_0_dot = x3_0 * x3_0 + y3_0 * y3_0;
	
	if (z3_0_dot < 0.001)
		flat = YES;
	else
		{
		double max_perp_sq = s->flatness * s->flatness * z3_0_dot;
		
		double z1_perp = y1_0 * x3_0 - x1_0 * y3_0;
		if (z1_perp * z1_perp > max_perp_sq)
			flat = NO;
		else
			{
			double z2_perp = y3_2 * x3_0 - x3_2 * y3_0;
			if (z2_perp * z2_perp > max_perp_sq)
				flat = NO;
			else
				{
				double z1_dot = x1_0 * x3_0 + y1_0 * y3_0;
				if (z1_dot < 0 && z1_dot * z1_dot > max_perp_sq)
					flat = NO;
				else
					{
					double z2_dot = x3_2 * x3_0 + y3_2 * y3_0;
					if (z2_dot < 0 && z2_dot * z2_dot > max_perp_sq)
						flat = NO;
					else
						{
						if ((z1_dot + z1_dot > z3_0_dot) || (z2_dot + z2_dot > z3_0_dot))
							flat = NO;
		}	}	}	}	}

	if (flat)
		s->lineto(s, pts[3]);
	else
		{
		NSPoint bl[4], br[4];			// split into left and right Beziers
		
		bl[0] = pts[0];
		bl[1].x = (pts[0].x + pts[1].x) / 2;
		bl[1].y = (pts[0].y + pts[1].y) / 2;
		bl[2].x = (pts[0].x + 2*pts[1].x + pts[2].x) / 4;
		bl[2].y = (pts[0].y + 2*pts[1].y + pts[2].y) / 4;
		bl[3].x = (pts[0].x + 3*(pts[1].x + pts[2].x) + pts[3].x) / 8;
		bl[3].y = (pts[0].y + 3*(pts[1].y + pts[2].y) + pts[3].y) / 8;
		br[0].x = bl[3].x;
		br[0].y = bl[3].y;
		br[1].x = (pts[3].x + 2*pts[2].x + pts[1].x) / 4;
		br[1].y = (pts[3].y + 2*pts[2].y + pts[1].y) / 4;
		br[2].x = (pts[3].x + pts[2].x) / 2;
		br[2].y = (pts[3].y + pts[2].y) / 2;
		br[3] = pts[3];

		_CGPathStrokeCurve(s, bl);
		_CGPathStrokeCurve(s, br);
		}
}

static CGPathRef
_CGPathStrokeCopy( CGPath *p, rCTX *s, CGMutablePathRef path)
{
	NSPoint p0;
	NSPoint subpath_org;
	NSPoint pts[4];
	NSUInteger i;

	s->copy = path;

	for (i = 0; i < p->_count; i++)
		switch (p->_pe[i].type)
			{
			case kCGPathElementMoveToPoint:		// NSMoveToBezierPathElement
				pts[0] = p->_pe[i].p1;
        		CGPathMoveToPoint(s->copy, s->ctm, pts[0].x, pts[0].y);
				s->org = subpath_org = p0 = pts[0];
				break;

			case kCGPathElementAddLineToPoint:	// NSLineToBezierPathElement
				pts[0] = p->_pe[i].p1;
				s->lineto(s, pts[0]);
				p0 = pts[0];
				break;

			case kCGPathElementAddQuadCurveToPoint:
				pts[0] = p0;
				pts[1] = p0;
				pts[2] = p->_pe[i].p1;
				pts[3] = p->_pe[i].p2;
				_CGPathStrokeCurve(s, pts);		// FIX ME test
				p0 = pts[3];
				break;

			case kCGPathElementAddCurveToPoint:	// NSCurveToBezierPathElement
				pts[0] = p0;
				pts[1] = p->_pe[i].p1;
				pts[2] = p->_pe[i].p2;
				pts[3] = p->_pe[i].p3;
				_CGPathStrokeCurve(s, pts);
				p0 = pts[3];
				break;

			case kCGPathElementCloseSubpath:	// NSClosePathBezierPathElement
				if (s->dash != NULL)
					{
					unsigned long subpath = ((CGPath *)path)->_subpath;
					CGPoint a = ((CGPath *)path)->_pe[subpath].p1;

					s->lineto(s, a);
					}
				CGPathCloseSubpath(path);
				p0 = subpath_org;

			default:
				break;
			}

	if (path != NULL)
		_CGPathMakeImmutable(path);
	
	return path;
}

CGPathRef
CGPathCreateCopyByStrokingPath( CGPathRef p,
								const CGAffineTransform *m,
								CGFloat    lineWidth,
								CGLineCap  lineCap,
								CGLineJoin lineJoin,
								CGFloat    miterLimit)
{
	CGMutablePathRef path = CGPathCreateMutable();
	_CGRenderCTX r = {0};
	CGContext *cx;

	r.lineto = _CGPathAddLineToPoint;
	r.flatness = (cx = CTX) ? cx->_gs->_line.flatness : 0.1;
	r.ctm = m;
										// FIX ME add stroke attributes
	return _CGPathStrokeCopy( (CGPath *)p, &r, path);
}

CGPathRef
CGPathCreateCopyByDashingPath( CGPathRef p,
							   const CGAffineTransform *m,
							   CGFloat phase,
							   const CGFloat *lengths,
							   size_t count)
{
	if (lengths != NULL && count > 0)
		{
		_CGPathDash d = (_CGPathDash){phase, lengths, count, 0};
		_CGRenderCTX r = {0};
		CGContext *cx;

		r.dash = &d;
		r.lineto = _CGPathDashLineToPoint;
		r.flatness = (cx = CTX) ? cx->_gs->_line.flatness : 0.1;
		r.ctm = m;

		return _CGPathStrokeCopy( (CGPath *)p, &r, CGPathCreateMutable());
		}

	return NULL;
}

CGMutablePathRef
CGPathCreateMutableCopyByTransformingPath( CGPathRef p,
										   const CGAffineTransform *m)
{
	CGMutablePathRef n = CGPathCreateMutableCopy(p);
	NSUInteger i;

	n->_bbox = n->_pbox = CGRectZero;
	
	for (i = 0; i < ((CGPath *)p)->_count; i++)
		switch (p->_pe[i].type)
			{
			case NSCurveToBezierPathElement:
				n->_pe[i].p3 = CGPointApplyAffineTransform(p->_pe[i].p3, *m);
				n->_bbox = NSUnionRect(n->_bbox, (NSRect){n->_pe[i].p3, {1,1}});
			case _NSQuadCurveToBezierPathElement:
				n->_pe[i].p2 = CGPointApplyAffineTransform(p->_pe[i].p2, *m);
				n->_bbox = NSUnionRect(n->_bbox, (NSRect){n->_pe[i].p2, {1,1}});
			case NSMoveToBezierPathElement:
			case NSLineToBezierPathElement:
			case NSClosePathBezierPathElement:
				n->_pe[i].p1 = CGPointApplyAffineTransform(p->_pe[i].p1, *m);
				n->_bbox = NSUnionRect(n->_bbox, (NSRect){n->_pe[i].p1, {1,1}});
				n->_pbox = NSUnionRect(n->_pbox, (NSRect){n->_pe[i].p1, {1,1}});
			default:
				break;
			}

	((CGPath *)n)->_count = i;

	return n;
}

CGPathRef
CGPathCreateCopyByTransformingPath( CGPathRef p, const CGAffineTransform *m)
{
	if ((p = CGPathCreateMutableCopyByTransformingPath(p, m)) != NULL)
		_CGPathMakeImmutable(p);

	return p;
}

CGRect
CGPathGetBoundingBox( CGPathRef p)						// with control points
{
	return (p && p->_count) ? p->_bbox : CGRectNull;
}

CGRect
CGPathGetPathBoundingBox( CGPathRef p)					// w/o control points
{
	return (p && p->_count) ? p->_pbox : CGRectNull;
}

/* ****************************************************************************

	Point in Poly algorithm origins unknown or disputed.
	Code is derived from public domain and BSD license examples provided by:
	
	Copyright 2000 softSurfer, 2012 Dan Sunday
	http://geomalgorithms.com/a03-_inclusion.html

	Copyright (c) 1970-2003, Wm. Randolph Franklin
	https://wrf.ecse.rpi.edu//Research/Short_Notes/pnpoly.html#Polyhedron

** ***************************************************************************/

static int
eo_pnpoly(NSInteger count, CGPoint v[], float x, float y)
{
	NSInteger j = count;
	int i, c = 0;

	for (i = 0; i < count; j = i++)
		if ( ((v[i].y > y) != (v[j].y > y))
			  && (x <= (v[j].x - v[i].x) * (y - v[i].y) / (v[j].y - v[i].y) + v[i].x) )
			c = !c;

	return c;
}

/* ****************************************************************************

	cn_PnPoly()		crossing number test for a point in a polygon

	V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
	0 = outside
	1 = inside

** ***************************************************************************/

static int
cn_PnPoly( NSInteger count, CGPoint *V, float x, float y)
{
    int i, cn = 0;							// crossing number counter

    for (i = 0; i < count; i++)				// loop thru edges of polygon
		{									// edge from V[i] to V[i+1]
		if (((V[i].y <= y) && (V[i+1].y > y))			// upward crossing
				|| ((V[i].y > y) && (V[i+1].y <= y)))	// downward crossing
			{				// compute actual edge-ray intersect x-coordinate
            float vt = (y - V[i].y) / (V[i+1].y - V[i].y);

            if (x <= V[i].x + vt * (V[i+1].x - V[i].x))	// P.x < intersect or ON
                 ++cn;		// a valid crossing of y=P.y right of P.x
			}
		}

    return (cn&1);							// 0 if even (out), 1 if odd (in)
}

/* ****************************************************************************

	isLeft()  test if P2 is Left/On/Right of an infinite line.

	>0 = P2 left of line from P0 and P1
	=0 = P2 on the line
	<0 = P2 right of the line

** ***************************************************************************/

static inline int
isLeft( CGPoint P0, CGPoint P1, CGPoint P2 )
{
    return ( (P1.x - P0.x) * (P2.y - P0.y) - (P2.x -  P0.x) * (P1.y - P0.y) );
}

/* ****************************************************************************

	wn_PnPoly(): winding number test for a point in a polygon

	V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
	wn = the winding number (=0 only when P is outside)

** ***************************************************************************/

static int
wn_PnPoly( NSInteger count, CGPoint *V, float x, float y)
{
    int i, wn = 0;							// winding number counter

    for (i = 0; i < count; i++)				// loop thru edges of polygon
		{									// edge from V[i] to V[i+1]
        if (V[i].y <= y)
			{								// start y <= P.y
            if (V[i+1].y > y)				// an upward crossing
                 if (isLeft( V[i], V[i+1], (CGPoint){x,y}) >= 0)  // P left of edge or ON
                     ++wn;					// valid up intersect
			}
        else
			{								// start y > P.y (no test needed)
            if (V[i+1].y <= y)				// a downward crossing
                 if (isLeft( V[i], V[i+1], (CGPoint){x,y}) < 0)  // P right of edge
                     --wn;					// valid down intersect
			}
		}

    return wn;
}

static void
_CGPathGetVertices(CGPath *p)
{
	CGPathRef sp = CGPathCreateCopyByStrokingPath( p, NULL, 1.0, 0, 0, 1);
	NSUInteger i;

	p->_vrtx = calloc(((CGPath *)sp)->_count, sizeof(CGPoint));
	p->_vrtxCount = ((CGPath *)sp)->_count;

	for (i = 0; i < p->_vrtxCount; i++)
		p->_vrtx[i] = sp->_pe[i].p1;

	CGPathRelease(sp);
}

static bool
_CGPathPointInPoly(CGPathRef p, CGPoint a, bool eo)
{
	bool inside;

	if (p->_vrtx == NULL)
		_CGPathGetVertices((CGPath *)p);

	if (eo)									// test with Even-Odd rule
		inside = (eo_pnpoly(p->_vrtxCount - 1, p->_vrtx, a.x, a.y) == 1);
	else									// test with Winding rule
		inside = (wn_PnPoly(p->_vrtxCount - 1, p->_vrtx, a.x, a.y) != 0);

	return inside;
}

bool
CGPathContainsPoint(CGPathRef p, const CGAffineTransform *m, CGPoint a, bool eo)
{
	if (!p || p->_count == 0)
		return NO;

	if (!NSPointInRect(a, CGPathGetBoundingBox(p)))
		return NO;

	if (m)
		a = CGPointApplyAffineTransform(a, *m);

	return _CGPathPointInPoly(p, a, eo);
}
