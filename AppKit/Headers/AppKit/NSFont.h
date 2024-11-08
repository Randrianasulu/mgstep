/*
   NSFont.h

   Font class

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFont
#define _mGSTEP_H_NSFont

#include <Foundation/NSCoder.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSString.h>

@class NSDictionary;
@class NSGraphicsContext;


typedef unsigned int NSGlyph;

enum {
	NSControlGlyph = 0x00ffffff,					// tab, cr, lf ...etc
	NSNullGlyph    = 0x0
};

typedef enum {

    NSFontDefaultRenderingMode             = 0,		// defined by user pref
    NSFontAntialiasedRenderingMode         = 1,		// AA, floating-point adv
    NSFontIntegerAdvancementsRenderingMode = 2,		// integer advancements
    NSFontAntialiasedIntegerAdvancementsRenderingMode = 3 	// AA, integer adv

} NSFontRenderingMode;

extern const CGFloat *NSFontIdentityMatrix;  		// [1 0 0 1 0 0]


@interface NSFont : NSObject  <NSCoding>
{
	NSString *_name;
	NSString *_family;
	NSString *_display;
	NSString *_descriptor;

	CGFloat _matrix[6];

	struct AXFontInt *_ftFont;

	struct __FontFlags {
		unsigned int isFixedPitch:1;
		unsigned int antialias:1;
		unsigned int embolden:1;		// force emboldening
		unsigned int transform:1;		// non-identify matrix?
		unsigned int minspace:1;
		unsigned int reserved:3;
	} _f;
}
										// family-face name e.g. Helvetica-Bold
+ (NSFont *) fontWithName:(NSString*)fontName matrix:(const float *)fontMatrix;
+ (NSFont *) fontWithName:(NSString*)fontName size:(float)fontSize;

+ (NSFont *) boldSystemFontOfSize:(float)fontSize;
+ (NSFont *) systemFontOfSize:(float)fontSize;

+ (NSFont *) userFixedPitchFontOfSize:(float)fontSize;
+ (NSFont *) userFontOfSize:(float)fontSize;
+ (void) setUserFixedPitchFont:(NSFont *)aFont;			// Set class font
+ (void) setUserFont:(NSFont *)aFont;

- (void) set;
- (void) setInContext:(NSGraphicsContext *)gc;

- (NSString *) fontName;
- (NSString *) familyName;
- (NSString *) displayName;

- (NSStringEncoding) mostCompatibleStringEncoding;

- (NSRect) boundingRectForFont;
- (BOOL) glyphIsEncoded:(NSGlyph)aGlyph;				// deprecated on OS X
- (BOOL) isFixedPitch;
- (const CGFloat *) matrix;
- (NSFont *) printerFont;
- (NSFont *) screenFont;
- (NSSize) maximumAdvancement;
- (NSSize) minimumAdvancement;

- (float) pointSize;
- (float) leading;
- (float) ascender;
- (float) descender;
- (float) capHeight;
- (float) italicAngle;
- (float) underlinePosition;
- (float) underlineThickness;
- (float) xHeight;
- (float) widthOfString:(NSString *)string;

- (NSSize) advancementForGlyph:(NSGlyph)aGlyph;			// Glyph Attributes
- (NSRect) boundingRectForGlyph:(NSGlyph)aGlyph;

- (NSGlyph) glyphWithName:(NSString*)glyphName;
- (NSUInteger) numberOfGlyphs;

//- (NSFont *) screenFontWithRenderingMode:(NSFontRenderingMode)rm;
//- (NSFontRenderingMode) renderingMode;

@end

#endif  /* _mGSTEP_H_NSFont */
