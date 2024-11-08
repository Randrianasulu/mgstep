/*
   CGContextRaster.m

   Device raster and low level graphics functions

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
												// convert Y coord to device
												// space per flipped state
#define NO_FLIP_TO_X(a, b)  (NSHeight(b) - NSMinY(a) - NSMinY(b) - NSHeight(a))
#define	CONVERT_Y(a, b, f)	((f) ? NSMinY(a) + NSMinY(b) : NO_FLIP_TO_X(a, b))

#define CTX			((CGContext *)cx)
#define ISFLIPPED	CTX->_gs->isFlipped
#define XCANVAS		CTX->_gs->xCanvas
#define GSTATE		CTX->_gs
#define CLIP_RECT	CTX->_gs->clip
#define XCLIP		CTX->_gs->xClip
#define CLAYER		CTX->_layer

#define GBASE		CTX->_bitmap->idata
#define GLINELEN	CTX->_bitmap->bytesPerRow
#define GSIZE		CTX->_bitmap->size
#define GBYTES_PX	CTX->_bitmap->samplesPerPixel
#define GXOFF		(int)CTX->_layer->_origin.x
#define GYOFF		(int)CTX->_layer->_origin.y


extern void mov_3x3up(unsigned char *src, int len, unsigned char *dst);
extern void mov_3x3dn(unsigned char *src, int len, unsigned char *dst);



unsigned char *
_CGRasterLine( CGContextRef cx, unsigned x, unsigned y, unsigned w)
{
	long location = (x+GXOFF) * GBYTES_PX + (y+GYOFF) * GLINELEN;
//	long end = location + w * GBYTES_PX;

	if (location >= GSIZE || y+GYOFF < 0)
		{
		_CGOutOfBoundsAccess(__FUNCTION__, CLAYER, x, y, location);
		printf("CG location: (%ld)  canvas size %d\n", location, GSIZE);

		return NULL;
		}
	
	return (GBASE + location);			// FIX ME validate scan line BBox
}

static void
_CGWritePixel(CGContextRef cx, int x, int y, union _CGColorState *cl)
{
	unsigned char color[4] = {cl->blue, cl->green, cl->red, cl->alpha};
//	CGPathRef p = CTX->_gs->_clip;

	if (!NSPointInRect((NSPoint){x,y}, CLIP_RECT))		// apply clip
		return;
//	if (p && !CGPathContainsPoint(p, NULL, (CGPoint){x,y}, CTX->_f.eoClip))
//		return;

	CTX->_gs->colorBlend(color, NULL, 1, _CGRasterLine(cx, x, y, 1));
}

static inline unsigned char *
_CGImageLine( CGImage *a, unsigned x, unsigned y)
{
	long location = (x * a->samplesPerPixel) + (y * a->bytesPerRow);

	return (a->idata + location);
}

BOOL
_CGImageRect( CGImage *a, NSRect r)
{
	long x = (long)r.origin.x;
	long y = (long)r.origin.y;
	long location = (x * a->samplesPerPixel) + (y * a->bytesPerRow);
	long end = location + r.size.height * r.size.width * a->samplesPerPixel;

	return (x < 0 || y < 0 || end > a->size) ? NO : YES;
}

void
_CGContextCopyRect( CGContextRef srcGC, NSRect src, NSPoint dest)
{
	CGContextRef cx = (CGContextRef)((CGContext *)srcGC)->_mg->_ctx;
	int j, y, mx, my;
	CGImage *a = (CGImage *)((CGContext *)srcGC)->_bitmap;			// src
	CGImage *ds = (CGImage *)((CGContext *)cx)->_bitmap;			// dst

	NSRect c = _CGGetClipRect(cx, (NSRect){dest,src.size});

	src.size = c.size;
	dest = c.origin;						// clip destination rect

	if (!a->bytesPerRow || !a->samplesPerPixel || !_CGImageRect( a, src))
		NSLog(@"_CGContextCopyRect invalid src image rect ***");
	if (!ds->bytesPerRow || !ds->samplesPerPixel || !_CGImageRect( ds, c))
		NSLog(@"_CGContextCopyRect invalid dest image rect ***");

#ifndef FB_GRAPHICS
	XRContextCopyRect(srcGC, src, dest);				// same mov on Pixmap
#endif

	j = (int)src.origin.y;
	mx = (int)dest.x + (int)src.size.width;
	my = (int)dest.y + (int)src.size.height;
	y = (int)dest.y;

	if (dest.x < src.origin.x)
		{
		int i = (int)src.origin.x;
		int x = (int)dest.x;

		if (dest.y < src.origin.y)
			for (j = (int)src.origin.y, y = (int)dest.y; y < my; j++, y++)
				mov_3x3up(_CGImageLine(a, i, j), mx-x, _CGImageLine(ds, x, y));
		else
			for (j = (int)NSMaxY(src)-1, y = my-1; y >= (int)dest.y; j--, y--)
				mov_3x3up(_CGImageLine(a, i, j), mx-x, _CGImageLine(ds, x, y));
		}
	else
		{
		int i = (int)NSMaxX(src)-1;
		int x = mx-1;
		int w = x-(int)dest.x+1;

		if (dest.y < src.origin.y)
			for (j = (int)src.origin.y, y = (int)dest.y; y < my; j++, y++)
				mov_3x3dn(_CGImageLine(a, i, j), w, _CGImageLine(ds, x, y));
		else
			for (j = (int)NSMaxY(src)-1, y = my-1; y >= (int)dest.y; j--, y--)
				mov_3x3dn(_CGImageLine(a, i, j), w, _CGImageLine(ds, x, y));
		}
}

/* ****************************************************************************

	gState bitmap copying

** ***************************************************************************/

