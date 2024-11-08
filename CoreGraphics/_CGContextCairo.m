/*
   _CGContextCairo.m

   Cairo graphics interface

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>

#ifdef CAIRO_GRAPHICS
  #include <cairo/cairo.h>
  #include <cairo/cairo-xlib.h>
#endif


#define CTX				((CGContext *)cx)
#define CXCAIRO	 		CTX->_cairoContext
#define SURFACE			CTX->_surface
#define XPIXMAP			CTX->xPixmap
#define XSCREEN			CTX->_display->_xScreen
#define XDISPLAY		CTX->_display->xDisplay
#define PATH			CTX->_path
#define PATH_COUNT		CTX->_path->_count
#define PATH_ORIGIN		CTX->_path->_p0
#define PATH_E			CTX->_path->_pe
#define GSTATE			CTX->_gs



#ifndef FB_GRAPHICS

#ifdef  CAIRO_GRAPHICS  /* ************************************************* */

void _cairo_set_surface_for_window( CGContextRef cx, NSWindow *window )
{
	NSSize s = [window frame].size;
	int w = (int)s.width;
	int h = (int)s.height;

	if (!SURFACE)
		{
		Visual *visual = XDefaultVisual(XDISPLAY, XSCREEN);

		SURFACE = cairo_xlib_surface_create (XDISPLAY, XPIXMAP, visual, w, h);
		CXCAIRO = cairo_create(SURFACE);
		}
	else
		cairo_xlib_surface_set_drawable (SURFACE, XPIXMAP, w, h);
}

void
_cairo_release(CGContextRef cx)
{
	if (CXCAIRO)
		cairo_destroy (CXCAIRO),	CXCAIRO = NULL;
}

void _set_cairo_operator(CGContextRef cx, CGBlendMode mode)
{
	switch (mode)
		{
		case kCGBlendModeXOR:
			cairo_set_operator(CXCAIRO, CAIRO_OPERATOR_XOR);			break;
		case kCGBlendModeClear:
			cairo_set_operator(CXCAIRO, CAIRO_OPERATOR_CLEAR);			break;
		default:
			cairo_set_operator(CXCAIRO, CAIRO_OPERATOR_OVER);			break;
		}
}

