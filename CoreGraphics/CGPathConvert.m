/*
   CGPathConvert.m

   Convert path into a Global Edge Table.

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGPath.h>



static void
Line(gGET *g, const CGAffineTransform *m, float x, float y, float x1, float y1)
{
	float tx  = m->a * x + m->c * y + m->tx;
	float ty  = m->b * x + m->d * y + m->ty;
	float tx1 = m->a * x1 + m->c * y1 + m->tx;
	float ty1 = m->b * x1 + m->d * y1 + m->ty;

	_CGAddEdgeGET(g, tx, ty, tx1, ty1);
}

static void
Arc(rCTX *r, float xc, float yc, float x0, float y0, float x1, float y1)
{
	float aradius = fabs(r->linewidth);
	float theta = 2 * M_SQRT2 * sqrt(r->flatness / aradius);
	float th0 = atan2(y0, x0);
	float th1 = atan2(y1, x1);
	CGPoint o = (CGPoint){x0, y0};
	CGPoint n;
	int np, i;

	if (r->linewidth > 0)
		{
		if (th0 < th1)							// curve to the left
			th0 += M_PI * 2;
		np = ceil((th0 - th1) / theta);
		}
	else
		{
		if (th1 < th0)							// curve to the right
			th1 += M_PI * 2;
		np = ceil((th1 - th0) / theta);
		}

	for (i = 1; i < np; i++)
		{
		theta = th0 + (th1 - th0) * i / np;
		n = (CGPoint){cos(theta) * aradius, sin(theta) * aradius};
		Line(r->get, r->ctm, xc + o.x, yc + o.y, xc + n.x, yc + n.y);
		o = n;
		}

	Line(r->get, r->ctm, xc + o.x, yc + o.y, xc + x1, yc + y1);
}

static void
LineStroke(rCTX *r, CGPoint a, CGPoint b)
{
	float dx = b.x - a.x;
	float dy = b.y - a.y;
	float scale = r->linewidth / sqrt(dx * dx + dy * dy);
	float dlx = dy * scale;
	float dly = -dx * scale;

	Line(r->get, r->ctm, a.x - dlx, a.y - dly, b.x - dlx, b.y - dly);
	Line(r->get, r->ctm, b.x + dlx, b.y + dly, a.x + dlx, a.y + dly);
}

static void
LineJoin(rCTX *r, CGPoint a, CGPoint b, CGPoint c)
{
	int linejoin = r->linejoin;
	float linewidth = r->linewidth;
	float dlx0, dly0;
	float dlx1, dly1;
	float dmx, dmy;
	float dmr2;
	float scale;
	float cross;
	float dx0 = b.x - a.x;			// vectors of lines from a to b and b to c
	float dy0 = b.y - a.y;
	float dx1 = c.x - b.x;
	float dy1 = c.y - b.y;

	if (dx0 * dx0 + dy0 * dy0 < FLT_EPSILON)
		linejoin = kCGLineJoinBevel;
	if (dx1 * dx1 + dy1 * dy1 < FLT_EPSILON)
		linejoin = kCGLineJoinBevel;

	scale = linewidth / sqrt(dx0 * dx0 + dy0 * dy0);
	dlx0 = dy0 * scale;
	dly0 = -dx0 * scale;

	scale = linewidth / sqrt(dx1 * dx1 + dy1 * dy1);
	dlx1 = dy1 * scale;
	dly1 = -dx1 * scale;

	cross = dx1 * dy0 - dx0 * dy1;	// pos for positive area (i.e. left turn)

	dmx = (dlx0 + dlx1) * 0.5;
	dmy = (dly0 + dly1) * 0.5;
	dmr2 = dmx * dmx + dmy * dmy;

	if (cross * cross < FLT_EPSILON && dx0 * dx1 + dy0 * dy1 >= 0)
		linejoin = kCGLineJoinBevel;

	if (linejoin == kCGLineJoinMiter)
		if (dmr2 * r->miterlimit * r->miterlimit < linewidth * linewidth)
			linejoin = kCGLineJoinBevel;

	if (linejoin == kCGLineJoinBevel)
		{
		Line(r->get, r->ctm, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
		Line(r->get, r->ctm, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
		}
	else if (linejoin == kCGLineJoinMiter)
		{
		scale = linewidth * linewidth / dmr2;
		dmx *= scale;
		dmy *= scale;

		if (cross < 0)
			{
			Line(r->get, r->ctm, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
			Line(r->get, r->ctm, b.x + dlx1, b.y + dly1, b.x + dmx, b.y + dmy);
			Line(r->get, r->ctm, b.x + dmx, b.y + dmy, b.x + dlx0, b.y + dly0);
			}
		else
			{
			Line(r->get, r->ctm, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
			Line(r->get, r->ctm, b.x - dlx0, b.y - dly0, b.x - dmx, b.y - dmy);
			Line(r->get, r->ctm, b.x - dmx, b.y - dmy, b.x - dlx1, b.y - dly1);
			}
		}
	else if (linejoin == kCGLineJoinRound)
		{
		if (cross < 0)
			{
			Line(r->get, r->ctm, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
			Arc(r, b.x, b.y, dlx1, dly1, dlx0, dly0);
			}
		else
			{
			Line(r->get, r->ctm, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
			Arc(r, b.x, b.y, -dlx0, -dly0, -dlx1, -dly1);
			}
		}
}

static void
LineCap(rCTX *r, CGPoint a, CGPoint b)
{
	float linewidth = r->linewidth;
	float dx = b.x - a.x;
	float dy = b.y - a.y;
	float scale = linewidth / sqrt(dx * dx + dy * dy);
	float dlx = dy * scale;
	float dly = -dx * scale;

	if (r->linecap == kCGLineCapButt)
		Line(r->get, r->ctm, b.x - dlx, b.y - dly, b.x + dlx, b.y + dly);
	else if (r->linecap == kCGLineCapRound)
		{
		int np = ceil(M_PI / (2.0 * M_SQRT2 * sqrt(r->flatness / linewidth)));
		CGPoint o = (CGPoint){b.x - dlx, b.y - dly};
		int i;

		for (i = 1; i < np; i++)
			{
			float theta = M_PI * i / np;
			float c_th = cos(theta);
			float s_th = sin(theta);
			float nx = b.x - dlx * c_th - dly * s_th;
			float ny = b.y - dly * c_th + dlx * s_th;

			Line(r->get, r->ctm, o.x, o.y, nx, ny);
			o.x = nx;
			o.y = ny;
			}
		Line(r->get, r->ctm, o.x, o.y, b.x + dlx, b.y + dly);
		}
	else if (r->linecap == kCGLineCapSquare)
		{
		Line(r->get, r->ctm, b.x - dlx, b.y - dly, b.x - dlx - dly, b.y - dly + dlx);
		Line(r->get, r->ctm, b.x - dlx - dly, b.y - dly + dlx, b.x + dlx - dly, b.y + dly + dlx);
		Line(r->get, r->ctm, b.x + dlx - dly, b.y + dly + dlx, b.x + dlx, b.y + dly);
		}
}

static void
LineDot(rCTX *r, CGPoint a)
{
	float linewidth = r->linewidth;
	CGPoint o = (CGPoint){a.x - linewidth, a.y};
	int np = ceil(M_PI / (M_SQRT2 * sqrt(r->flatness / linewidth)));
	int i;

	for (i = 1; i < np; i++)
		{
		float theta = M_PI * 2 * i / np;
		float c_th = cos(theta);
		float s_th = sin(theta);
		CGPoint n = (CGPoint){a.x - c_th * linewidth, a.y + s_th * linewidth};

		Line(r->get, r->ctm, o.x, o.y, n.x, n.y);
		o = n;
		}
	Line(r->get, r->ctm, o.x, o.y, a.x - linewidth, a.y);
}

static void
StrokeCap(rCTX *r)
{
	if (r->lenB == 2)
		{
		LineCap(r, r->vA[1], r->vA[0]);
		LineCap(r, r->vB[0], r->vB[1]);
		}
	else if (r->dot)
		LineDot(r, r->vA[0]);

	r->dot = 0;
}

static void
StrokeMoveto(rCTX *r, CGPoint a)
{
	StrokeCap(r);

	r->vA[0] = r->vB[0] = a;
	r->lenA = r->lenB = 1;
}

static void
StrokeLineto(rCTX *r, CGPoint a)
{
	float dx = a.x - r->vB[r->lenB-1].x;
	float dy = a.y - r->vB[r->lenB-1].y;

	if (dx * dx + dy * dy > FLT_EPSILON)
		{
		LineStroke(r, r->vB[r->lenB-1], a);

		if (r->lenB == 2)
			{
			LineJoin(r, r->vB[0], r->vB[1], a);
			r->vB[0] = r->vB[1];
			r->vB[1] = a;
			}

		if (r->lenB == 1)
			r->vB[r->lenB++] = a;
		if (r->lenA == 1)
			r->vA[r->lenA++] = a;
		}
	else
		r->dot = 1;
}

static void
StrokeClosepath(rCTX *r)
{
	if (r->lenB == 2)
		{
		StrokeLineto(r, r->vA[0]);

		if (NSEqualPoints(r->vB[1], r->vA[0]))
			LineJoin(r, r->vB[0], r->vA[0], r->vA[1]);
		else
			LineJoin(r, r->vB[1], r->vA[0], r->vA[1]);
		}
	else if (r->dot)
		LineDot(r, r->vA[0]);

	r->lenA = 0;
	r->lenB = 0;
	r->dot = 0;
}

static void
DashLineto(rCTX *r, CGPoint b)
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
		StrokeLineto(r, a);						// ON
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
			StrokeMoveto(r, a);					// OFF
		else
			StrokeLineto(r, a);					// ON
		lineLen -= segLen;
		}

	r->org = a;
}

static void
StrokeCurve(rCTX *r, CGPoint p, CGPoint p1, CGPoint p2, CGPoint p3)
{
	float d = ABS(p.x - p1.x);

	d = MAX(d, ABS(p.y - p1.y));
	d = MAX(d, ABS(p3.x - p2.x));
	d = MAX(d, ABS(p3.y - p2.y));

	if (d < r->flatness)
		r->lineto(r, p3);
	else
		{
		CGPoint ab = (CGPoint){p.x + p1.x, p.y + p1.y};
		CGPoint bc = (CGPoint){p1.x + p2.x, p1.y + p2.y};
		CGPoint cd = (CGPoint){p2.x + p3.x, p2.y + p3.y};
		CGPoint abc = (CGPoint){ab.x + bc.x, ab.y + bc.y};
		CGPoint bcd = (CGPoint){bc.x + cd.x, bc.y + cd.y};
		CGPoint abcd = (CGPoint){abc.x + bcd.x, abc.y + bcd.y};

		ab = (CGPoint){ab.x * 0.5, ab.y * 0.5};
		bc = (CGPoint){bc.x * 0.5, bc.y * 0.5};
		cd = (CGPoint){cd.x * 0.5, cd.y * 0.5};
		abc = (CGPoint){abc.x * 0.25, abc.y * 0.25};
		bcd = (CGPoint){bcd.x * 0.25, bcd.y * 0.25};
		abcd = (CGPoint){abcd.x * 0.125, abcd.y * 0.125};

		StrokeCurve(r, p, ab, abc, abcd);
		StrokeCurve(r, abcd, bcd, cd, p3);
		}
}

void
_CGPathStroke( CGPath *path, _CGRenderCTX *r)
{
	CGPoint p0 = {0,0};
	CGPoint p1, p2, p3, b;
	int i;

	if (r->dash)
		{
		r->lineto = DashLineto;
		r->dash->cursor = 0;
		}
	else
		r->lineto = StrokeLineto;

	for (i = 0; i < path->_count; i++)
		switch (path->_pe[i].type)
			{
			case kCGPathElementMoveToPoint:
				p1 = path->_pe[i].p1;
				StrokeMoveto(r, p1);
				r->org = b = p0 = p1;
				break;

			case kCGPathElementAddLineToPoint:
				p1 = path->_pe[i].p1;
				r->lineto(r, p1);
				p0 = p1;
				break;

			case kCGPathElementAddQuadCurveToPoint:
				p1 = p0;
				p2 = path->_pe[i].p1;
				p3 = path->_pe[i].p2;
				StrokeCurve(r, p0, p1, p2, p3);
				p0 = p3;
				break;

			case kCGPathElementAddCurveToPoint:
				p1 = path->_pe[i].p1;
				p2 = path->_pe[i].p2;
				p3 = path->_pe[i].p3;
				StrokeCurve(r, p0, p1, p2, p3);
				p0 = p3;
				break;

			case kCGPathElementCloseSubpath:
				if (r->dash)
					r->lineto(r, b);
				else
					StrokeClosepath(r);
				break;
			}

	StrokeCap(r);
}

static void
FillCurve(gGET *get, CGAffineTransform *m, float flatness, CGPoint p, CGPoint p1, CGPoint p2, CGPoint p3)
{
	float d = ABS(p.x - p1.x);

	d = MAX(d, ABS(p.y - p1.y));
	d = MAX(d, ABS(p3.x - p2.x));
	d = MAX(d, ABS(p3.y - p2.y));

	if (d < flatness)
		Line(get, m, p.x, p.y, p3.x, p3.y);
	else
		{
		CGPoint ab = (CGPoint){p.x + p1.x, p.y + p1.y};
		CGPoint bc = (CGPoint){p1.x + p2.x, p1.y + p2.y};
		CGPoint cd = (CGPoint){p2.x + p3.x, p2.y + p3.y};
		CGPoint abc = (CGPoint){ab.x + bc.x, ab.y + bc.y};
		CGPoint bcd = (CGPoint){bc.x + cd.x, bc.y + cd.y};
		CGPoint abcd = (CGPoint){abc.x + bcd.x, abc.y + bcd.y};

		ab = (CGPoint){ab.x * 0.5, ab.y * 0.5};
		bc = (CGPoint){bc.x * 0.5, bc.y * 0.5};
		cd = (CGPoint){cd.x * 0.5, cd.y * 0.5};
		abc = (CGPoint){abc.x * 0.25, abc.y * 0.25};
		bcd = (CGPoint){bcd.x * 0.25, bcd.y * 0.25};
		abcd = (CGPoint){abcd.x * 0.125, abcd.y * 0.125};

		FillCurve(get, m, flatness, p, ab, abc, abcd);
		FillCurve(get, m, flatness, abcd, bcd, cd, p3);
		}
}

void
_CGPathFill(CGPath *path, gGET *get, CGAffineTransform *m, float flatness)
{
	CGPoint p, p1, p2;
	CGPoint b = {0,0};
	CGPoint c = {0,0};
	int i;

	for (i = 0; i < path->_count; i++)
		switch (path->_pe[i].type)
			{
			case kCGPathElementMoveToPoint:
				if (i && (c.x != b.x || c.y != b.y))	// implicit closepath
					Line(get, m, c.x, c.y, b.x, b.y);
				c = b = p = path->_pe[i].p1;
				break;

			case kCGPathElementAddLineToPoint:
				p = path->_pe[i].p1;
				Line(get, m, c.x, c.y, p.x, p.y);
				c = p;
				break;

			case kCGPathElementAddQuadCurveToPoint:
				p  = c;
				p1 = path->_pe[i].p1;
				p2 = path->_pe[i].p2;
				FillCurve(get, m, flatness, c, p, p1, p2);
				c = p2;
				break;

			case kCGPathElementAddCurveToPoint:
				p  = path->_pe[i].p1;
				p1 = path->_pe[i].p2;
				p2 = path->_pe[i].p3;
				FillCurve(get, m, flatness, c, p, p1, p2);
				c = p2;
				break;

			case kCGPathElementCloseSubpath:
				Line(get, m, c.x, c.y, b.x, b.y);
				c = b;
				break;
			}

	if (i && (c.x != b.x || c.y != b.y))
		Line(get, m, c.x, c.y, b.x, b.y);
}

void
_CGPathDescription(CGPath *path, NSUInteger indent)
{
	NSUInteger i, j;
	CGPoint p;

	for (i = 0; i < path->_count; i++)
		{
		for (j = 0; j < indent; j++)
			putchar(' ');
		switch (path->_pe[i].type)
			{
			case kCGPathElementMoveToPoint:
				p = path->_pe[i].p1;
				printf("%g %g moveto\n", p.x, p.y);
				break;
			case kCGPathElementAddLineToPoint:
				p = path->_pe[i].p1;
				printf("%g %g lineto\n", p.x, p.y);
				break;
			case kCGPathElementAddQuadCurveToPoint:
				p = path->_pe[i].p1;
				printf("%g %g ", p.x, p.y);
				p = path->_pe[i].p2;
				printf("%g %g curvetoq\n", p.x, p.y);
				break;
			case kCGPathElementAddCurveToPoint:
				p = path->_pe[i].p1;
				printf("%g %g ", p.x, p.y);
				p = path->_pe[i].p2;
				printf("%g %g ", p.x, p.y);
				p = path->_pe[i].p3;
				printf("%g %g curveto\n", p.x, p.y);
				break;
			case kCGPathElementCloseSubpath:
				printf("closepath\n");
			}
		}
}
