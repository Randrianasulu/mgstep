/*
   CGContext.m

   Graphics context

   Copyright (C) 2006-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
#include <CoreGraphics/Private/encoding.h>

#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>


#define CTX				((CGContext *)cx)
#define SURFACE			CTX->_bitmap
#define PATH			CTX->_path
#define PATH_COUNT		CTX->_path->_count
#define PATH_ORIGIN		CTX->_path->_p0
#define CTM				CTX->_gs->hasCTM
#define XCLIP			CTX->_gs->xClip
#define CLIP_RECT		CTX->_gs->clip
#define XCANVAS			CTX->_gs->xCanvas
#define ISFLIPPED		CTX->_gs->isFlipped
#define GSTATE			CTX->_gs
#define COLOR			CTX->_gs->stroke.color
#define COLOR_FILL		CTX->_gs->fill.color
#define CLAYER			CTX->_layer

#define CONTEXT			((CGContext *)cx)->_mg->_ctx
#define GS_ARRAY		((CGContext *)cx)->_mg->_gStateArray
#define GS_STACK_		((CGContext *)cx)->_mg->_gsStack
#define GS_INDEX		((CGContext *)cx)->_mg->_gsStackIndex

#define NO_FLIP_TO_X(a, b)  (NSHeight(b) - NSMinY(a) - NSMinY(b) - NSHeight(a))
#define	CONVERT_Y(a, b, f)	((f) ? NSMinY(a) + NSMinY(b) : NO_FLIP_TO_X(a, b))



void
CGContextSetLineWidth( CGContextRef cx, float width)
{
	GSTATE->_line.width = width;
}

void
CGContextSetLineCap( CGContextRef cx, CGLineCap style)
{
	GSTATE->_line.capStyle = style;
}

void
CGContextSetLineJoin( CGContextRef cx, CGLineJoin style)
{
	GSTATE->_line.joinStyle = style;
}

void
CGContextSetMiterLimit(CGContextRef cx, float limit)
{
	GSTATE->_line.miterLimit = limit;
}

void
CGContextSetFlatness(CGContextRef cx, float flatness)
{
	GSTATE->_line.flatness = flatness;
}

void
CGContextSetInterpolationQuality(CGContextRef cx, CGInterpolationQuality q)
{
	CTX->_gs->_interpolationQuality = q;	// set quality of interpolation
}		 									// performed when an image is scaled

CGInterpolationQuality
CGContextGetInterpolationQuality(CGContextRef cx)
{
	return CTX->_gs->_interpolationQuality;
}

void
CGContextSetAllowsAntialiasing (CGContextRef cx, bool allowsAntialiasing)
{
	CTX->_f.allowsAntialiasing = allowsAntialiasing;
}

void
CGContextSetShouldAntialias (CGContextRef cx, bool shouldAntialias)
{
	CTX->_f.shouldAntialias = (shouldAntialias && CTX->_f.allowsAntialiasing);
}

void
CGContextStrokeLineSegments(CGContextRef cx, const CGPoint pts[], size_t count)
{
	if (count >= 2 && pts != NULL  && cx != NULL)
		{
		CGContextAddLines(cx, pts, count);
		CGContextStrokePath (cx);
		}
}

void
CGContextStrokeRectWithWidth (CGContextRef cx, CGRect r, float width)
{
	NSRectEdge sides[] = { NSMaxXEdge, NSMinYEdge, NSMinXEdge, NSMaxYEdge };
	NSRect remainder = r;
	NSRect rects[4];
	int i;

	[COLOR setFill];							// sync stroke and fill colors
	for (i = 0; i < 4; i++)
		NSDivideRect(remainder, &rects[i], &remainder, width, sides[i]);
	for (i = 0; i < 4; i++)
		CGContextFillRect(cx, rects[i]);
}

void
CGContextStrokeRect (CGContextRef cx, CGRect r)
{
	CGContextStrokeRectWithWidth(cx, r, GSTATE->_line.width);
}

void
CGContextFillRects (CGContextRef cx, const CGRect rects[], size_t count)
{
	int i;

    for (i = 0; i < count; i++)
		CGContextFillRect(cx, rects[i]);
}

void
CGContextSetAlpha(CGContextRef cx, CGFloat alpha)
{
	GSTATE->stroke.alpha = (unsigned short)(65535 * alpha) >> 8;
	GSTATE->fill.alpha = (unsigned short)(65535 * alpha) >> 8;
	GSTATE->alpha = alpha;
}

void
CGContextSetRGBFillColor(CGContextRef cx, float r, float g, float b, float a)
{
	GSTATE->fill.red   = (unsigned short)(65535 * r) >> 8;
	GSTATE->fill.green = (unsigned short)(65535 * g) >> 8;
	GSTATE->fill.blue  = (unsigned short)(65535 * b) >> 8;
	GSTATE->fill.alpha = (unsigned short)(65535 * a) >> 8;
	GSTATE->fill.color = nil;
}

void
CGContextSetRGBStrokeColor(CGContextRef cx, float r, float g, float b, float a)
{
	GSTATE->stroke.red   = (unsigned short)(65535 * r) >> 8;
	GSTATE->stroke.green = (unsigned short)(65535 * g) >> 8;
	GSTATE->stroke.blue  = (unsigned short)(65535 * b) >> 8;
	GSTATE->stroke.alpha = (unsigned short)(65535 * a) >> 8;
	GSTATE->stroke.color = nil;
}

void
_CGContextSetHSBColor(CGContextRef cx, CGFloat h, CGFloat s, CGFloat b)
{
	struct RGB_Color rgb;
	struct HSB_Color hsb = {h, s, b};

	_CGColorConvertHSBtoRGB(hsb, &rgb);				// 0-255

	GSTATE->fill.red   = GSTATE->stroke.red   = rgb.red;
	GSTATE->fill.green = GSTATE->stroke.green = rgb.green;
	GSTATE->fill.blue  = GSTATE->stroke.blue  = rgb.blue;
	GSTATE->fill.color = GSTATE->stroke.color = nil;
}

void
CGContextSetGrayStrokeColor(CGContextRef cx, float gray, float a)
{
	GSTATE->stroke.red   = (unsigned short)(65535 * gray) >> 8;
	GSTATE->stroke.alpha = (unsigned short)(65535 * a) >> 8;
	GSTATE->stroke.green = GSTATE->stroke.blue = GSTATE->stroke.red;
	GSTATE->stroke.color = nil;
}

void
CGContextSetGrayFillColor(CGContextRef cx, float gray, float a)
{
	GSTATE->fill.red   = (unsigned short)(65535 * gray) >> 8;
	GSTATE->fill.alpha = (unsigned short)(65535 * a) >> 8;
	GSTATE->fill.green = GSTATE->fill.blue = GSTATE->fill.red;
	GSTATE->fill.color = nil;
}

void CGContextSetFillColorWithColor(CGContextRef cx, CGColorRef color)
{
	if (COLOR_FILL != (NSColor *)color)
		[(NSColor *)color setFill];
}

void CGContextSetStrokeColorWithColor(CGContextRef cx, CGColorRef color)
{
	if (COLOR != (NSColor *)color)
		[(NSColor *)color setStroke];
}

void CGContextSetTextDrawingMode(CGContextRef cx, CGTextDrawingMode mode)
{
	CTX->_f.drawText = mode;
}

void
CGContextSetShadowWithColor(CGContextRef cx,
							CGSize offset,
							CGFloat blur,
							CGColorRef color)
{
    CTX->_gs->_shadow.blur = blur;
    CTX->_gs->_shadow.offset = offset;
    CTX->_gs->_shadow.color = CGColorRetain(color);
}

void
CGContextSetShadow(CGContextRef cx, CGSize offset, CGFloat blur)
{
	CGContextSetShadowWithColor(cx, offset, blur, NULL);
}											// s/b RGBA = {0, 0, 0, 1.0/3.0})

void
CGContextSetLineDash( CGContextRef cx,
					  CGFloat phase,				// offset
					  const CGFloat lengths[],		// pattern
					  size_t count)
{
	if (count > 0)
		{
		GSTATE->_line.dash.lengths = realloc( GSTATE->_line.dash.lengths,
											  count * sizeof(CGFloat));
		memcpy(GSTATE->_line.dash.lengths, lengths, count * sizeof(CGFloat));
		}
	GSTATE->_line.dash.phase = phase;
	GSTATE->_line.dash.count = count;
}

/* ****************************************************************************

		CG BitmapContext

** ***************************************************************************/

