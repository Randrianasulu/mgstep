/*
   CTFont.h

   mini Core Text font object.

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CTFont
#define _mGSTEP_H_CTFont

#include <CoreGraphics/CGFont.h>
#include <CoreGraphics/CGAffineTransform.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGContext.h>


typedef const struct _NSFont * CTFontRef;


typedef enum _CTFontOptions {		// descriptor match / font create options
	kCTFontOptionsDefault               = 0,
	kCTFontOptionsPreventAutoActivation = 1,
	kCTFontOptionsPreferSystemFont      = 2
} CTFontOptions;


extern CTFontRef CTFontCreateWithName( CFStringRef name,
									   CGFloat size,
									   const CGAffineTransform *m);

extern CTFontRef CTFontCreateWithNameAndOptions( CFStringRef name,
												 CGFloat size,
												 const CGAffineTransform *m,
												 CTFontOptions opt );

	// Performs basic character-to-glyph mapping.  Returns TRUE if font could
	// encode all Unicode characters else FALSE with bad indexes set to 0
	// Glyph is apparently precomposed at this point.
extern BOOL CTFontGetGlyphsForCharacters( CTFontRef f,
										  const UniChar chars[],
										  CGGlyph glyphs[],
										  CFIndex count );

	// Returns a new font reference that can best map the given string range
	// based on the current font.
extern CTFontRef CTFontCreateForString( CTFontRef currentFont,
										CFStringRef string,
										CFRange range );

	// Create a CG Path from a glyph transformed by m which can be NULL
extern CGPathRef  CTFontCreatePathForGlyph( CTFontRef f,
											CGGlyph g,
											const CGAffineTransform *m);

#endif  /* _mGSTEP_H_CTFont */
