/*
   CGPostscript.m

   Postscript single operator functions

   Copyright (C) 2010-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    March 2010

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>


#define CONTEXT			(_CGContext())
#define CTX				((CGContextRef)ctxt)
#define GSTATE			((CGContext *)ctxt)->_gs
#define XCANVAS			((CGContext *)cx)->_gs->xCanvas
#define DRAW_ORIGIN		((CGContext *)cx)->_path->_p0



void DPSinitclip(DPSContext ctxt)			// reset clip path to device canvas
{
	NSRect r = (NSRect){{0,0}, ((CGContext *)ctxt)->_gs->xCanvas.size};

	_CGContextSetClipRect( CTX, r);
}

void DPSmoveto(DPSContext ctxt, float x, float y)
{ 
	CGContextMoveToPoint( CTX, x, y);
}

void DPSlineto(DPSContext ctxt, float x, float y)
{ 
	CGContextAddLineToPoint( CTX, x, y);
}

void DPSshow(DPSContext ctxt, const char *str)
{
	CGContextShowText( CTX, str, (int)strlen(str));
}

void DPSsetgray(DPSContext ctxt, float g)
{
	CGContextSetGrayFillColor( CTX, g, 1.0);
	CGContextSetGrayStrokeColor( CTX, g, 1.0);
}

void DPSsethsbcolor(DPSContext ctxt, float h, float s, float b)
{
	if (b == 0)
		DPSsetgray(ctxt, 0.0);
	else
		_CGContextSetHSBColor( CTX, h, s, b);
}

void DPSrectfill(DPSContext ctxt, float x, float y, float w, float h)
{
	CGContextFillRect( CTX, (CGRect){x, y, w, h});
}

void DPSrectstroke(DPSContext ctxt, float x, float y, float w, float h)
{
	CGContextStrokeRectWithWidth( CTX, (CGRect){x, y, w, h}, 1.0);
}

void DPScompositerect(DPSContext cx, float x, float y, float w, float h, int op)
{
	CGContextSetBlendMode( (CGContextRef)cx, (CGBlendMode)op);
	CGContextFillRect( (CGContextRef)cx, (CGRect){x, y, w, h});
}

void PSshow(const char *str)
{
	CGContextShowText(CONTEXT, str, strlen(str));
}

void
PSrlineto(float x, float y)   							// Draw line relative   
{														// to the current point
	CGContextRef cx = CONTEXT;

    PSlineto(DRAW_ORIGIN.x + x, DRAW_ORIGIN.y + y);
}

void PSmoveto(float x, float y)		{ CGContextMoveToPoint(CONTEXT, x, y); }
void PSlineto(float x, float y)		{ CGContextAddLineToPoint(CONTEXT, x, y); }
void PSnewpath(void)				{ CGContextBeginPath(CONTEXT); }
void PSclosepath(void)				{ CGContextClosePath(CONTEXT); }
void PSgsave(void)					{ CGContextSaveGState(CONTEXT); }
void PSgrestore(void)				{ CGContextRestoreGState(CONTEXT); }
void PSclip(void)					{ CGContextClip(CONTEXT); }
void PSeoclip(void)					{ CGContextEOClip(CONTEXT); }
void PSsetmiterlimit(float limit)	{ CGContextSetMiterLimit(CONTEXT, limit); }
void PSsetflat(float flatness)		{ CGContextSetFlatness(CONTEXT,flatness); }
void PSsetgray(float g)				{ DPSsetgray((DPSContext)CONTEXT, g); }
void PSsetlinewidth(float width)	{ CGContextSetLineWidth(CONTEXT, width); }
void PSeofill(void)					{ CGContextEOFillPath(CONTEXT); }
void PSfill(void)					{ CGContextFillPath(CONTEXT); }
void PSstroke(void)					{ CGContextStrokePath(CONTEXT); }
void PSsetlinejoin(int style)		{ CGContextSetLineJoin(CONTEXT, style); }
void PSsetlinecap(int lineCap)		{ CGContextSetLineCap(CONTEXT, lineCap); }
void PSinitclip(void)				{ DPSinitclip((DPSContext)CONTEXT); }

void PScurveto(float x1, float y1, float x2, float y2, float x3, float y3)
{
	CGContextAddCurveToPoint(CONTEXT, x1, y1, x2, y2, x3, y3);
}

void PStranslate(float x, float y)   		// translate Xcanvas origin
{
	CGContextRef cx = CONTEXT;

    XCANVAS.origin = (NSPoint){NSMinX(XCANVAS) + x, NSMinY(XCANVAS) + y};
}

void PSrectclip(float a, float b, float c, float d)
{
	CGContextClipToRect(CONTEXT, (NSRect){a, b, c, d});			
}

void PSsetdash(CGFloat pattern[], int size, CGFloat offset)
{
	CGContextSetLineDash(CONTEXT, offset, pattern, size);
}

/* ****************************************************************************

	PScomposite

	Composite src Rect of srcGS's CTX to dest Point in focused view's CTX.

** ***************************************************************************/

void PScomposite(float sx, float sy, float w, float h, int srcGS,
				 float dst_x, float dst_y, int op)
{
	DPScomposite((DPSContext)CONTEXT, sx, sy, w, h, srcGS, dst_x, dst_y, op);
}

void DPScomposite(DPSContext ctxt, float sx, float sy, float w, float h,
					int srcGS, float dx, float dy, int op)
{
	if (w > 0 && h > 0)
		{
		_GState *g = srcGS ? _CGContextGetGState(CTX, srcGS) : GSTATE;
		CGImageRef img = ((CGContext *)g->context)->_bitmap;

		CGContextSaveGState(CTX);
		CGContextSetAlpha(CTX, 1.0);
		CGContextSetBlendMode(CTX, (CGBlendMode)op);

		if (sx > 0 || sy > 0)
			img = CGImageCreateWithImageInRect(img, (NSRect){{sx,sy},{w,h}});
		CGContextDrawImage(CTX, (NSRect){{dx,dy},{w,h}}, img);
		if (img != ((CGContext *)g->context)->_bitmap)
			CGImageRelease(img);
		CGContextRestoreGState(CTX);
		}
	else
		NSLog(@"DPScomposite: *** invalid size ***");
}

void PSdissolve(float sx, float sy, float w, float h, int srcGS,
				 float dst_x, float dst_y, float delta)
{
	DPSdissolve((DPSContext)CONTEXT, sx, sy, w, h, srcGS, dst_x, dst_y, delta);
}

void DPSdissolve(DPSContext ctxt, float sx, float sy, float w, float h,
					int srcGS, float dx, float dy, float delta)
{
	if (w > 0 && h > 0)
		{
		_GState *g = srcGS ? _CGContextGetGState(CTX, srcGS) : GSTATE;
		CGImageRef img = ((CGContext *)g->context)->_bitmap;

		CGContextSaveGState(CTX);
		CGContextSetAlpha(CTX, delta);
		CGContextSetBlendMode(CTX, kCGBlendModeNormal);

		g->dissolve = (255 * MAX(0.0, MIN(1.0, delta)));	// FIX ME needed ?

		if (sx > 0 || sy > 0)
			img = CGImageCreateWithImageInRect(img, (NSRect){{sx,sy},{w,h}});
		CGContextDrawImage(CTX, (NSRect){{dx,dy},{w,h}}, img);
		if (img != ((CGContext *)g->context)->_bitmap)
			CGImageRelease(img);
		CGContextRestoreGState(CTX);
		}
	else
		NSLog(@"DPSdissolve: *** invalid size ***");
}