CGContextRef
CGBitmapContextCreateWithData( void *data,				// bytesPerRow * height
							   size_t w,
							   size_t h,
							   size_t bitsPerComponent,
							   size_t bytesPerRow,
							   CGColorSpaceRef s,
							   CGBitmapInfo b,			// has alpha ...etc
							   CGBitmapContextReleaseDataCallback r,
							   void *info )
{
//	int bitsPerComponent = CGColorSpaceGetNumberOfComponents(s);
//	int samplesPerPixel = bitsPerPixel / bitsPerComponent;
	int samplesPerPixel = 32 / 8;		// FIX ME extract values from context
	int size = w * h * samplesPerPixel;
	CGContextRef cx = NULL;

//	bc = CFAllocatorAllocate(NULL, sizeof(_GCBitmapContext), 0);
//	bc->info = info;
	cx = (CGContextRef)[NSGraphicsContext graphicsContextWithBitmapImageRep:nil];

#ifdef FB_GRAPHICS
  ((CGContext *)cx)->_bitmap = CGImageCreate( w, h, 8, 24, 0, NULL, 0, NULL, NULL, 0, 0);
#else			// XR uses XImage
  ((CGContext *)cx)->_bitmap = _CGContextCreateImage(cx, (CGSize){w,h});
#endif

	return cx;
}

