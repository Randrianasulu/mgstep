/*
   NSFont.m

   Font object

   Copyright (C) 2006 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSUserDefaults.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
#include <CoreGraphics/Private/encoding.h>

#include <AppKit/NSFont.h>
#include <AppKit/NSFontManager.h>


#define TWO_SIXTEENTH 	(1 << 16)
#define TABWIDTH    	4						// default tab width = 4 spaces


static NSMutableDictionary *__fontDictionary = nil;			// known fonts

const CGFloat *NSFontIdentityMatrix = (const CGFloat *)&CGAffineTransformIdentity;



static NSFont *
_GetFont(NSString *key, NSString *defaultFontName, float size)
{
	NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
	NSString *fontName;

	if (!(fontName = [u objectForKey:key]))
		fontName = defaultFontName;

	if (!size)
		if(!(size = [u floatForKey:[NSString stringWithFormat:@"%@Size",key]]))
			size = 12;

	return [NSFont fontWithName:fontName size:size];
}

NSFont *
_NSFontFind(NSString *mf, const char *weight, unsigned size)
{
	NSString *xf = [NSString stringWithFormat: @"%c-%03d-%@", *weight, size, mf];
	AXFontInt *fonti;
	NSFont *font;

	if ((font = [__fontDictionary objectForKey: xf]))		// if font exists
		return font;										// return it

	NSLog(@"**** open font: %@\n", mf);

	if (!(fonti = _CGOpenFont([mf cString], size)))
		{
		NSLog(@"Unable to open font: %@\n", xf);
		return nil;
		}

	if ((font = (NSFont*)CGFontCreateWithPlatformFont (fonti)))
		{
		if (fonti->face->face_flags & FT_FACE_FLAG_SCALABLE && *weight == 'b')
			((CGFont *)font)->_f.embolden = 1;
		[__fontDictionary setObject:font forKey:xf];
		}

	return [font autorelease];
}

/* ****************************************************************************

	NSFont

** ***************************************************************************/

@implementation NSFont

+ (void) initialize
{
	if (__fontDictionary == nil) 
		__fontDictionary = [NSMutableDictionary new];
}

+ (NSString *) _encodingScheme
{
	NSStringEncoding e = [NSString defaultCStringEncoding];

	if (e == NSASCIIStringEncoding || e == NSISOLatin1StringEncoding)
		return @"iso-8859-1";
	if (e == NSUTF8StringEncoding || e == NSUnicodeStringEncoding)
		return @"iso10646-1";
	if (e == NSISOLatin2StringEncoding)
		return @"iso-8859-2";
	if (e == NSNonLossyASCIIStringEncoding || e == NSNEXTSTEPStringEncoding)
		return @"iso-8859-1";

	return @"iso10646-1";
}

+ (NSFont *) boldSystemFontOfSize:(float)fontSize
{												
	return _GetFont (@"NSBoldFont", @"Helvetica-Bold", fontSize);
}

+ (NSFont *) systemFontOfSize:(float)fontSize
{
	return _GetFont (@"NSFont", @"Helvetica", fontSize);
}

+ (NSFont *) userFixedPitchFontOfSize:(float)fontSize
{
	return _GetFont (@"NSUserFixedPitchFont", @"Courier", fontSize);
}

+ (NSFont *) userFontOfSize:(float)fontSize
{
	return _GetFont (@"NSUserFont", @"Helvetica", fontSize);
}

+ (void) setUserFixedPitchFont:(NSFont*)font		// Set preferred user fonts
{												
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName] 
										   forKey:@"NSUserFixedPitchFont"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void) setUserFont:(NSFont*)font
{
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName] 
										   forKey:@"NSUserFont"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSFont *) fontWithName:(NSString*)name size:(float)pointSize
{
	float fontMatrix[6] = { pointSize, 0, 0, pointSize, 0, 0 };

	return [NSFont fontWithName:name matrix:fontMatrix];
}

