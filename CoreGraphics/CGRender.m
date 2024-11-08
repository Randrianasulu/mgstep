/*
   CGRender.m

   Render a graphics path's Global Edge Table.

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

#include <AppKit/NSColor.h>


#define CTX				((CGContext *)cx)
#define GSTATE			CTX->_gs
#define COLOR_FILL		((CGColor *)GSTATE->fill.color)
#define COLOR_STROKE	((CGColor *)GSTATE->stroke.color)

#define floor_div(a,b)	(((a) < 0) ? ((a) - (b) + 1) / (b) : ((a) / (b)))


struct _PolygonEdge
{
	int x, y, h;									// coords and horz edge len
	int xdir, ydir;									// dir of movement 1 or -1
	int xinc;										// advancing X increment
	int e, adjup, adjdown;							// Bresenham’s error term
};													// & error term adjustments

static const int SUBXRES = 17;						// subpixel resolution
static const int SUBYRES = 15;

static iRect __emptyRect = { 0, 0, 0, 0 };



static iRect
iRectIntersection(iRect a, iRect b)
{
	iRect r;

	if (a.x0 > a.x1)								// infinite a
		return b;
	if (b.x0 > b.x1)								// infinite b
		return a;
	r.x0 = MAX(a.x0, b.x0);
	r.y0 = MAX(a.y0, b.y0);
	r.x1 = MIN(a.x1, b.x1);
	r.y1 = MIN(a.y1, b.y1);

	return (r.x1 < r.x0 || r.y1 < r.y0) ? __emptyRect : r;
}

static void
resetGET(gGET *get, iRect clip)
{
	if (clip.x0 > clip.x1)							// infinite clip
		{
		get->clip.x0 = get->clip.y0 = INT_MAX;
		get->clip.x1 = get->clip.y1 = INT_MIN;
		}
	else
		{
		get->clip.x0 = clip.x0 * SUBXRES;
		get->clip.x1 = clip.x1 * SUBXRES;
		get->clip.y0 = clip.y0 * SUBYRES;
		get->clip.y1 = clip.y1 * SUBYRES;
		}

	get->bbox.x0 = get->bbox.y0 = INT_MAX;
	get->bbox.x1 = get->bbox.y1 = INT_MIN;
	get->length = get->index = 0;
}

static iRect
boundsGET(gGET *get)
{
	iRect bbox;

	bbox.x0 = floor_div(get->bbox.x0, SUBXRES);
	bbox.y0 = floor_div(get->bbox.y0, SUBYRES);
	bbox.x1 = floor_div(get->bbox.x1, SUBXRES) + 1;
	bbox.y1 = floor_div(get->bbox.y1, SUBYRES) + 1;

	return bbox;
}

static gGET *
extendGET( gGET *get)
{
	NSUInteger capacity = get->size + 512;
	pEdge *edges = realloc(get->edges, sizeof(pEdge) * capacity);

	if (!edges)
		[NSException raise: NSMallocException format:@"malloc failed"];
	get->size = capacity;
	get->edges = edges;
	
	return get;
}

static gAET *
extendAET( gAET *aet)
{
	NSUInteger capacity = aet->size + 128;
	pEdge **edges = realloc(aet->edges, sizeof(pEdge *) * capacity);

	if (!edges)
		[NSException raise: NSMallocException format:@"malloc failed"];
	aet->edges = edges;
	aet->size = capacity;

	return aet;
}

void
_CGAddEdgeGET(gGET *get, float fx0, float fy0, float fx1, float fy1)
{
	pEdge *edge;
	int dx, dy;
	int winding;
	int width;
	int x0 = floor(fx0 * SUBXRES);
	int y0 = floor(fy0 * SUBYRES);
	int x1 = floor(fx1 * SUBXRES);
	int y1 = floor(fy1 * SUBYRES);
	int v0 = y0 < get->clip.y0;				// clip to Y min
	int v1 = y1 < get->clip.y0;

	if (v0 + v1 == 0)		{ }				// in
	else if (v0 + v1 == 2)	{ return; }		// out
	else if (v1)							// exit
		{
		x1 = x0 + (x1 - x0) * (get->clip.y0 - y0) / (y1 - y0);
		y1 = get->clip.y0;
		}
	else									// enter
		{
		x0 = x1 + (x0 - x1) * (get->clip.y0 - y1) / (y0 - y1);
		y0 = get->clip.y0;
		}

	v0 = y0 > get->clip.y1;					// clip to Y max
	v1 = y1 > get->clip.y1;

	if (v0 + v1 == 0)		{ }				// in
	else if (v0 + v1 == 2)	{ return; }		// out
	else if (v1)							// exit
		{
		x1 = x0 + (x1 - x0) * (get->clip.y1 - y0) / (y1 - y0);
		y1 = get->clip.y1;
		}
	else									// enter
		{
		x0 = x1 + (x0 - x1) * (get->clip.y1 - y1) / (y0 - y1);
		y0 = get->clip.y1;
		}

	if (y0 == y1)
		return;

	if (y0 > y1)
		{
		int swapX = x0;  x0 = x1;  x1 = swapX;
		int swapY = y0;  y0 = y1;  y1 = swapY;
		winding = -1;
		}
	else
		winding = 1;

	if (x0 < get->bbox.x0)  get->bbox.x0 = x0;
	if (x0 > get->bbox.x1)  get->bbox.x1 = x0;
	if (x1 < get->bbox.x0)  get->bbox.x0 = x1;
	if (x1 > get->bbox.x1)  get->bbox.x1 = x1;
	if (y0 < get->bbox.y0)  get->bbox.y0 = y0;
	if (y1 > get->bbox.y1)  get->bbox.y1 = y1;

	dy = y1 - y0;
	dx = x1 - x0;

	if (get->length + 1 >= get->size)
		extendGET( get);

	edge = &get->edges[get->length++];			// init new edge
	edge->xdir = dx > 0 ? 1 : -1;
	edge->ydir = winding;
	edge->x = x0;
	edge->y = y0;
	edge->h = dy;
	edge->adjdown = dy;
	edge->e = (dx >= 0) ? 0 : -dy + 1;

	width = dx < 0 ? -dx : dx;
	if (dy >= width)							// Y major edge
		{
		edge->xinc = 0;
		edge->adjup = width;
		}
	else										// X major
		{
		edge->xinc = (width / dy) * edge->xdir;
		edge->adjup = width % dy;
		}
}

static void
sortGET(gGET *get, int n)						// Shell sort (optimized Knuth)
{
	pEdge *a = get->edges;
	int i, j, h = 1;

 	if (n > 8)
		for (; h <= n/9; h = 3*h+1);

    for (; h > 0; h /= 3)
		for (i = h; i < n; i++)
			{
			pEdge e = a[i];

			for (j = i; j >= h && e.y < a[j-h].y; j -= h)
				a[j] = a[j-h];
			a[j] = e;
			}
}

static inline void
sortAET(pEdge **a, int n)						// Insertion sort
{
	int i, j;

    for (i = 1; i < n; i++)
		for (j = i; j > 0 && a[j]->x < a[j-1]->x; j--)
			{
			pEdge *e = a[j];

			a[j] = a[j-1];
			a[j-1] = e;
			}
}

static void
insertAET(gAET *aet, gGET *get, int y)
{
	while (get->index < get->length && get->edges[get->index].y == y)
		{
		if (aet->length + 1 >= aet->size)
			extendAET(aet);
		aet->edges[aet->length++] = &get->edges[get->index++];
		}

	sortAET(aet->edges, aet->length);			// sort edges by ascending X
}

static void
advanceAET(gAET *aet)							// Advances each edge in AET by
{												// one scan line, removes edges
	int i = 0;									// that have been fully scanned.

	while (i < aet->length)
		{
		pEdge *edge = aet->edges[i];

		if (--edge->h == 0)						// edge finished remove from AET
			aet->edges[i] = aet->edges[--aet->length];
		else
			{									// Advance edge's X coordinate
			edge->x += edge->xinc;				// by minimum move
			edge->e += edge->adjup;
			if (edge->e > 0)					// Determine if it's time for
				{								// X to advance one extra
				edge->x += edge->xdir;
				edge->e -= edge->adjdown;
				}
			i++;
			}
		}
}

static inline void
addSpan(unsigned char *spans, int x0, int x1)
{
	int px0 = x0 / SUBXRES;			// spans is an array of pixel coverage
	int sp0 = x0 % SUBXRES;			// values that turn the scanline drawing
	int px1 = x1 / SUBXRES;			// pen on and off at specific pixel offsets
	int sp1 = x1 % SUBXRES;

	if (px0 == px1)
		{
		spans[px0]   += sp1 - sp0;
		spans[px0+1] += sp0 - sp1;
		}
	else
		{
		spans[px0]   += SUBXRES - sp0;
		spans[px0+1] += sp0;
		spans[px1]   += sp1 - SUBXRES;
		spans[px1+1] += -sp1;
		}
}

static inline void
nonZeroWinding(gAET *aet, unsigned char *spans, int xoff)
{
	int winding = 0;
	int i, x = 0;

	for (i = 0; i < aet->length; i++)
		{
		if (winding)
			{
			if (!(winding + aet->edges[i]->ydir) && (x != aet->edges[i]->x))
				addSpan(spans, x - xoff, aet->edges[i]->x - xoff);
			}
		else if ((winding + aet->edges[i]->ydir))			// !winding
			x = aet->edges[i]->x;
		winding += aet->edges[i]->ydir;
		}
}

static inline void
evenOdd(gAET *aet, unsigned char *spans, int xoff)
{
	int even = 0;
	int i, x = 0;

	for (i = 0; i < aet->length; i++)
		{
		if (!even)
			x = aet->edges[i]->x;
		else if ((x != aet->edges[i]->x))					// even
			addSpan(spans, x - xoff, aet->edges[i]->x - xoff);
		even = !even;
		}
}

static inline void
Blend( CGContextRef cx, _CGInk *ink, int x, int y, u8 *src, int len, int clipx)
{
	CGImage *bmp = (CGImage *)CTX->_bitmap;
	UInt8 *dst = bmp->idata + ( y * bmp->width + x ) * bmp->samplesPerPixel;
	UInt8 cov = 0;

	if (ink->pattern)
		{
		CGImage *img = (CGImage *)((CGPattern *)ink->pattern)->bitmap;
		unsigned py = ((y - ink->yb) % (int)((CGPattern *)ink->pattern)->yStep);

		ink->length = img->width;
		ink->rgba = img->idata + py * img->bytesPerRow;
		}

	while (clipx--)
		{
		cov += *src;
		*src++ = 0;
		}

	src[len] = cov;

	CTX->_gs->pathBlend(src, ink, len, dst);
}

static void
_CGContextRenderGET( CGContextRef cx, iRect clip, bool fill)
{
	void (*fillRule) (gAET *, unsigned char *, int);
	gGET *get = (gGET *)CTX->_get;
	gAET *aet = (gAET *)CTX->_aet;
	int xmax = floor_div(get->bbox.x1, SUBXRES) + 1;
	int xmin = floor_div(get->bbox.x0, SUBXRES);
	int need = xmax - xmin + 1 + 4;
	int clen = clip.x1 - clip.x0;
	int clipx = clip.x0 - xmin;
	int xoff = xmin * SUBXRES;
	unsigned char sbuf[1024];
	unsigned char *spans;
	int y, yn, yc;
	_CGInk ink = {0,1,255, 0,0,0, GSTATE->mask};

	NSAssert(clip.x0 >= xmin || clip.x1 <= xmax, @"invalid horizontal clip");

	if (CTX->_f.draw == kCGPathEOFill || CTX->_f.draw == kCGPathEOFillStroke)
		fillRule = evenOdd;
	else
		fillRule = nonZeroWinding;

	spans = (need > sizeof(sbuf)) ? malloc(need) : sbuf;
	memset(spans, 0, need);

	ink.rgba = (fill) ? GSTATE->fill.rgba : GSTATE->stroke.rgba;
	if ((ink.color = (fill) ? COLOR_FILL : COLOR_STROKE))
		ink.pattern = ink.color->pattern;

	y = get->edges[0].y;
	yc = yn = ink.yb = floor_div(y, SUBYRES);

	while (aet->length > 0 || get->index < get->length)
		{
		if (yn != yc && yc >= clip.y0 && yc < clip.y1)
			Blend(cx, &ink, xmin + clipx, yc, spans, clen, clipx);

		insertAET(aet, get, y);

		yc = yn;
		if (yc >= clip.y0 && yc < clip.y1)
			fillRule(aet, spans, xoff);

		advanceAET(aet);

		if (aet->length > 0)
			y++;
		else if (get->index < get->length)
			y = get->edges[get->index].y;
		yn = floor_div(y, SUBYRES);				// subpixel to pixel
		}

	if (yc >= clip.y0 && yc < clip.y1)
		Blend(cx, &ink, xmin + clipx, yc, spans, clen, clipx);

	if (spans != sbuf)
		free(spans);

	_CGContextBitmapNeedsFlush(xmin, clip.y0, xmax, clip.y1);
}

void _clip_rect( CGContextRef cx, NSRect rect)
{
	GSTATE->clip = NSIntersectionRect(GSTATE->clip, rect);

	CTX->clip.x0 = GSTATE->clip.origin.x;
	CTX->clip.x1 = NSMaxX(GSTATE->clip);
	CTX->clip.y0 = GSTATE->clip.origin.y;
	CTX->clip.y1 = NSMaxY(GSTATE->clip);
}

void _clip_reset( CGContextRef cx)
{
	CGImage *a = (CGImage *)CTX->_bitmap;

	CTX->clip.x0 = 0;
	CTX->clip.x1 = a->width;
	CTX->clip.y0 = 0;
	CTX->clip.y1 = a->height;
	GSTATE->clip = (NSRect){0, 0, 65535, 65535};
}

void
_CGRenderPath(CGContextRef cx, CGPath *p, CGAffineTransform *m, bool fill)
{
	CGFloat determinant = sqrt(fabs(m->a * m->d - m->b * m->c));
	CGFloat flatness = MAX(.1, .3 / determinant);	// m vol scale constraint
	iRect gbox;
	iRect clip;

	resetGET(((gGET *)CTX->_get), CTX->clip);

	if (p->_count > 0 && p->_pe[0].type != kCGPathElementMoveToPoint)
		{
		NSLog(@"ERROR: CGPath must begin with moveto");
		return;
		}

	if (fill)										// scan path to GET
		_CGPathFill(p, CTX->_get, m, flatness);
	else
		{
		_CGRenderCTX r = {0};
		_CGPathDash d;

		if (GSTATE->_line.dash.count)
			{
			d.phase = GSTATE->_line.dash.phase;
			d.count = GSTATE->_line.dash.count;
			d.lengths = GSTATE->_line.dash.lengths;
			r.dash = &d;
			}

		r.linewidth = CTX->_gs->_line.width;
		if (r.linewidth * determinant < 0.1)
			r.linewidth = 1.0 / determinant;		// min line width
		r.linewidth *= 0.5;
		r.linecap    = CTX->_gs->_line.capStyle;
		r.linejoin   = CTX->_gs->_line.joinStyle;
		r.miterlimit = CTX->_gs->_line.miterLimit;
		r.get = CTX->_get;
		r.ctm = m;
		r.flatness = flatness;

		_CGPathStroke(p, &r);
		}

	sortGET(((gGET *)CTX->_get), ((gGET *)CTX->_get)->length);

	gbox = boundsGET(((gGET *)CTX->_get));
	clip = iRectIntersection(CTX->clip, gbox);

	if (clip.x0 != clip.x1 && ((gGET *)CTX->_get)->length > 0)
		_CGContextRenderGET(cx, clip, fill);		// get not empty
}

void
_CGContextReleaseRender(CGContextRef cx)
{
	if (CTX->_get)
		free(((gGET *)CTX->_get)->edges), free(CTX->_get), CTX->_get = NULL;
	if (CTX->_aet)
		free(((gAET *)CTX->_aet)->edges), free(CTX->_aet), CTX->_aet = NULL;
}

void
_CGContextSetWindowCanvas( CGContextRef cx, NSWindow *window )
{
	NSSize s = [window frame].size;
	int w = (int)s.width;
	int h = (int)s.height;

	if (!CTX->_bitmap)
		{
		gGET *get = calloc(1, sizeof(gGET));
		gAET *aet = calloc(1, sizeof(gAET));

		if (!get || !aet)
			[NSException raise: NSMallocException format:@"malloc failed"];
		CTX->_get = extendGET(get);
		CTX->_aet = extendAET(aet);
		CTX->clip.x1 = ((gGET *)CTX->_get)->bbox.x1 = w;
		CTX->clip.y1 = ((gGET *)CTX->_get)->bbox.y1 = h;
		CTX->_bitmap = (CGImage *)_CGContextCreateImage( cx, (CGSize){w,h} );
		}
	else
		CTX->_bitmap = (CGImage *)_CGContextResizeBitmap( cx, (CGSize){w,h});
}