void
NSCopyBits(int srcGS, NSRect src, NSPoint dest)
{
	CGContextRef cx = _CGContext();
	_GState *gs = _CGContextGetGState(cx, srcGS);
	NSRect r = {dest, src.size};

	src.origin.y = CONVERT_Y(src, gs->xCanvas, gs->isFlipped);
	src.origin.x += gs->xCanvas.origin.x;

	dest.y = CONVERT_Y(r, XCANVAS, ISFLIPPED);
	dest.x += XCANVAS.origin.x;

	_CGContextRectNeedsFlush(cx, (CGRect){dest, src.size});
	_CGContextCopyRect((CGContextRef)gs->context, src, dest);
}

void
NSCopyBitmapFromGState(int srcGS, NSRect src, NSRect destRect)
{
	if (NSEqualSizes(src.size, destRect.size))
		NSCopyBits(srcGS, src, destRect.origin);
//	else
//		must scale bitmap
}

void
_CGContextCompositeImage( CGContextRef cx, NSRect rect, CGImageRef img)
{
	int x, y, width, height, xd, yd;
	CGImage *ds = (CGImage *)((CGContext *)cx)->_bitmap;
	CGImage *a = (CGImage *)img;
	NSPoint org;
	NSRect c;
	_CGInk ink = {0, a->samplesPerPixel, GSTATE->dissolve, 0,0,0, GSTATE->mask};

	if (!ds)
		ds = (CGImage *)((CGContext *)((CGLayer *)((CGContext *)cx)->_layer)->context)->_bitmap;

	rect = NSIntegralRect(rect);		// WARNING: expands size 11.00001 to 12
	org.y = CONVERT_Y(rect, XCANVAS, ISFLIPPED);
	org.x = NSMinX(rect) + NSMinX(XCANVAS);

	c = _CGGetClipRect(cx, (NSRect){org, rect.size});

	if (NSWidth(c) <= 0 || NSHeight(c) <= 0)
		return;										// rect is not visible

	x = (int)c.origin.x - org.x;
	y = (int)c.origin.y - org.y;
	org = c.origin;
	rect.size = c.size;

	_CGContextRectNeedsFlush(cx, (CGRect){org, rect.size});

	xd = org.x;
	yd = org.y;
	width = (int)NSWidth(c);
	height = y + (int)NSHeight(c);

	if (!a->bytesPerRow || !a->samplesPerPixel || !_CGImageRect( a, (NSRect){x,y,width,height-y}))
		NSLog(@"_CGContextCompositeImage: invalid src image ***");

	_CGContextSetImageBlendMode( cx, a);

	if (a != ds)	// FIX ME s/b an error but menu title shader does layer flush onto same ctx
	  for (; y < height; y++, yd++)
		CTX->_gs->imageBlend(_CGImageLine(a, x, y), &ink, width, _CGImageLine(ds, xd, yd));

	if (((CGContext *)cx)->_bitmap)
		_CGContextFlushBitmap(cx, xd, (int)org.y, xd + width, (int)org.y + (int)NSHeight(c));
}