CGContextRef
_CGBitmapContextCreate( CGContextRef cx, CGSize z)
{
	int w = z.width;
	int h = z.height;
	CGContextRef gc;

	gc = CGBitmapContextCreateWithData( NULL, w, h, 8, 0, NULL,	0, NULL, NULL );
	((CGContext *)gc)->_gs->xCanvas = (NSRect){{0,0},z};
	((CGContext *)gc)->_gs->_ctm = ((CGContext *)cx)->_gs->_ctm;
	((CGContext *)gc)->_gs->hasCTM = ((CGContext *)cx)->_gs->hasCTM;

	return gc;
}

/* ****************************************************************************

	Graphics state

** ***************************************************************************/

void
CGContextSaveGState(CGContextRef cx)				// save graphics state
{
	_GState *gs;

	if (!(gs = GS_STACK_[GS_INDEX]))
		gs = GS_STACK_[GS_INDEX] = [_GState alloc];

	memcpy(gs, CTX->_gs, sizeof(_GState));

//	if (gs->context != CONTEXT)						// saving an unfocused ctx
//		NSLog (@"CGContextSaveGState: (gs->context != CONTEXT) **************");
	gs->current = (gs->context != CONTEXT) ? CONTEXT : nil;
	gs->stroke.color = [GSTATE->stroke.color retain];
	gs->fill.color   = [GSTATE->fill.color retain];
//	gs->font         = [GSTATE->font retain];

#ifdef CAIRO_GRAPHICS
	_cairo_save (cx);
#endif

	if ((++GS_INDEX) >= (GS_STACK_SIZE - 1))
		{
		GS_INDEX = (GS_STACK_SIZE - 1);
		NSLog(@" ************** caught graphics stack overflow\n");	 
		}
}

