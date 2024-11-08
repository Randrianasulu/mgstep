/*
   CGFont.m

   mini Core Graphics FreeType font management

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   Portions of the FreeType interface were derived
   from Keith Packard's Xft and Fontconfig.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
#include <CoreGraphics/Private/encoding.h>


#define FONT_MAX_GLYPH_MEMORY   (1024 * 1024)

#define X_SIZE(face,a)    ((face)->available_sizes[a].x_ppem)
#define Y_SIZE(face,a)    ((face)->available_sizes[a].y_ppem)

#define DIST(a,b)		  ( ABS((a) - (b)) )

#define FLOOR(x)		  ((x) & -64)
#define CEIL(x)			  (((x)+63) & -64)
#define TRUNC(x)		  ((x) >> 6)

#undef ROUND
#define ROUND(x)		  (((x)+32) & -64)


static FT_Library __FTLibrary = NULL;



static BOOL
_CGConfigureFace (AXFontInt *font)
{
	FT_Face face = font->face;
	FT_Matrix *matrix = &font->matrix;
	FT_F26Dot6 xsize = font->xsize;
	FT_F26Dot6 ysize = font->ysize;

    if (font->xxsize != xsize || font->xysize != ysize)
		{
		if (!(face->face_flags & FT_FACE_FLAG_SCALABLE))
			{					// Bitmap only faces must match exactly, find
			int i, best = 0;	// the closest one (height dominant search)
	
			for (i = 1; i < face->num_fixed_sizes; i++)
				{
				if (DIST(ysize, Y_SIZE(face,i)) < DIST(ysize, Y_SIZE(face, best))
						|| (DIST(ysize, Y_SIZE(face, i)) == DIST(ysize, Y_SIZE(face, best))
						&& DIST(xsize, X_SIZE(face, i)) < DIST(xsize, X_SIZE(face, best))))
					{
					best = i;
					}
				}
			if ( FT_Set_Char_Size (face, face->available_sizes[best].x_ppem,
								face->available_sizes[best].y_ppem, 0, 0) != 0)
				{
				return NO;
				}					// set character size, use 50pt at 100dpi
//  		FT_Set_Char_Size( face, 50 * 64, 0, 100, 0 );
			}
		else
			if (FT_Set_Char_Size (face, xsize, ysize, 0, 0))
				return NO;

		font->xxsize = xsize;
		font->xysize = ysize;
		}

    if (font->xmatrix.xx != matrix->xx || font->xmatrix.yy != matrix->yy
			|| font->xmatrix.xy != matrix->xy || font->xmatrix.yx != matrix->yx)
		{
	    NSLog(@"Set face matrix to (%g,%g,%g,%g)\n",
		    (double) matrix->xx / 0x10000, (double) matrix->xy / 0x10000,
		    (double) matrix->yx / 0x10000, (double) matrix->yy / 0x10000);
		FT_Set_Transform (face, matrix, NULL);
		font->xmatrix = *matrix;
		}

    return YES;
}

static unsigned long
_HashGlyphKeyPrefix(FT_Matrix *matrix)
{
	unsigned char *m = (unsigned char *)matrix;
	unsigned long hash = m[0];
	unsigned int i;

	for (i = 1; i < sizeof(FT_Matrix); i++)					// sdbm hash
		hash = m[i] + (hash << 6) + (hash << 16) - hash;

	return hash;
}

BOOL
_CGFontSetMatrix (CGFontRef f, CGAffineTransform *m)
{
	AXFontInt *font = (AXFontInt *) ((CGFont *)f)->_ftFont;
	FT_Matrix matrix;
	BOOL transform;

	matrix.xx = (FT_Fixed)( m->a * 0x10000L );
	matrix.xy = (FT_Fixed)( m->c * 0x10000L );
	matrix.yx = (FT_Fixed)( m->b * 0x10000L );
	matrix.yy = (FT_Fixed)( m->d * 0x10000L );

    transform = (memcmp(m, &CGAffineTransformIdentity, sizeof(*m)) != 0);
	if (transform && !font->glyphCache)
		font->glyphCache = NSCreateMapTable( NSIntMapKeyCallBacks,
											 NSNonOwnedPointerMapValueCallBacks,
											 font->num_glyphs);
	if (font->glyphCache && !((CGFont *)f)->_f.transform)
		{
		unsigned long hash = _HashGlyphKeyPrefix(&font->matrix);
		int i;

		for (i = 0; i < font->num_glyphs; i++)
			{
			XRGlyph *xrg = font->glyphs[i];

			if (xrg)									// save glyphs to cache
				NSMapInsert (font->glyphCache, (void *)hash + (i << 9), xrg);
		}	}
														// dump glyph array
	memset (font->glyphs, '\0', font->num_glyphs * sizeof(XRGlyph *));
	((CGFont *)f)->_f.transform = transform;
	font->matrix = matrix;
	font->hash = (void *)_HashGlyphKeyPrefix(&matrix);

    return transform;
}

static void
printBytes(char *bitmap, int n)
{
	int offset;

	for (offset = 0; offset < n; offset++)
		{
		unsigned char c = bitmap[offset];
		printf("%02hhX ",c);
		}
	printf("\n");
}

static void
_PrintGlyph(FT_Bitmap *bmp)
{
	unsigned char *srcLine = bmp->buffer;
	int h = bmp->rows;

	NSLog(@"printBytes %d %d ****************\n", h, bmp->width);

	while (h--)
		{
		printBytes(srcLine, bmp->width);
		srcLine += bmp->pitch;
		}
}

static UInt32
_MapCharCode (const FontMap *map, UInt32 ucs4)
{
	int low = 0;
	int high = map->num_entries - 1;

    if (ucs4 >= map->items[low].bmp && map->items[high].bmp >= ucs4)
		while (low <= high)
			{
			int mid = (high + low) >> 1;
			UInt16 bmp = map->items[mid].bmp;
	
			if (ucs4 == bmp)
				return (FT_ULong) map->items[mid].index;
	
			if (ucs4 < bmp)
				high = mid - 1;
			else
				low = mid + 1;
			}

    return ~0;
}

static inline void
_RenderBitmapGlyph (FT_GlyphSlot slot, unsigned char *bufBitmap, int pitch,
					int hmul, int vmul, BOOL subpixel, BOOL antialias)
{
	unsigned char *srcLine = slot->bitmap.buffer;
	unsigned char *dstLine = bufBitmap;
	int br = slot->bitmap.rows;

	if (antialias)
		{
		while (br--)
			{
			int x;

			for (x = 0; x < slot->bitmap.width; x++)
				{										// always MSB bitmaps
				unsigned char a = ((srcLine[x >> 3] & (0x80 >> (x & 7))) ? 0xff : 0x00);

				if (subpixel)
					{
					int h, v;

					for (v = 0; v < vmul; v++)
						for (h = 0; h < hmul; h++)
							dstLine[v * pitch + x*hmul + h] = a;
					}
				else
					dstLine[x] = a;
				}
			dstLine += pitch * vmul;
			srcLine += slot->bitmap.pitch;
		}	}
	else
		{
		int bytes = (slot->bitmap.width + 7) >> 3;

//printf("Glyph height %d  width %d  bytes %d  pitch %d\n",h, glyphslot->bitmap.width, bytes, glyphslot->bitmap.pitch);
		while (br--)
			{
//printBytes(srcLine, bytes);
			memcpy (dstLine, srcLine, bytes);
			dstLine += pitch;
			srcLine += slot->bitmap.pitch;
		}	}
}

static inline void
_FilterGlyph( AXFontInt *font,			// Filter glyph to soften color edges
			  unsigned char *bufBitmap,
			  unsigned char *bufBitmapRgba,
			  int pitchrgba, int sizergba,
			  int width, int height, int pitch, int hmul, int vmul)
{
	int x, y;
	unsigned char *in_line = bufBitmap;
	unsigned char *out_line = bufBitmapRgba;
	int r, g, b;
	int os = 1;
	static const int filters[3][3] = {
			/* red */	{ 65538*9/13,65538*3/13,65538*1/13 },
			/* green */	{ 65538*1/6, 65538*4/6, 65538*1/6 },
			/* blue */	{ 65538*1/13,65538*3/13,65538*9/13 } };

	switch (font->rgba)
		{
		case FC_RGBA_VRGB:
			os = pitch;
		case FC_RGBA_RGB:
		default:
			r = 0;
			g = 1;
			b = 2;
			break;
		case FC_RGBA_VBGR:
			os = pitch;
		case FC_RGBA_BGR:
			b = 0;
			g = 1;
			r = 2;
			break;
		}

	for (y = 0; y < height; y++)
		{
		unsigned char *inp = in_line;
		unsigned int *outp = (unsigned int *) out_line;

		in_line += pitch * vmul;
		out_line += pitchrgba;

		for (x = 0; x < width * hmul; x += hmul)
			{
			int s;
			int o = 0;
			unsigned int red = 0, green = 0, blue = 0;

			for (s = 0; s < 3; s++)
				{
				red   += filters[r][s]*inp[x+o];
				green += filters[g][s]*inp[x+o];
				blue  += filters[b][s]*inp[x+o];
				o += os;
				}
			red   /= 65536;
			green /= 65536;
			blue  /= 65536;
			*outp++ = (green << 24) | (red << 16) | (green << 8) | blue;
		}	}
}