+ (NSFont *) fontWithName:(NSString *)name matrix:(const float *)fontMatrix
{												// expects family-face name
	NSString *cf = nil;							// e.g. Helvetica-Bold Oblique
	NSString *mf = nil;
	NSFont *font;
	int size = (int)fontMatrix[0];
	const char *weight = "medium";
	const char *ff = [[name lowercaseString] cString];		// family-face
	const char *p;

	if (!strcmp("helvetica", ff))
		ff = "liberation sans";
//		ff = "dejavu sans";
//		ff = "freesans";
	if (!strcmp("helvetica-bold", ff))
		ff = "liberation sans-bold",		weight = "bold";
//		ff = "dejavu sans-bold";
//		ff = "freesans-semibold";
	if (!strcmp("sans-bold", ff))
		ff = "bitstream vera sans-bold",	weight = "bold";
	if (!strcmp("courier-bold", ff))
		ff = "courier new",					weight = "bold";

	if (!strcmp("courier", ff) && (int)fontMatrix[0] == 12)
		cf = [NSString stringWithFormat:
					@"-misc-fixed-medium-r-semicondensed-*-*-120-*-*-*-*-%@",
					[self _encodingScheme]];
	else if ((p = strchr(ff, '-')))
		{
		NSString *fmt = @"-*-%s-%s-r-*-*-%d-*-*-*-*-*-*-*";
		char buf[128] = {0};
													// FIX ME parse face name
		if (strstr(ff, "italic") != NULL)
			fmt = @"-*-%s-%s-i-*-*-%d-*-*-*-*-*-*-*";
		else if (strstr(ff, "oblique") != NULL)
			fmt = @"-*-%s-%s-o-*-*-%d-*-*-*-*-*-*-*";
		strncpy(buf, ff, p-ff);
		if (strstr(p, "bold") != NULL)
			weight = "bold";
		cf = [NSString stringWithFormat: fmt, buf, weight, (int)fontMatrix[0]];
		}
	else
		cf = [NSString stringWithFormat: @"-*-%s-%s-r-*-*-%d-*-*-*-*-*-*-*",
										ff, weight, (int)fontMatrix[0]];

//	NSLog(@"** match pattern: %@\n", cf);

	if (!(mf = _NSFontMatchingPattern(cf)))
		{
		cf = @"-misc-fixed-medium-r-semicondensed-*-*-120-*-*-*-*-iso8859-1";
//		mf = FONTPATH(FONT_PREFIX/X11/misc/6x13-ISO8859-1.pcf.gz);
		if (!(mf = _NSFontMatchingPattern(cf)))
			{
			NSLog(@"Failed to open default font: %@\n", cf);
			return nil;
		}	}

//	NSLog(@"*** found: %@ size %03d, weight %c\n", mf, size, *weight);

	if ((font = _NSFontFind(mf, weight, size)) && !font->_name)
		{
		font->_name = [name copy];						// set font attr's
		font->_descriptor = [cf retain];
		memcpy (font->_matrix, fontMatrix, sizeof(font->_matrix));
		}

	return font;
}

- (void) dealloc
{
	_CGFontClose ((CGFontRef)self);
	[_name release],		_name = nil;
	[_family release],		_family = nil;
	[_display release],		_display = nil;
	[_descriptor release],	_descriptor = nil;
	[super dealloc];
}

- (void) set
{
	CGContext *cx = (CGContext *) _CGContext();

	if (self != cx->_gs->font)
		{
		CGContextSetFont((CGContextRef)cx, (CGFontRef)self);
		cx->_gs->tabSize = TABWIDTH * [self widthOfString: @"\t"];
		}
}

- (void) setInContext:(NSGraphicsContext *)gc
{
	CGContext *cx = (CGContext *) [gc graphicsPort];

	if (self != cx->_gs->font)
		{
		CGContextSetFont((CGContextRef)cx, (CGFontRef)self);
		cx->_gs->tabSize = TABWIDTH * [self widthOfString: @"\t"];
		}
}

- (float) widthOfString:(NSString*)string					// width of string
{															// using this font
	const char *cs;

	if (!string || !(*(cs = [string cString])))
		return 0;

	return _CGTextWidth((CGFont *)self, cs, strlen(cs));
}

- (float) pointSize		{ return (float)((AXFontInt *)_ftFont)->xysize / 64.0; }
- (float) leading		{ return (float)0; }
- (float) ascender		{ return ((AXFontInt *)_ftFont)->ascent; }
- (float) descender		{ return ((AXFontInt *)_ftFont)->descent; }
- (float) xHeight		{ return (float)0; } 								// x
- (float) capHeight		{ return (float)(((AXFontInt *)_ftFont)->height); } // H