CGImageRef
_CGContextGetImage(CGContextRef cx, NSRect r)
{
	NSPoint org;

	r = NSIntegralRect(r);
	org.y = CONVERT_Y(r, XCANVAS, ISFLIPPED);
	org.x = NSMinX(r) + NSMinX(XCANVAS);

	if (org.x < 0 || org.y < 0 || ((org.x + NSWidth(r)) > NSWidth(XCANVAS))
			|| ((org.y + NSHeight(r)) > NSHeight(XCANVAS)))
		{
		NSLog(@"CGGetImage grab: %f %f %f %f  outside of window: %f %f",
				org.x, org.y, NSWidth(r), NSHeight(r),
				NSWidth(XCANVAS), NSHeight(XCANVAS));
		return NULL;
		}

	return CGImageCreateWithImageInRect(CTX->_bitmap, (CGRect){org, r.size});
}

/* ****************************************************************************

	_CGContextDrawOutlineGlyph

	height	number of rows, i.e. lines, in the bitmap
	width	number of horizontal pixels in the bitmap
	pitch	number of bytes per bitmap line.  Can be positive or negative
			depending on the bitmap's vertical orientation

	Postive pitch:  buf+pitch 0  |_____________________ [w,h]
                    buf+pitch 1  |_____________________
                                 |_____________________
                          [0,0]  |_____________________

** ***************************************************************************/

static void
_CGContextDrawOutlineGlyph(CGContextRef cx, XRGlyph *glyph, int xorg, int yorg)
{
	unsigned char *bitmap = glyph->bitmap;
	int width = glyph->metrics.width;
	int height = glyph->metrics.height;
	int pitch = glyph->metrics.pitch;
	int x, y;
	int offset;
	int xo = 0;		
	int yo = 0;		
	NSRect c;
	int k = 0;
	unsigned char color[4+width];

	color[2] = GSTATE->stroke.red;
	color[1] = GSTATE->stroke.green;
	color[0] = GSTATE->stroke.blue;

	c = _CGGetClipRect((CGContextRef)cx, (NSRect){xorg,yorg,width,height});
	if (c.size.width <= 0 || c.size.height <= 0)
		return;

//	printf("_CGContextDrawOutlineGlyph glyph clip rect %f %f %f %f\n", c.origin.x, c.origin.y, c.size.width, c.size.height);

	xo = ABS(xorg - (int)c.origin.x);
	width = xo + (int)NSWidth(c);
	xorg = (int)c.origin.x;

	yo = ABS(yorg - (int)c.origin.y);
	height = yo + NSHeight(c);
	yorg = (int)c.origin.y;

	x = xo;
	offset = yo * pitch;
	for (y = yo; y < height; y++, k++)
		{
		memcpy(color+3, bitmap+offset+x, width-x);

		CTX->_gs->textBlend(color, 255, width-x, _CGRasterLine(cx, xorg, yorg+k, 1));
		offset += pitch;
		}
}

static void
_CGContextDrawBitmapGlyph(CGContextRef cx, XRGlyph *glyph, int xorg, int yorg)
{
	unsigned char *bitmap = glyph->bitmap;
	int width = glyph->metrics.width;
	int height = glyph->metrics.height;
	int pitch = glyph->metrics.pitch;
	int x, y;
	int offset;
	int xo = 0;		
	int yo = 0;		
	NSRect c;
	unsigned char color[4+width];

	color[2] = GSTATE->fill.red;
	color[1] = GSTATE->fill.green;
	color[0] = GSTATE->fill.blue;

	c = _CGGetClipRect(cx, (NSRect){xorg,yorg,width,height});
	if (c.size.width == 0 || c.size.height == 0)
		return;
#if 0
	fprintf(stderr,"FBDrawBitmapChar8 glyph clip rect %f %f %f %f\n", c.origin.x, c.origin.y, c.size.width, c.size.height);
#endif

	xo = ABS(xorg - NSMinX(c));
	width = xo + NSWidth(c);

	yo = ABS(yorg - NSMinY(c));
	height = yo + NSHeight(c);

	offset = yo * pitch;
	for (y = yo; y < height; y++)					// convert bitmap to bytes
		{
		unsigned char span[width];
		unsigned char *sp = span;
		int j, k;

		memset(span, 0, width);

		for (x = xo; x < width;)
			for (j = 0; j < pitch && x < width; j++)
				{
				unsigned char b = bitmap[offset+j];

				if (b == 0)
					sp += 8;						// one pitch increment
				else
					for (k = 7; k >= 0; k--)
						*sp++ = ((b >> k) & 0x1) ? 255 : 0;
				x += 8;
				}

		memcpy(color+3, span+xo, width-xo);

		CTX->_gs->textBlend(color, 255, width-xo, _CGRasterLine(cx, xo+xorg, y+yorg, 1));

		offset += pitch;
		}
}