static inline _GlyphBounds
_GetGlyphBounds (AXFontInt *font, FT_GlyphSlot gs)
{
	_GlyphBounds bbx = {0};
	FT_Vector vector;
	int xc, yc;		// Compute glyph metrics from FreeType information
					// calc the true width by transforming all four corners
	for (xc = 0; xc <= 1; xc++)
		{
		for (yc = 0; yc <= 1; yc++)
			{
			vector.x = gs->metrics.horiBearingX + xc * gs->metrics.width;
			vector.y = gs->metrics.horiBearingY - yc * gs->metrics.height;
			FT_Vector_Transform(&vector, &font->matrix);

			NSLog(@"FBFont trans %d %d: %d %d\n", (int) xc, (int) yc,
					(int) vector.x, (int) vector.y);

			if (xc == 0 && yc == 0)
				{
				bbx.left = bbx.right = vector.x;
				bbx.top  = bbx.bottom = vector.y;
				}
			else
				{
				if (bbx.left > vector.x)
					bbx.left = vector.x;
				if (bbx.right < vector.x)
					bbx.right = vector.x;
				if (bbx.bottom > vector.y)
					bbx.bottom = vector.y;
				if (bbx.top < vector.y)
					bbx.top = vector.y;
		}	}	}

	bbx.left   = FLOOR(bbx.left);
	bbx.right  = CEIL(bbx.right);
	bbx.top    = CEIL(bbx.top);
	bbx.bottom = FLOOR(bbx.bottom);
DBLog(@"F Font top %d  left %d: right %d  bottom %d\n", bbx.top, bbx.left, bbx.right, bbx.bottom);
DBLog(@"F Font top %d  left %d: right %d  bottom %d\n", (int) bbx.top/64, (int) bbx.left/64,
						(int) bbx.right/64, (int) bbx.bottom/64);
	return bbx;
}

