/*
   _CGFont.h

   Font private interfaces

   Copyright (C) 2019 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Nov 2019

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _H_CGFont
#define _H_CGFont

#include <ft2build.h>
#include <freetype.h>
#include <ftoutln.h>
#include <ftsynth.h>
#include <ttnameid.h>
#include <ftbdf.h>

#define NUM_LOCAL			1024

/* sub-pixel order */
#define FC_RGBA_UNKNOWN	    0
#define FC_RGBA_RGB			1
#define FC_RGBA_BGR			2
#define FC_RGBA_VRGB	    3
#define FC_RGBA_VBGR	    4

/* hinting style */
#define FC_HINT_NONE        0
#define FC_HINT_FULL        3
#define FC_PROPORTIONAL		0
#define FC_MONO			    100
#define FC_CHARCELL		    110


typedef struct _XRGlyphInfo {

	float x;
	float y;
	float width;
	float height;
	float xOff;
	float yOff;
	int pitch;
	int descent;

} XRGlyphInfo;


typedef struct _XRGlyph {		// Glyphs are stored in this structure

    XRGlyphInfo metrics;
    void *bitmap;
    unsigned long glyph_memory;

} XRGlyph;


typedef struct _GlyphBoundsIntegerRect {

	int left, right;
	int top,  bottom;

} _GlyphBounds;


typedef struct	{ @defs(NSFont); } CTFont, CGFont;

/* ****************************************************************************

    _CGOpenFont() --> Tune AXFontInt --> CGFontCreateWithPlatformFont()

	font->load_flags |= FT_LOAD_VERTICAL_LAYOUT;	// set vertical layout
	font->load_flags |= FT_LOAD_FORCE_AUTOHINT;		// force autohinting
	font->load_flags |= FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH;

** ***************************************************************************/

typedef struct _AXFontInt {

	int  ascent;
	int  descent;
	int  height;
	int  max_advance_width;

	FT_Face		face;				// pointer to face; only valid when lock
	FT_F26Dot6  xxsize;				// current xsize setting
	FT_F26Dot6  xysize;				// current ysize setting
	FT_Matrix   xmatrix;			// current matrix setting

	int decoder;
									// Rendering options
	int hint_style;
	int spacing;
	int char_width;

	FT_F26Dot6	xsize;				// pixel size
	FT_F26Dot6	ysize;				// pixel size
	int			rgba;				// subpixel order
	FT_Matrix	matrix;				// glyph transformation matrix
	FT_Int		load_flags;			// glyph load flags

	NSMapTable *glyphCache;			// tranformed glyphs cache
    void *hash;						// glyph cache seed

    XRGlyph **glyphs;				// glyph cache plain, indexed by glyph ID
    int num_glyphs;					// size of glyph bitmap array

    unsigned long  glyph_memory;	// glyph cache mem management
    unsigned long  max_glyph_memory;

} AXFontInt;


extern AXFontInt * _CGOpenFont(const char *name, float pointSize);

extern void _CGFontClose (CGFontRef f);

extern FT_Face _CGLockFace (CGFontRef f);
extern FT_UInt _CGGlyphIndex (CGFontRef f, UInt32 ucs4);

extern void _CGFontLoadGlyphs (CGFont *f, const FT_UInt *glyphs, int nglyph);

extern float _CGTextWidth (CGFont *f, const char *string, int length);

extern BOOL _CGFontSetMatrix (CGFontRef f, CGAffineTransform *m);

/* ****************************************************************************

  X Logical Font Description pattern

  1   FOUNDRY: Type foundry - vendor or supplier of this font
  2   FAMILY_NAME: Typeface family
  3   WEIGHT_NAME: Weight of type
  4   SLANT: upright, italic, oblique, reverse italic, reverse oblique, "other"
  5   SETWIDTH_NAME: Proportionate width (e.g. normal, condensed, expanded...)
  6   ADD_STYLE_NAME: Additional style (e.g. (Sans) Serif, Informal, Decorated)
  7   PIXEL_SIZE: Size of characters, in pixels; 0 (Zero) means a scalable font
  8   POINT_SIZE: Size of characters, in tenths of points
  9   RESOLUTION_X: Horizontal resolution in dots per inch (DPI)
  10  RESOLUTION_Y: Vertical resolution, in DPI
  11  SPACING: monospaced, proportional, or "character cell"
  12  AVERAGE_WIDTH: Average width of font characters; 0 means scalable font
  13  CHARSET_REGISTRY: Registry defining this character set (e.g iso8859)
  14  CHARSET_ENCODING: Registry's character encoding scheme for this set

** ***************************************************************************/

extern NSString * _NSFontMatchingPattern(NSString *pattern);
extern NSFont * _NSFontFind(NSString *mp, const char *weight, unsigned size);

#endif  /* _H_CGFont */