- (NSString *) fontName				{ return _name; }		// Helvetica-Bold
- (NSString *) familyName			{ return _family; }		// Helvetica
- (NSString *) displayName			{ return _display; }
- (const CGFloat *) matrix			{ return _matrix; }

- (BOOL) isFixedPitch				{ return _f.isFixedPitch; }

- (NSSize) minimumAdvancement
{
	return NSZeroSize;
}

- (NSSize) maximumAdvancement
{
	return NSMakeSize((float)((AXFontInt *)_ftFont)->max_advance_width,
					  (float)(((AXFontInt *)_ftFont)->height));
}

- (NSSize) advancementForGlyph:(NSGlyph)glyph
{
	NSSize advancement = {0, 0};

	return advancement;
}
									// FIX ME s/return scaled value transformed
- (NSRect) boundingRectForFont		// by a matrix (if any) or by requested size.
{									// same for maximumAdvancement
	return NSMakeRect((float)0, (float)0,
					  (float)((AXFontInt *)_ftFont)->max_advance_width,
					  (float)(((AXFontInt *)_ftFont)->height));
}

- (float) italicAngle
{
	BDF_PropertyRec prop;
	FT_Face face = ((AXFontInt *)_ftFont)->face;
	int rc = FT_Get_BDF_Property(face, "ITALIC_ANGLE", &prop);

    if(rc == 0 && prop.type == BDF_PROPERTY_TYPE_INTEGER)
        return (float)(prop.u.integer - 64 * 90) * (TWO_SIXTEENTH / 64);

    rc = FT_Get_BDF_Property(face, "SLANT", &prop);
    if(rc == 0 && prop.type == BDF_PROPERTY_TYPE_ATOM)
        if(strcasecmp(prop.u.atom,"i") == 0 || strcasecmp(prop.u.atom,"s") == 0)
            return -30.0 * TWO_SIXTEENTH;

	return 0;
}

- (float) underlinePosition
{
	BDF_PropertyRec prop;
	FT_Face face = ((AXFontInt *)_ftFont)->face;
	int rc = FT_Get_BDF_Property(face, "UNDERLINE_POSITION", &prop);
	float up = face->available_sizes[0].height * TWO_SIXTEENTH;

	if (rc == 0 && prop.type == BDF_PROPERTY_TYPE_INTEGER)
		up = (double)prop.u.integer / up;
	else
		up = - 1.5 / up;

	return up;
}

- (float) underlineThickness
{
	BDF_PropertyRec prop;
	FT_Face face = ((AXFontInt *)_ftFont)->face;
	int rc = FT_Get_BDF_Property(face, "UNDERLINE_THICKNESS", &prop);
	float ut = face->available_sizes[0].height * TWO_SIXTEENTH;

	if (rc == 0 && prop.type == BDF_PROPERTY_TYPE_INTEGER)
		ut = (double)prop.u.integer / ut;
	else
		ut = 1.0 / ut;

	return ut;
}

- (NSStringEncoding) mostCompatibleStringEncoding
{
	return NSASCIIStringEncoding;
}

- (NSFont *) printerFont						{ return self; }
- (NSFont *) screenFont							{ return self; }
													// FIX ME glyph not font
- (NSRect) boundingRectForGlyph:(NSGlyph)aGlyph	{ return [self boundingRectForFont]; }
- (NSGlyph) glyphWithName:(NSString*)glyphName	{ return -1; }
- (BOOL) glyphIsEncoded:(NSGlyph)aGlyph			{ return YES; }	// deprecated

- (NSUInteger) numberOfGlyphs
{
	return ((AXFontInt *)_ftFont)->num_glyphs;
}

- (void) encodeWithCoder:(NSCoder *)aCoder			// NSCoding protocol
{
	[aCoder encodeObject:_name];
	[aCoder encodeArrayOfObjCType:"f" count:6 at:_matrix];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	_name = [aDecoder decodeObject];
	[aDecoder decodeArrayOfObjCType:"f" count:6 at:_matrix];

	return self;
}

@end  /* NSFont */