/* ****************************************************************************

	_CGFontLoadGlyphs

	http://freetype.sourceforge.net/freetype2/docs/tutorial/step1.html

** ***************************************************************************/

void
_CGFontLoadGlyphs (CGFont *f, const FT_UInt *glyphs, int nglyph)
{
	AXFontInt *font = (AXFontInt *) f->_ftFont;
	unsigned char bufLocal[4096];
	unsigned char *bufBitmap = bufLocal;
	int bufSize = sizeof (bufLocal);
	int hmul = 1;
	int vmul = 1;
	FT_Matrix matrix;
	FT_Face face;
	BOOL subpixel = NO;

    if (!(face = _CGLockFace ( (CGFontRef)f)))
		return;

    matrix.xx = matrix.yy = 0x10000L;
    matrix.xy = matrix.yx = 0;

    if (f->_f.antialias)
		switch (font->rgba)
			{
			case FC_RGBA_RGB:
			case FC_RGBA_BGR:
				matrix.xx *= 3;
				subpixel = YES;
				hmul = 3;
				break;
			case FC_RGBA_VRGB:
			case FC_RGBA_VBGR:
				matrix.yy *= 3;
				vmul = 3;
				subpixel = YES;
				break;
			}

    while (nglyph--)
		{
		FT_UInt glyphindex = *glyphs++;
		_GlyphBounds bbx;
		int size, pitch;
		int width, height;
		int sizergba, pitchrgba, allocSize;
		FT_Bitmap bmp;
		FT_GlyphSlot gs;
		XRGlyph *xrg;		// Check if glyph was just loaded, occurs when
							// drawing same glyph twice in a single string
		if ((xrg = font->glyphs[glyphindex]))
			continue;
		if (((CGFont *)f)->_f.transform)
		  if ((xrg = NSMapGet(font->glyphCache, font->hash + (glyphindex << 9))))
		  	{
			font->glyphs[glyphindex] = xrg;		// restore cached to glyph array
			continue;
			}
							// load glyph image into slot (erasing previous img)
		if (FT_Load_Glyph (face, glyphindex, font->load_flags))
			{
			if (!(font->load_flags & FT_LOAD_NO_BITMAP))
				continue;	// If no outline version exists
			if (FT_Load_Glyph (face, glyphindex, font->load_flags & ~FT_LOAD_NO_BITMAP))
				{
				NSLog(@"FT_Load_Glyph failed ****************\n");
				continue;	// fallback to bitmap even if anti-aliasing or
			}	}			// transforming. Any glyph is better than none.

		gs = face->glyph;

		if (f->_f.embolden)
			FT_GlyphSlot_Embolden(gs);			// Embolden if required

		if (f->_f.transform && gs->format != FT_GLYPH_FORMAT_BITMAP)
			bbx = _GetGlyphBounds (font, gs);
		else
			{
			bbx.left   = FLOOR( gs->metrics.horiBearingX );
			bbx.right  = CEIL( gs->metrics.horiBearingX + gs->metrics.width );
			bbx.top    = CEIL( gs->metrics.horiBearingY );
			bbx.bottom = FLOOR( gs->metrics.horiBearingY - gs->metrics.height);
			}
		width = TRUNC(bbx.right - bbx.left);
		height = TRUNC(bbx.top - bbx.bottom);		// Clip charcell glyphs to
													// their bounding box
		if (font->spacing >= FC_CHARCELL && !f->_f.transform)
			{
			if (font->load_flags & FT_LOAD_VERTICAL_LAYOUT)
				{
				if (TRUNC(bbx.bottom) > font->max_advance_width)
					{
					int adjust = bbx.bottom - (font->max_advance_width << 6);

					if (adjust > bbx.top)
						adjust = bbx.top;
					bbx.top -= adjust;
					bbx.bottom -= adjust;
					height = font->max_advance_width;
				}	}
			else
				{
				if (TRUNC(bbx.right) > font->max_advance_width)
					{
					int adjust = bbx.right - (font->max_advance_width << 6);

					if (adjust > bbx.left)
						adjust = bbx.left;
					bbx.left -= adjust;
					bbx.right -= adjust;
					width = font->max_advance_width;
			}	}	}

		if (f->_f.antialias)
			pitch = (width * hmul + 3) & ~3;
		else
			pitch = ((width + 31) & ~31) >> 3;
		allocSize = size = pitch * height * vmul;

		if (subpixel)
			{
			pitchrgba = (width * 4 + 3) & ~3;
			allocSize = sizergba = pitchrgba * height;
			}

		if (!(xrg = (XRGlyph *) calloc(1, allocSize + sizeof(XRGlyph))))
			continue;
		xrg->glyph_memory = allocSize + sizeof (XRGlyph);
		xrg->bitmap = (void *)xrg + sizeof(XRGlyph);
		xrg->metrics.width = width;
		xrg->metrics.height = height;
		xrg->metrics.x = -TRUNC(bbx.left);
		xrg->metrics.y = TRUNC(bbx.top);
		xrg->metrics.pitch = pitch;			// FIX ME s/b pitchrgba w/subpixel
		xrg->metrics.descent = TRUNC(bbx.bottom);
		if (f->_f.transform)
			NSMapInsert (font->glyphCache, font->hash + (glyphindex << 9), xrg);
		font->glyphs[glyphindex] = xrg;
//	NSLog(@"FBFont xrg %d %d : %d %d\n", width, height, (int) xrg->metrics.x, (int) xrg->metrics.y);

		if (font->spacing >= FC_MONO)
			{
			FT_Vector vector = {0};

			if (f->_f.transform)
				{
				if (font->load_flags & FT_LOAD_VERTICAL_LAYOUT)
					vector.y = -face->size->metrics.max_advance;
				else
					vector.x = face->size->metrics.max_advance;

				FT_Vector_Transform (&vector, &font->matrix);
				xrg->metrics.xOff = vector.x >> 6;
				xrg->metrics.yOff = -(vector.y >> 6);
				}
			else
				{
				if (font->load_flags & FT_LOAD_VERTICAL_LAYOUT)
					xrg->metrics.yOff = -font->max_advance_width;
				else
					xrg->metrics.xOff = font->max_advance_width;
			}	}
		else
			{
			xrg->metrics.xOff = TRUNC(ROUND(gs->advance.x));
///#ifdef FB_GRAPHICS
			if (width <= 4 && width >= xrg->metrics.xOff)
				xrg->metrics.xOff = width+2;  // FIX ME needed in fb not X11 ?
///#endif
			if (f->_f.embolden)
				xrg->metrics.yOff = 0;
			else
				xrg->metrics.yOff = -TRUNC(ROUND(gs->advance.y));
			}

		if (size > bufSize)				// alloc more space for glyph as needed
			{
			if (bufBitmap != bufLocal)
				free (bufBitmap);
			if (!(bufBitmap = (unsigned char *) malloc(size)))
				continue;
			bufSize = size;
			}
		memset (bufBitmap, 0, size);

		switch (gs->format)				// Rasterize glyph into the local buffer
			{
			case FT_GLYPH_FORMAT_OUTLINE:
				bmp.buffer = bufBitmap;
				bmp.width = width * hmul;
				bmp.rows = height * vmul;
				bmp.pitch = pitch;
				bmp.pixel_mode = (f->_f.antialias) ? FT_PIXEL_MODE_GRAY
												   : FT_PIXEL_MODE_MONO;
				if (subpixel)
					FT_Outline_Transform (&gs->outline, &matrix);

				FT_Outline_Translate (&gs->outline, -bbx.left*hmul, -bbx.bottom*vmul);
				FT_Outline_Get_Bitmap(__FTLibrary, &gs->outline, &bmp);

///				_PrintGlyph(&bmp);				// Debug ***********
				break;
	
			case FT_GLYPH_FORMAT_BITMAP:
				_RenderBitmapGlyph (gs, bufBitmap, pitch, hmul, vmul, subpixel, f->_f.antialias);
				break;

			default:
				NSLog(@"glyph %d is not in a usable format", (int)glyphindex);
				continue;
			}

		DBLog(@"Loaded glyph index %d", glyphindex);

		if (subpixel)					// Filter glyph to soften color edges
			_FilterGlyph(font, bufBitmap, xrg->bitmap, pitchrgba, sizergba,
						 width, height, pitch, hmul, vmul);
		else
			memcpy (xrg->bitmap, bufBitmap, size);

		font->glyph_memory += xrg->glyph_memory;
//		printf("Caching glyph 0x%x size %ld\n", glyphindex, xrg->glyph_memory);
		}

	if (bufBitmap != bufLocal)
		free (bufBitmap);
}