/* ****************************************************************************

	_CGGetKern
	
	Some fonts contain kerning tables that can be used to tune glyph layout,
	unfortunately many common Linux fonts do not produce meaningful offsets
	despite Freetype reporting that they have kerning.  Here we fake it.

	FT_Face face = font->face;
	FT_GlyphSlot slot = face->glyph;
	FT_Bool use_kerning = FT_HAS_KERNING( face );
	FT_Vector delta;
	int pen_x, pen_y;

	if ( use_kerning && previous && glyph_index )
		{
		FT_Get_Kerning( face, previous, glyph_index, FT_KERNING_DEFAULT, &delta );
		pen_x += delta.x >> 6;				// dx/64
		}
	FT_Load_Glyph( face, glyph_index, FT_LOAD_RENDER );
	draw_glyph( &slot->bitmap, pen_x + slot->bitmap_left, pen_y - slot->bitmap_top );
	pen_x += slot->advance.x >> 6;

	https://www.freetype.org/freetype2/docs/tutorial/step2.html

** ***************************************************************************/

static inline int
_CGGetKern(AXFontInt *font, FT_UInt previous, FT_UInt glyph_index)
{
	unsigned int c = glyph_index;
	int kx = 0;

	if (font->glyphs[c]->metrics.width > 0)
		{									// center if advance wider than width
		if (font->glyphs[c]->metrics.xOff > font->glyphs[c]->metrics.width + 1.0 && font->glyphs[c]->metrics.x == 0)
			kx = (font->glyphs[c]->metrics.xOff - font->glyphs[c]->metrics.width) / 2;
		else
			kx = font->glyphs[c]->metrics.x * -1.0;
		}
	if (kx < 1.0 && font->glyphs[c]->metrics.width < font->glyphs[c]->metrics.xOff)
		kx = font->glyphs[c]->metrics.x;	// only glyph wider than advance needs negative kern

	return kx;
}