void
cairo_rounded_rect(cairo_t *cr, double x, double y, double width, double height)
{
    double aspect = 1.0;     /* aspect ratio */
//    double corner_radius = height / 10.0;   /* and corner curvature radius */
    double corner_radius = 1.0;   /* and corner curvature radius */

	double radius = corner_radius / aspect;
	double degrees = M_PI / 180.0;

	cairo_new_sub_path (cr);
	cairo_arc (cr, x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
	cairo_arc (cr, x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
	cairo_arc (cr, x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
	cairo_arc (cr, x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
	cairo_close_path (cr);

//	cairo_set_source_rgb (cr, 0.5, 0.5, 1);
	cairo_fill_preserve (cr);
//	cairo_set_source_rgba (cr, 0.5, 0, 0, 0.5);
	cairo_set_line_width (cr, 2.0);
	cairo_stroke (cr);
}

void
_cairo_fill_rect( CGContextRef cx, NSRect r)
{
	if (!CXCAIRO)
		return;
//  cairo_set_source_rgb(CXCAIRO, 0.6, 0.0, 0.0);
//  cairo_set_line_width(cr, 1);
//	cairo_rounded_rect(CXCAIRO, r.origin.x, r.origin.y, r.size.width, r.size.height);
	cairo_rectangle(CXCAIRO, r.origin.x, r.origin.y, r.size.width, r.size.height);
	cairo_fill(CXCAIRO);
}

void
_cairo_fill_path( CGContextRef cx)
{
	if (!CXCAIRO)
		return;

    cairo_save(CXCAIRO);

	if (GSTATE->hasCTM)
		{
		cairo_matrix_t m;

		memcpy(&m, &GSTATE->_ctm, sizeof(CGAffineTransform));
		cairo_set_matrix(CXCAIRO, &m);
		}

//	cairo_set_source_rgb (CXCAIRO, CTX->_gs->red/255, CTX->_gs->green/255, CTX->_gs->blue/255);
//	cairo_set_source_rgb (cr, 0.5, 0.5, 1);
//	cairo_set_source_rgba (CXCAIRO, 0.5, 0, 0, 0.5);

	if (CTX->_f.draw == kCGPathEOFill || CTX->_f.draw == kCGPathEOFillStroke)
		cairo_set_fill_rule(CXCAIRO, CAIRO_FILL_RULE_EVEN_ODD);
	else
		cairo_set_fill_rule(CXCAIRO, CAIRO_FILL_RULE_WINDING);

	if (CTX->_f.draw == kCGPathFillStroke || CTX->_f.draw == kCGPathEOFillStroke)
		cairo_fill_preserve (CXCAIRO);
	else
		cairo_fill(CXCAIRO);

    cairo_restore(CXCAIRO);
}

void
_cairo_clip_rect( CGContextRef cx, NSRect rect)
{
	XRectangle xRect;

	if (!CXCAIRO)
		return;

	xRect.x = rect.origin.x;
	xRect.y = rect.origin.y;
	xRect.width = rect.size.width;
	xRect.height = rect.size.height;

	cairo_new_path (CXCAIRO);
	cairo_move_to (CXCAIRO, xRect.x, xRect.y);
	cairo_rel_line_to (CXCAIRO, xRect.width, 0);
	cairo_rel_line_to (CXCAIRO, 0, xRect.height);
	cairo_rel_line_to (CXCAIRO, -xRect.width, 0);
	cairo_close_path (CXCAIRO);
//	cairo_rectangle(CXCAIRO, xRect.x, xRect.y, xRect.width, xRect.height);
	cairo_clip(CXCAIRO);
}

void
_cairo_clip( CGContextRef cx)
{
	int i;

	if (!CXCAIRO || !PATH || !PATH_COUNT)
		return;

	cairo_new_path (CXCAIRO);
	cairo_move_to (CXCAIRO, PATH_E[0].p1.x, PATH_E[0].p1.y);
	for (i = 1; i < PATH_COUNT; i++)
		cairo_line_to (CXCAIRO, PATH_E[i].p1.x, PATH_E[i].p1.y);

	if (CTX->_f.draw == kCGPathEOFill)
		cairo_set_fill_rule(CXCAIRO, CAIRO_FILL_RULE_EVEN_ODD);
	else
	    cairo_set_fill_rule(CXCAIRO, CAIRO_FILL_RULE_WINDING);

	cairo_clip(CXCAIRO);
}

void
_cairo_reset_clip (CGContextRef cx)
{
	if (CXCAIRO)
		cairo_reset_clip(CXCAIRO);
}

void
_cairo_set_line_dash( CGContextRef cx,
					  CGFloat offset,
					  const CGFloat pattern[],
					  size_t size)
{
	double dpat[size];
	int i;
	
	for (i = 0; i < size; i++)
		dpat[i] = pattern[i];
	cairo_set_dash (CXCAIRO, dpat, size, offset);
}

void
_cairo_stroke_line (CGContextRef cx, NSPoint start, NSPoint end)
{
	cairo_move_to (CXCAIRO, start.x, start.y);
	cairo_line_to (CXCAIRO, end.x, end.y);
	cairo_stroke (CXCAIRO);
}

void
_cairo_stroke_point (CGContextRef cx, CGFloat x, CGFloat y)
{
	cairo_move_to (CXCAIRO, x, y);
	cairo_line_to (CXCAIRO, x+1, y+1);
//	cairo_set_line_width (CXCAIRO, 1);
	cairo_stroke (CXCAIRO);
}

void
_cairo_quadratic_curve_to (CGContextRef cx,
						   double x1, double y1,  // CGFloat cp_x, CGFloat cp_y
						   double x2, double y2)  // CGFloat x, CGFloat y
{
	double x0 = ((CGContext *)cx)->_path->_p0.x;	// elevate degree of Bezier
	double y0 = ((CGContext *)cx)->_path->_p0.y;	// curve, quad to cubic
	double cp1_x = 2.0 / 3.0 * x1 + 1.0 / 3.0 * x0;
	double cp1_y = 2.0 / 3.0 * y1 + 1.0 / 3.0 * y0;
	double cp2_x = 2.0 / 3.0 * x1 + 1.0 / 3.0 * x2;
	double cp2_y = 2.0 / 3.0 * y1 + 1.0 / 3.0 * y2;

	cairo_curve_to (CXCAIRO, cp1_x, cp1_y, cp2_x, cp2_y, x2, y2);
}

void
_cairo_set_color (CGContextRef cx, unsigned red, unsigned green, unsigned blue)
{
	if (CXCAIRO)
		{
		float r = (float)red / (float)65535;
		float g = (float)green / (float)65535;
		float b = (float)blue / (float)65535;

		cairo_set_source_rgb(CXCAIRO, r, g, b);
		}
}

void
_cairo_save (CGContextRef cx)
{
	if (CXCAIRO)
		cairo_save (CXCAIRO);
}

void
_cairo_restore (CGContextRef cx)
{
	if (CXCAIRO)
		cairo_restore (CXCAIRO);
}

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

		cairo_new_path (CXCAIRO);

		for (i = 0; i < PATH->_count; i++)
			{
			switch (PATH_E[i].type)
				{
				case kCGPathElementMoveToPoint:
					{
					rect.origin = PATH_E[i].p1;
					cairo_move_to (CXCAIRO, rect.origin.x, rect.origin.y);
					o = PATH_ORIGIN = rect.origin;
					break;
					}

				case kCGPathElementAddLineToPoint:
				case kCGPathElementCloseSubpath:
					{
					rect.origin = PATH_E[i].p1;
					cairo_line_to (CXCAIRO, rect.origin.x, rect.origin.y);
					o = PATH_ORIGIN = rect.origin;
					break;
					}

				case kCGPathElementAddQuadCurveToPoint:
					{
					NSPoint cp = PATH_E[i].p1;
					NSPoint e = PATH_E[i].p2;

					_cairo_quadratic_curve_to (cx, cp.x, cp.y, e.x, e.y);
					o = rect.origin = PATH_ORIGIN = e;
					break;
					}

				case kCGPathElementAddCurveToPoint:
					{
					NSPoint cp1 = PATH_E[i].p1;
					NSPoint cp2 = PATH_E[i].p2;
					NSPoint e = PATH_E[i].p3;

					cairo_curve_to(CXCAIRO, cp1.x, cp1.y, cp2.x, cp2.y, e.x, e.y);
					o = rect.origin = PATH_ORIGIN = e;
					break;
					}
				}

			xFlushRect = NSUnionRect(xFlushRect, rect);
			}

		_CGContextRectNeedsFlush(cx, xFlushRect);
		}
}

void
_CGContextStrokePath (CGContextRef cx)
{
	if (GSTATE->_line.width == 0)
		GSTATE->_line.width = 1.0;			// FIX ME is this really needed ?
	cairo_set_line_width(CXCAIRO, GSTATE->_line.width);
	_cairo_set_line_dash(cx, GSTATE->_line.dash.phase,
							 GSTATE->_line.dash.lengths,
							 GSTATE->_line.dash.count);
	cairo_set_line_cap (CXCAIRO, GSTATE->_line.capStyle);
	cairo_set_line_join (CXCAIRO, GSTATE->_line.joinStyle);
	_set_cairo_operator(cx, GSTATE->blendMode);
	cairo_stroke(CXCAIRO);
}

void
_CGContextFillPath( CGContextRef cx)
{
	_cairo_fill_path(cx);
}

#endif  /* CAIRO_GRAPHICS */

#endif  /* !FB_GRAPHICS   */