static float
_WidthOfGlyphs (CGFont *font, const FT_UInt *glyphs, int nglyphs)
{
	AXFontInt *ft = (AXFontInt *) font->_ftFont;
	const FT_UInt *g = glyphs;
	XRGlyphInfo sextents;
	XRGlyphInfo *extents = &sextents;
	FT_UInt glyph;
	XRGlyph *xrg = NULL;
	float width;

	_CGFontLoadGlyphs((CGFont *)font, glyphs, nglyphs);

    while (nglyphs)
		{
		glyph = *g++;
		nglyphs--;
		if (glyph < ft->num_glyphs && (xrg = ft->glyphs[glyph]))
			break;
		}

    if (nglyphs == 0)
		{
		if (xrg)
			*extents = xrg->metrics;
		else
			memset (extents, '\0', sizeof (*extents));
		}
    else
		{
		int overall_left = xrg->metrics.x;
		int overall_top = xrg->metrics.y;
		int overall_right = overall_left + (int) xrg->metrics.width;
		int overall_bottom = overall_top + (int) xrg->metrics.height;
		int x = xrg->metrics.xOff;
		int y = xrg->metrics.yOff;

		while (nglyphs--)
			{
			glyph = *g++;
			if (glyph < ft->num_glyphs && (xrg = ft->glyphs[glyph]))
				{
				int left = x - xrg->metrics.x;
				int top = y - xrg->metrics.y;
				int right = left + (int) xrg->metrics.width;
				int bottom = top + (int) xrg->metrics.height;

				if (left < overall_left)
					overall_left = left;
				if (top < overall_top)
					overall_top = top;
				if (right > overall_right)
					overall_right = right;
				if (bottom > overall_bottom)
					overall_bottom = bottom;
				x += xrg->metrics.xOff;
				y += xrg->metrics.yOff;
			}	}

		extents->x = -overall_left;
		extents->y = -overall_top;
		extents->width = overall_right - overall_left;
		extents->height = overall_bottom - overall_top;
		extents->xOff = x;
		extents->yOff = y;
		}

///	width = (float)extents->width;
	width = (float)extents->xOff;
//	printf ("Width of glyphs %f  height %ld\n", width, extents->height);

	return width;
}

