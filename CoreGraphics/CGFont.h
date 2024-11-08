/*
   CGFont.h

   mini Core Graphics font object.

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jun 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CGFont
#define _mGSTEP_H_CGFont

typedef struct _NSFont * CGFontRef;

typedef unsigned int  CGGlyph;


extern CGFontRef CGFontCreateWithPlatformFont (void *platformFontReference);

extern void CGFontRelease (CGFontRef f);
extern void CGFontRetain  (CGFontRef f);


#if 0
extern CGFontRef CGFontCreateWithFontName(CFStringRef name);
extern CFStringRef CGFontCopyFullName(CGFontRef f);
extern size_t CGFontGetNumberOfGlyphs(CGFontRef f);

extern int CGFontGetDescent(CGFontRef f);
extern int CGFontGetAscent(CGFontRef f);
extern int CGFontGetLeading(CGFontRef f);  // space between lines of text

extern CGRect CGFontGetFontBBox(CGFontRef f);

		// Distance above baseline of the glyph tops of flat capital letters
		// in font.  Value is specified in glyph space units.
extern int CGFontGetCapHeight(CGFontRef f);

		// Distance above baseline of the top of flat, non-ascending lowercase
		// letters (e.g. "x") of glyphs in a font. Value is glyph space units.
extern int CGFontGetXHeight(CGFontRef f);

		// angle in degrees counter-clockwise from vertical
extern CGFloat CGFontGetItalicAngle(CGFontRef f);

		// Returns advance of each glyph in `glyphs' array with size `count'
		// and places it in the corresponding entry of `advances'.  Array of
		// advances are in glyph space.  Returns false on failure, else true.
extern bool CGFontGetGlyphAdvances( CGFontRef f,
									const CGGlyph glyphs[],
									size_t count,
									int advances[]);

		// Returns bounding box of each glyph in `glyphs' array with size
		// `count' and places it in the corresponding entry of `bboxes' an
		// array of rects.  Returns false on failure, else true.
extern bool CGFontGetGlyphBBoxes(CGFontRef f,
								const CGGlyph glyphs[],
								size_t count,
								CGRect bboxes[]);
#endif

#endif  /* _mGSTEP_H_CGFont */