void
_CGContextDrawGlyphs( CGContextRef cx, int *char32, int nglyphs, CGFloat x, CGFloat y)
{
	AXFontInt *font = (AXFontInt *) ((CGFont *)CTX->_gs->font)->_ftFont;
	CGAffineTransform tx = (CGAffineTransform){1,0,0,1, -x, -y};
	NSRect bbx = NSZeroRect;
	int bbxo = x;
	int bby = 0;
	int bbw = 0;
	int bbh = 0;
	int xo = x;
	int yo = y;
	int xt = x;
	int i;

	if (((CGContext *)cx)->_f.textMatrix)
		tx = CGAffineTransformConcat( tx, ((CGContext *)cx)->_ttm);

	if (font->face->glyph->format == FT_GLYPH_FORMAT_OUTLINE)
		{
		for (i = 0; i < nglyphs; i++)
			{
			unsigned int c = char32[i];
			CGFloat kd = _CGGetKern(font, 0, c);
			int yy = font->glyphs[c]->metrics.yOff - font->glyphs[c]->metrics.height - font->glyphs[c]->metrics.descent;
			int h = MAX(font->glyphs[c]->metrics.pitch, font->glyphs[c]->metrics.yOff + font->glyphs[c]->metrics.height);

			if (font->glyphs[c]->metrics.y < 0)
				yy += font->glyphs[c]->metrics.y + 1;	// adj baseline e.g. underscore (95)
#if 0
			fprintf(stderr,"RenderGlyphs x %f kd %f X %f width %f  xOFF %f pitch %d  descent %d\n", x, kd, font->glyphs[c]->metrics.x,
					font->glyphs[c]->metrics.width, font->glyphs[c]->metrics.xOff, font->glyphs[c]->metrics.pitch, font->glyphs[c]->metrics.descent);
#endif
			if (((CGContext *)cx)->_f.textMatrix)
				{
				int yOff = 10 - font->glyphs[c]->metrics.height + font->glyphs[c]->metrics.yOff;

				kd = font->glyphs[c]->metrics.xOff - font->glyphs[c]->metrics.width / 2;	// negative offset

				NSPoint a = CGPointApplyAffineTransform((NSPoint){xt+kd, yo - yOff + font->glyphs[c]->metrics.yOff}, tx);
						x = xo + round(a.x);
						y = yo - round(a.y);
				_CGContextDrawOutlineGlyph(cx, font->glyphs[c], x, y);

				xt += (font->glyphs[c]->metrics.width + font->glyphs[c]->metrics.xOff) / 2 + GSTATE->spacing;
				if (kd > 0)
					xt += kd;
				a = CGPointApplyAffineTransform((NSPoint){xt,yo}, tx);
				y = yo - round(a.y);
				}
			else
				{
				_CGContextDrawOutlineGlyph(cx, font->glyphs[c], x+kd, y+yy);

				x += font->glyphs[c]->metrics.xOff + GSTATE->spacing;
				}

//printf("GLYPH %d  y %f  yy %d (%f) \t %f h %d descent %d\n", c, y, yy, y+yy, font->glyphs[c]->metrics.yOff, h, font->glyphs[c]->metrics.descent);
			bby = (bby>0) ? MIN(bby, y+yy) : y+yy;
			bbw += font->glyphs[c]->metrics.xOff + GSTATE->spacing + ABS(kd);
			bbh = MAX(h + ABS(font->glyphs[c]->metrics.descent), bbh );
			bbx = NSUnionRect(bbx, (NSRect){x,y, font->glyphs[c]->metrics.width, font->glyphs[c]->metrics.height});
		}	}
	else
		{
		for (i = 0; i < nglyphs; i++)
			{
			unsigned int c = char32[i];
			int yy = font->glyphs[c]->metrics.yOff - font->glyphs[c]->metrics.height - font->glyphs[c]->metrics.descent;
			int h = MAX(font->glyphs[c]->metrics.pitch, font->glyphs[c]->metrics.yOff + font->glyphs[c]->metrics.height);

			_CGContextDrawBitmapGlyph(cx, font->glyphs[c], x, y+yy);
			x += font->glyphs[c]->metrics.xOff;

			bby = (bby>0) ? MIN(bby, y+yy) : y+yy;
			bbw += font->glyphs[c]->metrics.xOff + GSTATE->spacing;
			bbh = MAX(h + ABS(font->glyphs[c]->metrics.descent), bbh );
		}	}

//	NSLog(@"FlushCanvas X rect (%d, %d), (%d, %d)", bbxo, bby, bbw, bbh);
	if (((CGContext *)cx)->_f.textMatrix)
		{
		NSLog(@"FlushCanvas X rect (%d, %d), (%d, %d)", (int)bbx.origin.x, (int)bbx.origin.y, (int)bbx.size.width, (int)bbx.size.height);
		_CGContextFlushBitmap(cx, (int)(bbx.origin.x-1), (int)bbx.origin.y, (int)bbx.origin.x + (int)bbx.size.width, (int)(bbx.origin.y + bbx.size.height));
		}
	else
		_CGContextFlushBitmap(cx, MAX(0, bbxo-1), bby, bbxo + bbw, bby + bbh);

	CTX->_pen.x += x - bbxo;
}

void
CGContextSetCharacterSpacing( CGContextRef cx, CGFloat spacing)
{
	GSTATE->spacing = spacing;
}

CGFloat
_CGContextTextWidth( CGContextRef cx, CGFontRef f, const char *bytes, int length)
{
	return _CGTextWidth((CGFont*)f, bytes, length) + (GSTATE->spacing * length);
}