static inline BOOL
_HasCharMap(FT_Face face, FT_Encoding e)
{
	int j;

	for (j = 0; j < face->num_charmaps; j++)
		if (face->charmaps[j]->encoding == e)
			return YES;

	return NO;
}

static inline int
_SelectCharMap(FT_Face face)
{
	int decoder = 0;
	int i;

    for (i = 0; i < NUM_DECODE; i++)			// select best font encoding
		{
		int k = (1 + i) % NUM_DECODE;			// round robin loop from 1

		if (_HasCharMap( face, __FontDecoders[k].encoding))
			{
			decoder = k;
			break;
		}	}

	if (FT_Select_Charmap (face, __FontDecoders[decoder].encoding) != 0)
		if (face->num_charmaps > 0 )
			FT_Set_Charmap (face, face->charmaps[0]);

	if (face->charmap && face->charmap->encoding == FT_ENCODING_NONE)
		{										// if not UNICODE or 8859 the
		const char *acharset_encoding;			// BDF and PCF drivers set NONE
		const char *acharset_registry;			// e.g. CJK == "GB2312.1980"
												// must determine true encoding
		FT_Get_BDF_Charset_ID(face, &acharset_encoding, &acharset_registry );
//  	printf("FT_Get_BDF_Charset_ID %s %s\n", acharset_encoding, acharset_registry);
		if (!strncmp(acharset_registry, "GB2312.1980", strlen("GB2312.1980")))
			decoder = 5;						// FIX ME should enum table
		}

	return decoder;
}