void
CGContextRestoreGState(CGContextRef cx)				// restore graphics state
{
	_GState *gs;

	if ((--GS_INDEX) < 0)
		{
		GS_INDEX = 0;
		NSLog(@" ************** caught graphics stack underflow\n");
		}

	gs = GS_STACK_[GS_INDEX];
	CONTEXT = (NSGraphicsContext *)gs->context;
	[gs->stroke.color release];
	[gs->fill.color release];
//	[gs->font release];

//	if (CTX->_gs->mask == YES)						// FIX ME reset clip mask

	memcpy(((CGContext *)CONTEXT)->_gs, gs, sizeof(_GState));

	_clip_rect(gs->context, gs->clip);				// restore raster clip
#ifdef CAIRO_GRAPHICS
	_cairo_restore (gs->context);
#endif

	if (gs->current)								// if current was != saved
		CONTEXT = gs->current;
}

NSInteger
_CGContextAllocGState(CGContextRef cx)
{
	_GState *gs = [_GState alloc];

	gs->context          = (NSGraphicsContext *)cx;
	gs->alpha            = 1.0;
	gs->dissolve         = 255;
	gs->blendMode        = kCGBlendModeNormal;		// NeXT SourceOver (0)
	gs->_line.flatness   = _CG_FLATNESS;
	gs->_line.joinStyle  = _CG_LINE_JOIN_STYLE;
	gs->_line.capStyle   = _CG_LINE_CAP_STYLE;
	gs->_line.width      = _CG_LINE_WIDTH;
	gs->_line.miterLimit = _CG_MITER_LIMIT;
	gs->clip = (NSRect){0, 0, 65535, 65535};

	[GS_ARRAY addObject: [gs autorelease]];

    return ((CGContext *)cx)->_mg->_uniqueGStateTag++;
}

_GState *
_CGContextGetGState(CGContextRef cx, NSInteger tag)
{
    return (_GState *)[GS_ARRAY objectAtIndex: tag];
}

void
_CGContextReleaseGState(CGContextRef cx, NSInteger tag)
{
	[GS_ARRAY replaceObjectAtIndex:tag withObject:_CGContextGetGState(cx, 0)];
}

void										// window backend resources retain
_CGContextRelease(CGContextRef cx)			// the context, call this to avoid
{											// a retain cycle FIX ME ugly
	_CGContextReleaseGState(cx, CTX->_gState), 	CTX->_gState = -1;
	_CGContextReleaseRender(cx);

#ifndef FB_GRAPHICS
	_x11_release_context(cx);
#endif

	CGImageRelease(SURFACE),		SURFACE = NULL;
	CGPathRelease(PATH),			PATH = NULL;
	CGLayerRelease(CLAYER), 		CLAYER = NULL;
	CGContextRelease(cx);
}

CGContextRef
CGContextRetain(CGContextRef cx)
{
	return (cx) ? (CGContextRef)CFRetain(cx) : cx;
}

void
CGContextRelease(CGContextRef cx)
{
	if (cx)
		CFRelease(cx);
}

/* ****************************************************************************

	Intersect current clipping path with clipping region formed by creating a
	path consisting of all rects in `rects'. Resets context path to empty.

** ***************************************************************************/

void
CGContextClipToRects(CGContextRef cx, const CGRect rects[], size_t count)
{
	const CGAffineTransform *m = (CTM) ? &GSTATE->_ctm : NULL;

	CGPathAddRects( PATH, m, rects, count);
	CGContextClip(cx);
}

void
CGContextClipToMask(CGContextRef cx, CGRect rect, CGImageRef mask)
{
	CGBlendMode mode = CTX->_gs->blendMode;

	CGContextSetBlendMode(cx, kCGBlendModeClear);
	_CGContextCompositeImage(cx, rect, mask);
	CTX->_gs->mask = YES;							// FIX ME mask reset
	CGContextSetBlendMode(cx, mode);
}