FT_Face
_CGLockFace (CGFontRef f)
{
	AXFontInt *font = (AXFontInt *) ((CGFont *)f)->_ftFont;
	FT_Face	face = font->face;
	int i;
					// Make sure the face is usable at the requested size
    if (!face || !_CGConfigureFace (font))
		{
//		face = 0;	// FIX ME bitmaps ?
	    NSLog(@"_CGLockFace failed ****************\n");

		return NULL;
		}

	if (!face->charmap)
		font->decoder = _SelectCharMap(face);
	if (font->decoder == 0 && face->charmap->encoding != FT_ENCODING_NONE)
		for (i = 0; i < NUM_DECODE; i++)
			if (face->charmap->encoding == __FontDecoders[i].encoding)
				{
				font->decoder = i;
				break;
				}

    return face;
}

/* ****************************************************************************

	_CGGlyphIndex

	Map a UCS4 char code to a font glyph index.

** ***************************************************************************/

FT_UInt
_CGGlyphIndex (CGFontRef f, UInt32 ucs4)
{
	AXFontInt *font = (AXFontInt *) ((CGFont *)f)->_ftFont;
	FT_Face	face = font->face;
	const FontMap *map;
	UInt32 charcode;

	if ((map = __FontDecoders[font->decoder].map))
		charcode = _MapCharCode(map, ucs4);
	else
		charcode = ucs4;

    return FT_Get_Char_Index(face, charcode);
}

float
_CGTextWidth (CGFont *font, const char *bytes, int length)
{
	FT_UInt glyphs_local[NUM_LOCAL];
	FT_UInt *glyphs = glyphs_local;
	float width;
	int j, gc;
	CFRange r = {0,1};
	CFString st = {0};
	CFStringRef s = (CFStringRef)&st;
	UInt32 u4;
	unsigned char *p = (unsigned char *)&u4;

    if (!(_CGLockFace( (CGFontRef)font)))
		return 0;

	if (length > NUM_LOCAL && !(glyphs = malloc(length * sizeof(FT_UInt))))
		return 0;

	st._cString = (char *)bytes;
	st._count = length;
	for (gc = 0; r.location < length; gc++)
		{
		j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
		glyphs[gc] = _CGGlyphIndex((CGFontRef)font, u4);
		r.location += (j > 0) ? j : 1;
		}
	width = _WidthOfGlyphs (font, glyphs, gc);

    if (glyphs != glyphs_local)
		free (glyphs);
	
//	printf ("_CGTextWidth %f ***********************************\n", width);

	return width;
}

void
_CGFontClose (CGFontRef f)
{
	AXFontInt *font = (AXFontInt *) ((CGFont *)f)->_ftFont;
	XRGlyph *xrg;
	int i;

	if (font->glyphCache)							// sync array and cache
		{
		void *k, *v;				// FIX ME sync is inefficient, but some
		NSMapEnumerator e;			// glyphs may be in cache, array may have
									// both cached and uncached
		for (i = 0; i < font->num_glyphs; i++)
			if ((xrg = font->glyphs[i]))			// save glyphs to cache
				NSMapInsert (font->glyphCache, font->hash + (i << 9), xrg);

		e = NSEnumerateMapTable (font->glyphCache);
		while (NSNextMapEnumeratorPair (&e, &k, &v))
			free(v);
  		NSFreeMapTable (font->glyphCache);
		}
	else											// no transformed glyphs
		for (i = 0; i < font->num_glyphs; i++)
			if ((xrg = font->glyphs[i]))
				free(xrg);
}

AXFontInt *
_CGOpenFont(const char *path, float fontSize)
{
	FT_Face face;
	AXFontInt *font;
	double aspect = 1.0;
	int n;

	if (!__FTLibrary)
		if (FT_Init_FreeType (&__FTLibrary))
			NSLog(@"Could not initialize FreeType library\n");

	NSLog(@"_CGOpenFont open %s\n", path);
    if (FT_New_Face (__FTLibrary, path, 0, &face))
		return NULL;
							// glyphs may be numbered 1..n, other times 0..n-1
	n = face->num_glyphs + 1;
	if (!(font = calloc (1, (sizeof(AXFontInt) + n * sizeof(XRGlyph *)))))
		return NULL;

	font->face = face;
	font->ysize = (FT_F26Dot6) (fontSize * 64.0);
	font->xsize = (FT_F26Dot6) (fontSize * aspect * 64.0);

	font->glyphs = (XRGlyph **) (font + 1);		// Per glyph info
	memset (font->glyphs, '\0', n * sizeof (XRGlyph *));
	font->num_glyphs = n;
	font->glyph_memory = 0;						// glyph cache memory management
	font->max_glyph_memory = FONT_MAX_GLYPH_MEMORY;
	font->hint_style = FC_HINT_FULL;			// disable hinting if requested
//	font->load_flags |= FT_LOAD_NO_HINTING;
	font->matrix.xy = font->matrix.yx = 0;		// identity matrix
	font->matrix.xx = font->matrix.yy = 0x10000;
    font->load_flags = FT_LOAD_DEFAULT;			// Compute glyph load flags
	font->rgba = FC_RGBA_UNKNOWN;				// rgba value
	font->spacing = FC_PROPORTIONAL;
	font->char_width = 0;						// Check for fixed pixel spacing

	return font;
}