static void
_clip_path( CGContextRef cx)
{
	CGBlendMode mode = CTX->_gs->blendMode;

#ifdef CAIRO_GRAPHICS
	_cairo_clip(cx);
	return;
#endif

	if (!SURFACE || !PATH || !PATH_COUNT)
		return;

	CTX->_f.pathClip = YES;
	CGContextSetBlendMode(cx, kCGBlendModeClear);
	_CGContextScanPath(cx);
	_CGContextFillPath(cx);
	CTX->_gs->mask = YES;							// FIX ME mask reset
	CGContextSetBlendMode(cx, mode);
	CTX->_f.pathClip = NO;
}

void
CGContextClip(CGContextRef cx)
{
//	if (CTX->_gs->_clip)			// has clip must intersect with it
//		CLIP_RECT = NSIntersectionRect(CLIP_RECT, rect);

	CTX->_f.draw = kCGPathFill;
	_clip_path(cx);
}

void
CGContextEOClip(CGContextRef cx)
{
	CTX->_f.draw = kCGPathEOFill;
	_clip_path(cx);
}

NSRect
_CGGetClipRect(CGContextRef cx, NSRect rect)		// clip a device coords rect
{													// with gState's clip rect
#if 0
printf("######### FBRectClip clip %f %f %f %f\n",
		CLIP_RECT.origin.x, CLIP_RECT.origin.y,
		CLIP_RECT.size.width, CLIP_RECT.size.height);
printf("######### FBRectClip rect %f %f %f %f\n",
		rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
#endif
	if (NSIsEmptyRect(CLIP_RECT))
		return CLIP_RECT;

	if (!NSContainsRect(CLIP_RECT, rect))
		return NSIntersectionRect(CLIP_RECT, rect);

	return rect;
}

CGRect
CGContextGetClipBoundingBox(CGContextRef cx)
{
	return CLIP_RECT;
}

/* ****************************************************************************

	CGContextSelectFont

	Find font with name and set as CTX font.  If successful scale it to size.
	textEncoding determines the translation from bytes to glyphs.

** ***************************************************************************/

void
CGContextSelectFont(CGContextRef cx,
					const char *name,
					float fontSize,
					CGTextEncoding textEncoding)
{
	float fontMatrix[6] = { fontSize, 0, 0, fontSize, 0, 0 };
	NSString *n = [NSString stringWithCString: name];
	NSFont *font;

	if ((font = [NSFont fontWithName:n matrix:fontMatrix]))
		CGContextSetFont(cx, (CGFontRef)font);
}

void
CGContextSetFontSize(CGContextRef context, float size)
{
}		// Set the current font size in the context to size

void
CGContextShowText (CGContextRef cx, const char *bytes, size_t length)
{
	CGContextShowTextAtPoint(cx, PATH_ORIGIN.x, PATH_ORIGIN.y, bytes, length);
}

void
CGContextSetFont( CGContextRef cx, CGFontRef fnt)
{
	CGFont *font = (CGFont *)fnt;

	CTX->_gs->font = (NSFont*)font;						// set context GS font
	CTX->_gs->ascender = ((AXFontInt *)font->_ftFont)->ascent;
	CTX->_gs->descender = ((AXFontInt *)font->_ftFont)->descent;
}

void CGContextSetTextMatrix( CGContextRef cx, CGAffineTransform m)
{
	CTX->_ttm = m;
	if (CTX->_gs->font)
		CTX->_f.textMatrix = _CGFontSetMatrix(((CGFontRef)CTX->_gs->font), &m);
}

void CGContextSetTextPosition( CGContextRef cx, CGFloat x, CGFloat y)
{
	CTX->_pen = (CGPoint){x,y};
}

CGPoint CGContextGetTextPosition( CGContextRef cx)
{
	return CTX->_pen;
}

void
CGContextShowGlyphsAtPoint( CGContextRef cx,
							CGFloat x, CGFloat y,
							const CGGlyph glyphs[],
							size_t nglyphs )
{
	CGFont *nsfont = ((CGFont *)CTX->_gs->font);
	AXFontInt *font = (AXFontInt *) nsfont->_ftFont;
	unsigned int char_local[NUM_LOCAL];
	unsigned int *char32 = char_local;
//	NSPoint a = (NSPoint){x,y};
	NSRect rx = (NSRect){0,y,0,0};
	int i;
													// translate to X coord's
	CTX->_pen = (CGPoint){x, y};
//	if (CTM)
//		a = CGPointApplyAffineTransform(a, GSTATE->_ctm);

	y = CONVERT_Y(rx, XCANVAS, ISFLIPPED);			// convert to device coord
	x += XCANVAS.origin.x;

	_CGFontLoadGlyphs((CGFont *)nsfont, glyphs, nglyphs);

	if ((nglyphs * sizeof (unsigned int)) > sizeof (char_local))
		if (!(char32 = malloc (nglyphs * sizeof (unsigned int))))
			return;

	for (i = 0; i < nglyphs; i++)
		{
		unsigned int wire = (unsigned int) glyphs[i];

		if (wire >= font->num_glyphs || !font->glyphs[wire])
			wire = 0;
		char32[i] = (unsigned long) wire;
		}

	_CGContextDrawGlyphs(cx, char32, nglyphs, x, y);

	if (char32 != char_local)
		free (char32);
}

BOOL
CTFontGetGlyphsForCharacters( CGFontRef f,
							  const UniChar chars[],
							  CGGlyph glyphs[],
							  CFIndex count )
{
	BOOL hasAllGlyphs = YES;
	CFIndex i;								// FIX ME s/b in CoreText which is
											// not linked when use sys Freetype
	if (!count || !(_CGLockFace( f )))
		return NO;

	for (i = 0; i < count; i++)
		if ((glyphs[i] = _CGGlyphIndex( f, chars[i])) == 0)
			hasAllGlyphs = NO;

    return hasAllGlyphs;
}

/* ****************************************************************************

	CGContextShowTextAtPoint

	Display a string with length at point in the given context.

** ***************************************************************************/

void
CGContextShowTextAtPoint( CGContextRef cx,
						  CGFloat x, CGFloat y,
						  const char *bytes,
						  size_t length )
{
	FT_UInt glyphs_local[NUM_LOCAL];
	FT_UInt *glyphs = glyphs_local;
	CFRange r = {0,1};
	CFString st = {0};
	CFStringRef s = (CFStringRef)&st;
	UInt32 u4;
	unsigned char *p = (unsigned char *)&u4;
	int j, gc;

	if (!length || !(_CGLockFace( (CGFontRef)CTX->_gs->font)))
		return;

//	fprintf(stderr,"CGContextShowTextAtPoint %s\n", bytes);

	if (length > NUM_LOCAL && !(glyphs = malloc(length * sizeof(FT_UInt))))
		return;

	st._cString = (char *)bytes;
	st._count = length;
	for (gc = 0; r.location < length; gc++)
		{
		j = CFStringGetBytes(s, r, NSUTF32StringEncoding, '?', 0, p, 4, NULL);
		glyphs[gc] = _CGGlyphIndex( (CGFontRef)CTX->_gs->font, u4);
		r.location += (j > 0) ? j : 1;
		}

	CGContextShowGlyphsAtPoint(cx, x, y, glyphs, gc);

    if (glyphs != glyphs_local)
		free(glyphs);
}

void
CGContextFillRect( CGContextRef cx, CGRect rect)
{
	unsigned char color[4];
	int x, y, w, h;
	NSPoint org;
	NSRect c;

	if (CTM)
		rect = CGRectApplyAffineTransform( rect, GSTATE->_ctm);

	if (rect.size.width <= 0 || rect.size.height <= 0)
		return;

	org.y = CONVERT_Y(rect, XCANVAS, ISFLIPPED);
	org.x = rect.origin.x + XCANVAS.origin.x;

	if (CTX->_gs->_shadow.blur > 0)
		{
		NSPoint sp = (NSPoint){ (int)rect.origin.x + CTX->_gs->_shadow.offset.width,
								(int)rect.origin.y + CTX->_gs->_shadow.offset.height };

//    	CTX->_gs->_shadow.color = CGColorRetain(color);
		_CGContextDrawShadow(cx, (CGRect){sp, rect.size});
		}

//printf("######### CGContextFillRect %f %f %f %f \n", org.x, org.y, rect.size.width, rect.size.height);

	c = _CGGetClipRect(cx, (NSRect){org, rect.size});
	_CGContextRectNeedsFlush(cx, c);

#ifdef CAIRO_GRAPHICS
	if (COLOR)
		_cairo_fill_rect(cx, (NSRect){org, rect.size});
	return;
#endif

	x = (int)c.origin.x;
	w = (int)NSMaxX(c);
	h = (int)NSMaxY(c);

	color[3] = GSTATE->fill.alpha;
	color[2] = GSTATE->fill.red;
	color[1] = GSTATE->fill.green;
	color[0] = GSTATE->fill.blue;

	if (GSTATE->fill.c && GSTATE->fill.c->_f.pattern)
		{
		CGPatternRef p = GSTATE->fill.c->pattern;
		NSRect r = ((CGPattern *)p)->bounds;

		r.origin = rect.origin;
		r.origin.x += ((int)c.size.width / 2 % (int)((CGPattern *)p)->xStep);
		r.origin.y += ((int)c.size.height / 2 % (int)((CGPattern *)p)->yStep);

		for (y = (int)c.origin.y; y < h; y += ((CGPattern *)p)->yStep)
			{
			for (x = (int)c.origin.x; x < w; x += ((CGPattern *)p)->xStep, r.origin.x += ((CGPattern *)p)->xStep)
				_CGContextCompositeImage(cx, r, ((CGPattern *)p)->bitmap);
			r.origin.x = rect.origin.x + ((int)c.size.width / 2 % (int)((CGPattern *)p)->xStep);
			r.origin.y += ((CGPattern *)p)->yStep;
			}
		return;
		}

	for (y = (int)c.origin.y; y < h; y++)
		CTX->_gs->colorBlend(color, NULL, w-x, _CGRasterLine(cx, x, y, w));
	_CGContextFlushBitmap(cx, (int)c.origin.x, (int)c.origin.y, w, h);
}

/* ****************************************************************************

	CGContextDrawImage() -- Draw and if necessary scale image to rect
	
	Requires bitmap background layer to draw onto.  Assumes there is a focused
	bitmap image rep if called without setting a background layer.

	** Draws (flushes) to X Drawable only if context is a Window or a Layer.

** ***************************************************************************/

void CGContextDrawImage(CGContextRef cx, CGRect rect, CGImageRef img)
{
	unsigned int w = (unsigned int)NSWidth(rect);
	unsigned int h = (unsigned int)NSHeight(rect);
	CGImage *a = (CGImage *)img;
	CGImageRef n = NULL;

	if (CTX->_gs->alpha != 1.0)
		CTX->_gs->dissolve = 255 * CTX->_gs->alpha;

	if (a->width != w || a->height != h)
		{
		if (a->cimage && a->cimage->width == w && a->cimage->height == h)
			a = (CGImage *)a->cimage;					// cache matches size
		else
			{
			if (CTX->_gs->_interpolationQuality < kCGInterpolationHigh)
				n = _CGScaleImage(a, w, h);
			else
				n = _CGZoomFilter(a, w, h);
			a = (CGImage *)n;
		}	}

	_CGContextCompositeImage(cx, rect, a);

	if (n)
		{
		CGImageRelease(((CGImage *)img)->cimage);		// release prev cache
		((CGImage *)img)->cimage = NULL;
		if (((CGImage *)img)->_f.cache)
			((CGImage *)img)->cimage = n;				// cache scaled image
		else
			CGImageRelease(n);							// free scaling memory
		}
}