CGFontRef
CGFontCreateWithPlatformFont (void *platformFontReference)
{
	AXFontInt *font = platformFontReference;
	CGFont *f = (CGFont *)[NSFont alloc];
	FT_Face face = font->face;

	f->_ftFont = (struct AXFontInt *)font;
	f->_f.antialias = YES;					// FIX ME **** _CGContextShouldAntialias() **
    f->_f.transform = (font->matrix.xx != 0x10000 || font->matrix.xy != 0
					|| font->matrix.yx != 0 || font->matrix.yy != 0x10000);

    if (f->_f.antialias || f->_f.transform)		// disable bitmaps when AA'ing
		font->load_flags |= FT_LOAD_NO_BITMAP;	// or transforming glyphs

    if (f->_f.antialias)		// Determine load target for intended use
		{
		if (FC_HINT_NONE < font->hint_style && font->hint_style < FC_HINT_FULL)
			font->load_flags |= FT_LOAD_TARGET_LIGHT;
		else					// autohinter will snap stems to integer widths,
			{					// when the LCD targets are used.
			switch (font->rgba)
				{
				case FC_RGBA_RGB:
				case FC_RGBA_BGR:
					font->load_flags |= FT_LOAD_TARGET_LCD;
					break;
				case FC_RGBA_VRGB:
				case FC_RGBA_VBGR:
					font->load_flags |= FT_LOAD_TARGET_LCD_V;
					break;
		}	}	}
    else
		font->load_flags |= FT_LOAD_TARGET_MONO;

	f->_f.minspace = NO;
	if (font->char_width)
	    font->spacing = FC_MONO;

	if (!_CGConfigureFace (font)) { }
//		return;						// FIX ME bitmaps ?
	
	if (!(face->face_flags & FT_FACE_FLAG_SCALABLE))
		f->_f.antialias = NO;

	if (f->_f.transform)
		{
		FT_Vector vector = {0};
		
		vector.y = face->size->metrics.descender;
		FT_Vector_Transform (&vector, &font->matrix);
		font->descent = -(vector.y >> 6);
		
		vector.x = 0;
		vector.y = face->size->metrics.ascender;
		FT_Vector_Transform (&vector, &font->matrix);
		font->ascent = vector.y >> 6;
	
		if (f->_f.minspace)
			font->height = font->ascent + font->descent;
		else
			{
			vector.x = 0;
			vector.y = face->size->metrics.height;
			FT_Vector_Transform (&vector, &font->matrix);
			font->height = vector.y >> 6;
			}
		}
	else
		{
		font->descent = -(face->size->metrics.descender >> 6);
		font->ascent = face->size->metrics.ascender >> 6;
		if (f->_f.minspace)
			font->height = font->ascent + font->descent;
		else
			font->height = face->size->metrics.height >> 6;
		}
	
	if (font->char_width)
		font->max_advance_width = font->char_width;
	else
		{
		if (f->_f.transform)
			{
			FT_Vector vector = {face->size->metrics.max_advance, 0};

			FT_Vector_Transform (&vector, &font->matrix);
			font->max_advance_width = vector.x >> 6;
			}
		else
			font->max_advance_width = face->size->metrics.max_advance >> 6;
		}

	return (CGFontRef)f;
}

void CGFontRelease (CGFontRef font)		{ [(NSFont *)font release]; }
void CGFontRetain (CGFontRef font)		{ [(NSFont *)font retain]; }
