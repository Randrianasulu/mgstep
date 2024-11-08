/*
   NSColor.m

   NSColor, NSColorList -- Color management classes

   Copyright (C) 2000-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSEnumerator.h>

#include <AppKit/NSColor.h>
#include <AppKit/NSColorList.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSGraphics.h>

#include <CoreGraphics/Private/_CGColor.h>


#define NCLR(x)  __ansiColors[x].c ? __ansiColors[x].c \
				: [self colorWithCalibratedRed: __ansiColors[x].r \
										 green: __ansiColors[x].g \
										  blue: __ansiColors[x].b  alpha: -1.0]

#define CLR(key)   NSColor *c = [(__systemColors ? __systemColors : \
								(__systemColors = [self _systemColors])) \
						 		colorWithKey: key]; c->_colorName = key; \
						 		c->_catalogName = @"SystemColors"; return c

struct CachedRGBColor  { float r; float g; float b; NSColor *c; };
struct CachedHSBColor  { float h; float s; float b; NSColor *c; };

struct CachedRGBColor __ansiColors[] = {
	{ 0.0, 0.0, 1.0,  nil },		// blue
	{ 0.6, 0.4, 0.2,  nil },		// brown
	{ 0.0, 1.0, 1.0,  nil },		// cyan
	{ 0.0, 1.0, 0.0,  nil },		// green
	{ 1.0, 0.0, 1.0,  nil },		// magenta
	{ 1.0, 0.5, 0.0,  nil },		// orange
	{ 0.5, 0.0, 0.5,  nil },		// purple
	{ 1.0, 0.0, 0.0,  nil },		// red
	{ 1.0, 1.0, 0.0,  nil } };		// yellow

struct CachedHSBColor __hsbColors[24] = {0};

static BOOL __ignoresAlpha = NO;
static NSColorList *__systemColors = nil;

static NSMutableArray *__availableColorLists = nil;
static NSLock *__colorListLock = nil;

const float NSWhite		= 1;		// grays
const float NSBlack		= 0;
const float NSDarkGray	= .333;
const float NSLightGray	= .667;

static NSColor *__White = nil;
static NSColor *__Black = nil;
static NSColor *__Gray = nil;
static NSColor *__DarkGray = nil;
static NSColor *__LightGray = nil;
static NSColor *__highlightColor = nil;


/* ****************************************************************************

		NSColor

** ***************************************************************************/

@implementation NSColor

+ (void) initialize
{
	__White = [NSColor colorWithCalibratedWhite:NSWhite alpha:1];
	__Black = [NSColor colorWithCalibratedWhite:NSBlack alpha:1];
	__DarkGray = [NSColor colorWithCalibratedWhite:NSDarkGray alpha:1];
	__LightGray = [NSColor colorWithCalibratedWhite:NSLightGray alpha:1];
}

+ (BOOL) ignoresAlpha					{ return __ignoresAlpha; }
+ (void) setIgnoresAlpha:(BOOL)flag		{ __ignoresAlpha = flag; }

+ (NSColor*) colorWithCalibratedHue:(float)hue
						 saturation:(float)saturation
						 brightness:(float)brightness
						 alpha:(float)alpha
{
	NSColor **p = NULL;
	NSColor *c;
	int i;

	if (alpha == 1.0)
		{
		for (i = 0; i < 24; i++)
			{
			NSColor **t = &__hsbColors[i].c;
			float h = __hsbColors[i].h;
			float s = __hsbColors[i].s;
			float b = __hsbColors[i].b;

			if (!(*t) || (hue == h && saturation == s && brightness == b))
				{
				p = &__hsbColors[i].c;
				__hsbColors[i].h = hue;
				__hsbColors[i].s = saturation;
				__hsbColors[i].b = brightness;
				break;
		}	}	}

	if (p)
		c = (*p) ? *p : (*p = [NSColor new]);
	else
		c = [[[NSColor alloc] init] autorelease];

	c->_colorspaceName = NSCalibratedRGBColorSpace;
	c->_f.hsb = YES;
	c->_c.hsb.hue = hue < 0 || hue > 1 ? 0 : hue;
	c->_c.hsb.saturation = saturation < 0 || saturation > 1 ? 0 : saturation;
	c->_c.hsb.brightness = brightness < 0 || brightness > 1 ? 0 : brightness;
	c->_alpha = alpha < 0 || alpha > 1 || __ignoresAlpha ? 1 : alpha;

	return c;
}

+ (NSColor*) colorWithDeviceHue:(float)h
		     		 saturation:(float)s
		     		 brightness:(float)b
			  		 alpha:(float)a
{
	NSColor *c;

	c = [NSColor colorWithCalibratedHue:h saturation:s	brightness:b alpha:a];
	c->_colorspaceName = NSDeviceRGBColorSpace;

	return c;
}

+ (NSColor*) colorWithCalibratedRed:(float)red
			      			  green:(float)green
			       			   blue:(float)blue
			      			  alpha:(float)alpha
{
	NSColor **p = NULL;
	NSColor *c;
	int i;

	if (alpha == -1.0)
		{
		for (i = 0; i < 9; i++)
			{
			float r = __ansiColors[i].r;
			float g = __ansiColors[i].g;
			float b = __ansiColors[i].b;

			if (red == r && green == g && blue == b)
				{
				p = &__ansiColors[i].c;
				break;
		}	}	}

	if (p)
		c = (*p) ? *p : (*p = [NSColor new]);
	else
		c = [[[NSColor alloc] init] autorelease];

	c->_colorspaceName = NSCalibratedRGBColorSpace;
	c->_f.rgb = YES;
	c->_c.rgb.red = red < 0 || red > 1 ? 0 : red;
	c->_c.rgb.green = green < 0 || green > 1 ? 0 : green;
	c->_c.rgb.blue = blue < 0 || blue > 1 ? 0 : blue;
	c->_alpha = alpha < 0 || alpha > 1 || __ignoresAlpha ? 1 : alpha;

	return c;
}

+ (NSColor*) colorWithDeviceRed:(float)r
			  			  green:(float)g
			   			  blue:(float)b
			  			  alpha:(float)a
{
	NSColor *c = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];

	c->_colorspaceName = NSDeviceRGBColorSpace;

	return c;
}

+ (NSColor*) colorWithCalibratedWhite:(float)white
								alpha:(float)alpha
{
	NSColor **p = NULL;
	NSColor *c;

	if (alpha == 1.0)
		{
		if (white == NSBlack)			p = &__Black;
		else if (white == NSWhite)		p = &__White;
		else if (white == NSLightGray)	p = &__LightGray;
		else if (white == NSDarkGray)	p = &__DarkGray;
		else if (white == 0.5)			p = &__Gray;
		}

	if (p)
		c = (*p) ? *p : (*p = [NSColor new]);
	else
		c = [[[NSColor alloc] init] autorelease];

	c->_colorspaceName = NSCalibratedWhiteColorSpace;
	c->_f.gray = YES;
	c->_c.white = white < 0 || white > 1 ? 0 : white;
	c->_alpha = alpha < 0 || alpha > 1 || __ignoresAlpha ? 1 : alpha;

	return c;
}

+ (NSColor*) colorWithDeviceWhite:(float)white alpha:(float)alpha
{
	NSColor *c = [NSColor colorWithCalibratedWhite:white alpha:alpha];

	c->_colorspaceName = NSDeviceWhiteColorSpace;

	return c;
}

+ (NSColor*) colorWithDeviceCyan:(float)cyan
						 magenta:(float)magenta
						 yellow:(float)yellow
						 black:(float)black
						 alpha:(float)alpha
{
	NSColor *c = [[[NSColor alloc] init] autorelease];

	c->_colorspaceName = NSDeviceCMYKColorSpace;
	c->_c.cmyk.cyan = cyan < 0 || cyan > 1 ? 0 : cyan;
	c->_c.cmyk.magenta = magenta < 0 || magenta > 1 ? 0 : magenta;
	c->_c.cmyk.yellow = yellow < 0 || yellow > 1 ? 0 : yellow;
	c->_c.cmyk.black = black < 0 || black > 1 ? 0 : black;
	c->_alpha = alpha < 0 || alpha > 1 || __ignoresAlpha ? 1 : alpha;

	return c;
}

+ (NSColor*) blackColor					{ return __Black; }
+ (NSColor*) whiteColor					{ return __White; }
+ (NSColor*) darkGrayColor				{ return __DarkGray; }
+ (NSColor*) lightGrayColor				{ return __LightGray; }

+ (NSColor*) grayColor
{
	return [self colorWithCalibratedWhite: 0.5 alpha: 1.0];
}

+ (NSColor*) clearColor
{
	return [self colorWithCalibratedWhite:0 alpha:0];
}

+ (NSColor*) blueColor					{ return NCLR(0); }
+ (NSColor*) brownColor					{ return NCLR(1); }
+ (NSColor*) cyanColor					{ return NCLR(2); }
+ (NSColor*) greenColor					{ return NCLR(3); }
+ (NSColor*) magentaColor				{ return NCLR(4); }
+ (NSColor*) orangeColor				{ return NCLR(5); }
+ (NSColor*) purpleColor				{ return NCLR(6); }
+ (NSColor*) redColor					{ return NCLR(7); }
+ (NSColor*) yellowColor				{ return NCLR(8); }

+ (NSColorList*) _systemColors
{
	return [[NSColorList alloc] initWithName:@"SystemColors"];
}

+ (NSColor*) highlightColor
{												// avoid generating sys colors
	if (!__highlightColor && !__systemColors)	// for default highlight color
		__highlightColor = [[NSColor colorWithCalibratedRed:(float)0x1f / 256
													  green:(float)0x1f / 256
													   blue:0.
													  alpha:1.] retain];

	return __systemColors ? [__systemColors colorWithKey:@"highlightColor"]
						  : __highlightColor;
}

+ (NSColor*) controlBackgroundColor		{ CLR(@"controlBackgroundColor"); }
+ (NSColor*) controlColor				{ CLR(@"controlColor"); }
+ (NSColor*) controlHighlightColor		{ CLR(@"controlHighlightColor"); }
+ (NSColor*) controlLightHighlightColor	{ CLR(@"controlLightHighlightColor"); }
+ (NSColor*) controlShadowColor			{ CLR(@"controlShadowColor"); }
+ (NSColor*) controlDarkShadowColor		{ CLR(@"controlDarkShadowColor"); }
+ (NSColor*) controlTextColor			{ CLR(@"controlTextColor"); }
+ (NSColor*) disabledControlTextColor	{ CLR(@"disabledControlTextColor"); }
+ (NSColor*) gridColor					{ CLR(@"gridColor"); }
+ (NSColor*) knobColor					{ CLR(@"knobColor"); }
+ (NSColor*) scrollBarColor				{ CLR(@"scrollBarColor"); }
+ (NSColor*) selectedControlColor		{ CLR(@"selectedControlColor"); }
+ (NSColor*) selectedControlTextColor	{ CLR(@"selectedControlTextColor"); }
+ (NSColor*) selectedMenuItemColor		{ CLR(@"selectedMenuItemColor"); }
+ (NSColor*) selectedMenuItemTextColor	{ CLR(@"selectedMenuItemTextColor"); }
+ (NSColor*)selectedTextBackgroundColor { CLR(@"selectedTextBackgroundColor");}
+ (NSColor*) selectedTextColor			{ CLR(@"selectedTextColor"); }
+ (NSColor*) selectedKnobColor			{ CLR(@"selectedKnobColor"); }
+ (NSColor*) shadowColor				{ CLR(@"shadowColor"); }
+ (NSColor*) textBackgroundColor		{ CLR(@"textBackgroundColor"); }
+ (NSColor*) textColor					{ CLR(@"textColor"); }
+ (NSColor*) windowFrameColor			{ CLR(@"windowFrameColor"); }
+ (NSColor*) windowFrameTextColor		{ CLR(@"windowFrameTextColor"); }
+ (NSColor*) headerColor				{ CLR(@"headerColor"); }
+ (NSColor*) headerTextColor			{ CLR(@"headerTextColor"); }

+ (NSColor*) colorWithCatalogName:(NSString*)listName colorName:(NSString*)key
{
	return [[NSColorList colorListNamed: listName] colorWithKey: key];
}

+ (NSColor*) colorFromPasteboard:(NSPasteboard*)pasteBoard
{															
	NSData *d = [pasteBoard dataForType: NSColorPboardType];	// Copy/Paste

	return (d) ? [NSUnarchiver unarchiveObjectWithData: d] : nil;
}

- (void) dealloc
{
	[_colorspaceName release];
	[_catalogName release];
	[_colorName release];
	[super dealloc];
}

- (id) copy								{ return [self retain]; }

- (void) set							{ SUBCLASS }
- (void) setFill						{ SUBCLASS }
- (void) setStroke						{ SUBCLASS }

- (void) drawSwatchInRect:(NSRect)rect	
{
	[self set];
	NSRectFill(rect);
}

- (NSString*) description
{
	NSMutableString	*s;

	NSAssert(_colorspaceName != nil, NSInternalInconsistencyException);
											// simple RGB color without alpha
	if (_colorspaceName == NSCalibratedRGBColorSpace && _alpha == 1.0)
    	return [NSString stringWithFormat: @"\"%f %f %f\"",
							_c.rgb.red, _c.rgb.green, _c.rgb.blue];
 
								// property list dictionary for other colors
	s = [NSMutableString stringWithCapacity: 128];
	[s appendFormat: @"{ ColorSpace = \"%@\";", _colorspaceName];

	if (_colorspaceName == NSDeviceWhiteColorSpace
			|| (_colorspaceName == NSCalibratedWhiteColorSpace)
			|| (_colorspaceName == NSDeviceBlackColorSpace)
			|| (_colorspaceName == NSCalibratedBlackColorSpace))
      	[s appendFormat: @" W = \"%f\";", _c.white];

	if (_colorspaceName == NSCalibratedRGBColorSpace
			|| (_colorspaceName == NSDeviceRGBColorSpace))
		{
		if (_f.hsb)
			{
			[s appendFormat: @" H = \"%f\";", _c.hsb.hue];
			[s appendFormat: @" S = \"%f\";", _c.hsb.saturation];
			[s appendFormat: @" B = \"%f\";", _c.hsb.brightness];
			}
		else
			{
			[s appendFormat: @" R = \"%f\";", _c.rgb.red];
			[s appendFormat: @" G = \"%f\";", _c.rgb.green];
			[s appendFormat: @" B = \"%f\";", _c.rgb.blue];
		}	}

	if (_colorspaceName == NSDeviceCMYKColorSpace)
		{
		[s appendFormat: @" C = \"%f\";", _c.cmyk.cyan];
		[s appendFormat: @" M = \"%f\";", _c.cmyk.magenta];
		[s appendFormat: @" Y = \"%f\";", _c.cmyk.yellow];
		[s appendFormat: @" K = \"%f\";", _c.cmyk.black];
		}

	if (_colorspaceName == NSNamedColorSpace)
		{
		[s appendFormat: @" Catalog = \"%@\";", _catalogName];
		[s appendFormat: @" Color = \"%@\";", _colorName];
		}

	[s appendFormat: @" Alpha = \"%f\"; }", _alpha];

	return s;
}

- (void) getCyan:(float*)c
		 magenta:(float*)m
	 	 yellow:(float*)y
	  	 black:(float*)b				// getting components not in current
	  	 alpha:(float*)a				// colorspace returns undefined values
{
	if (c)	*c = _c.cmyk.cyan;
	if (m)	*m = _c.cmyk.magenta;
	if (y)	*y = _c.cmyk.yellow;
	if (b)	*b = _c.cmyk.black;
	if (a)	*a = _alpha;
}

- (void) getHue:(float*)h
		 saturation:(float*)s
		 brightness:(float*)b
		 alpha:(float*)a
{
	if (h)	*h = _c.hsb.hue;
	if (s)	*s = _c.hsb.saturation;
	if (b)	*b = _c.hsb.brightness;
	if (a)	*a = _alpha;
}

- (void) getRed:(float*)r green:(float*)g blue:(float*)b alpha:(float*)a
{
	if (r)	*r = _c.rgb.red;
	if (g)	*g = _c.rgb.green;
	if (b)	*b = _c.rgb.blue;
	if (a)	*a = _alpha;
}

- (void) getWhite:(float*)white alpha:(float*)alpha
{
	if (white)	*white = _c.white;
	if (alpha)	*alpha = _alpha;
}
														// Access Components
- (float) alphaComponent				{ return _alpha; }
- (float) whiteComponent				{ return _c.white; }
- (float) cyanComponent					{ return _c.cmyk.cyan; }
- (float) magentaComponent				{ return _c.cmyk.magenta; }
- (float) yellowComponent				{ return _c.cmyk.yellow; }
- (float) blackComponent				{ return _c.cmyk.black; }
- (float) redComponent					{ return _c.rgb.red; }
- (float) greenComponent				{ return _c.rgb.green; }
- (float) blueComponent					{ return _c.rgb.blue; }
- (float) hueComponent					{ return _c.hsb.hue; }
- (float) saturationComponent			{ return _c.hsb.saturation; }
- (float) brightnessComponent			{ return _c.hsb.brightness; }
- (NSString*) catalogNameComponent		{ return _catalogName; }
- (NSString*) colorNameComponent		{ return _colorName; }
- (NSString*) colorSpaceName			{ return _colorspaceName; }

- (NSColor*) colorUsingColorSpaceName:(NSString*)colorSpace
{		
	if (colorSpace == nil)								// Convert color spaces 
		colorSpace = NSCalibratedRGBColorSpace;

	if ([colorSpace isEqualToString: _colorspaceName])
		return self;

	if (_colorspaceName == NSNamedColorSpace
			|| _colorspaceName == NSCustomColorSpace)
		return nil;

	if ([colorSpace isEqualToString: NSCalibratedRGBColorSpace]
			|| [colorSpace isEqualToString: NSDeviceRGBColorSpace])
		{
		NSColor	*c;												
		float r, g, b;

		if (_colorspaceName == NSCalibratedRGBColorSpace
				|| _colorspaceName == NSDeviceRGBColorSpace)
			return self;

		if (_colorspaceName == NSDeviceCMYKColorSpace)		// Convert to RGB
			{
			if (_c.cmyk.black == 0)								// CMYK to RGB
				{
				r = 1 - _c.cmyk.cyan;
				g = 1 - _c.cmyk.magenta;
				b = 1 - _c.cmyk.yellow;
				}
			else if (_c.cmyk.black == 1)
				r = g = b = 0;
			else
				{
				double l = _c.cmyk.cyan;
				double m = _c.cmyk.magenta;
				double y = _c.cmyk.yellow;
				double white = 1 - _c.cmyk.black;
	
				r = (l > white ? 0 : white - l);
				g = (m > white ? 0 : white - m);
				b = (y > white ? 0 : white - y);
			}	}
																// White to RGB
		if ((_colorspaceName == NSCalibratedWhiteColorSpace)
				|| (_colorspaceName == NSDeviceWhiteColorSpace)
				|| (_colorspaceName == NSDeviceBlackColorSpace)
				|| (_colorspaceName == NSCalibratedBlackColorSpace))
			r = g = b = _c.white;

	  	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1];
		}

	if ([colorSpace isEqualToString: NSCalibratedWhiteColorSpace]
			|| [colorSpace isEqualToString: NSDeviceWhiteColorSpace])
		{
		NSColor	*c;
		float w;

		if (_colorspaceName == NSCalibratedWhiteColorSpace
				|| _colorspaceName == NSDeviceWhiteColorSpace)
			return self;

		if ((_colorspaceName == NSCalibratedRGBColorSpace)	// Convert to white
				|| (_colorspaceName == NSDeviceRGBColorSpace))
			{													// RGB to white
			struct RGB_Color rgb;

			if (!_f.rgb)
				{
				_CGColorConvertHSBtoRGB(_c.hsb, &rgb);
				_f.rgb = YES;
				}
			w = (rgb.red + rgb.green + rgb.blue) / 3;
			}

		if ((_colorspaceName == NSCalibratedBlackColorSpace)	// black to wht
				|| (_colorspaceName == NSDeviceBlackColorSpace))
			w = 1 - _c.white;

		if (_colorspaceName == NSDeviceCMYKColorSpace)			// CMYK to wht
			{
			c = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			w = (c->_c.rgb.red + c->_c.rgb.green + c->_c.rgb.blue) / 3;
			}

	  	return [NSColor colorWithCalibratedWhite:w alpha:1];
		}

	if ([colorSpace isEqualToString: NSCalibratedBlackColorSpace]
			|| [colorSpace isEqualToString: NSDeviceBlackColorSpace])
		{
		NSColor	*c;

		if (_colorspaceName == NSCalibratedBlackColorSpace
				|| _colorspaceName == NSDeviceBlackColorSpace)
			return self;

		c = [self colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
													// return cached if exists
	  	return [NSColor colorWithCalibratedWhite:(1 - c->_c.white) alpha:1];
		}
													// FIX ME convert to CMYK
//	if ([colorSpace isEqualToString: NSDeviceCMYKColorSpace])

	return nil;
}

- (NSColor*) blendedColorWithFraction:(float)fraction
							  ofColor:(NSColor*)aColor
{
	NSColor	*color = self;									// Color Blending
	NSColor	*other = aColor;
	float mr, mg, mb, or, og, ob, r, g, b;

	if ((_colorspaceName != NSCalibratedRGBColorSpace)
			&& (_colorspaceName != NSDeviceRGBColorSpace))
		color = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	if ((aColor->_colorspaceName != NSCalibratedRGBColorSpace)
			&& (aColor->_colorspaceName != NSDeviceRGBColorSpace))
		other = [aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	if (color == nil || other == nil)
		return nil;

	[color getRed: &mr green: &mg blue: &mb alpha: 0];
	[other getRed: &or green: &og blue: &ob alpha: 0];
	r = fraction * mr + (1 - fraction) * or;
	g = fraction * mg + (1 - fraction) * og;
	b = fraction * mb + (1 - fraction) * ob;

	return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 0];
}

- (NSColor*) colorWithAlphaComponent:(float)alpha
{
	NSColor *c = [self colorUsingColorSpaceName:_colorspaceName];

	c->_alpha = alpha < 0 || alpha > 1 ? 0 : alpha;

	return self;
}

- (NSColor*) highlightWithLevel:(float)level
{
	return [self blendedColorWithFraction: level 
				 ofColor: [NSColor highlightColor]];
}

- (NSColor*) shadowWithLevel:(float)level
{
	return [self blendedColorWithFraction:level ofColor:[NSColor shadowColor]];
}

- (void) writeToPasteboard:(NSPasteboard*)pasteBoard	// Copy / Paste
{
	NSData *d = [NSArchiver archivedDataWithRootObject: self];

	if (d)
		[pasteBoard setData: d forType: NSColorPboardType];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{																
	[aCoder encodeValueOfObjCType: "f" at: &_c.rgb.red];
	[aCoder encodeValueOfObjCType: "f" at: &_c.rgb.green];
	[aCoder encodeValueOfObjCType: "f" at: &_c.rgb.blue];
	[aCoder encodeValueOfObjCType: "f" at: &_c.cmyk.black];	// 4th component of
	[aCoder encodeValueOfObjCType: "f" at: &_alpha];		// union
	[aCoder encodeObject: _colorspaceName];
	[aCoder encodeObject: _catalogName];
	[aCoder encodeObject: _colorName];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_f];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[aDecoder decodeValueOfObjCType: "f" at: &_c.rgb.red];
	[aDecoder decodeValueOfObjCType: "f" at: &_c.rgb.green];
	[aDecoder decodeValueOfObjCType: "f" at: &_c.rgb.blue];
	[aDecoder decodeValueOfObjCType: "f" at: &_c.cmyk.black];
	[aDecoder decodeValueOfObjCType: "f" at: &_alpha];
	_colorspaceName = [aDecoder decodeObject];
	_catalogName = [aDecoder decodeObject];
	_colorName = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_f];

	return self;
}

@end /* NSColor */

/* ****************************************************************************

		NSColorList

** ***************************************************************************/

@implementation NSColorList

+ (void) initialize
{
	if (!__colorListLock)
		__colorListLock = [[NSLock alloc] init];
	if (!__availableColorLists)
		__availableColorLists = [NSMutableArray new];	// color lists array
}

+ (NSArray *) availableColorLists
{
	NSArray *a;

	[__colorListLock lock];								// serialize access
	a = [[[NSArray alloc] initWithArray: __availableColorLists] autorelease];
	[__colorListLock unlock];

	return a;
}

+ (NSColorList *) colorListNamed:(NSString*)name
{
	NSEnumerator *e = [__availableColorLists objectEnumerator];
	NSColorList *cl;
	
	while ((cl = [e nextObject]) != nil)
		if ([[cl name] isEqualToString: name])
			break;

	return cl;
}

- (void) _systemColorsDidChange:(NSNotification*)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *sc;
	NSString *key;

	if ((sc = [defaults objectForKey: @"SystemColors"]))
		{
		NSEnumerator *e = [_colorList keyEnumerator];
													// for any color in the DDB
		while ((key = [e nextObject]) != nil)		// check if current string
			{										// value differs from old.
			NSString *cs = [defaults stringForKey: key];
													// update color list if
			if (cs != nil)							// colors differ
				{
				NSString *old = [_colorList objectForKey: key];
		
				if ([cs isEqualToString: old] == NO)
					{								// DDB differs from old val
					[self removeColorWithKey:key];
					[_colorList setObject:cs forKey:key];
		}	}	}	}
}

- (id) initWithName:(NSString*)name fromFile:(NSString*)path
{
	if ((self = [super init]))			// name s/b file w/o '.clr' extension
		{								// absolute path or nil if Defaults DB
		_name = [name retain];

		if ((_fileName = [path retain]))
			_colorList = [NSUnarchiver unarchiveObjectWithFile:_fileName];
		else if (!__systemColors && [name isEqualToString: @"SystemColors"])
			{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			NSString *white = 	  @"1.0 1.0 1.0";
			NSString *lightGray = @".667 .667 .667";
			NSString *darkGray =  @".333 .333 .333";
			NSString *black =	  @"0.0 0.0 0.0";
			NSString *highlight = @".1215 .1215 0.0";

			_colorList = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
								darkGray,	@"controlBackgroundColor",
								lightGray,	@"controlColor",
								lightGray,	@"controlHighlightColor",
								white,		@"controlLightHighlightColor",
								darkGray,	@"controlShadowColor",
								black,		@"controlDarkShadowColor",
								black,		@"controlTextColor",
								darkGray,	@"disabledControlTextColor",
								darkGray,	@"gridColor",
								highlight,	@"highlightColor",
								lightGray,	@"knobColor",
								lightGray,	@"scrollBarColor",
								lightGray,	@"selectedControlColor",
								black,		@"selectedControlTextColor",
								white,		@"selectedMenuItemColor",
								black,		@"selectedMenuItemTextColor",
								lightGray,	@"selectedTextBackgroundColor",
								black,		@"selectedTextColor",
								lightGray,	@"selectedKnobColor",
								black,		@"shadowColor",
								white,		@"textBackgroundColor",
								black,		@"textColor",
								black,		@"windowFrameColor",
								white,		@"windowFrameTextColor",
								white,		@"headerColor",
								black,		@"headerTextColor",
								nil] retain];		// default system colors

			[nc addObserver: self
				selector: @selector(_systemColorsDidChange:)
				name: NSUserDefaultsDidChangeNotification
				object: nil];
			}
		else
			_colorList = [[NSMutableDictionary alloc] init];

		_cl.editable = YES;
		_keyArray = [[NSMutableArray alloc] init];
		_colorArray = [[NSMutableArray alloc] init];

		[__colorListLock lock];
		[__availableColorLists  addObject: self];		// add to global list
		[__colorListLock unlock];
		}

	return self;
}

- (id) initWithName:(NSString*)name
{
	return [self initWithName:name fromFile:nil];
}

- (void) dealloc
{
	[_name release];
	[_colorList release];
	[_keyArray release];
	[_colorArray release];
	[super dealloc];
}

- (NSString *) name							{ return _name; }
- (BOOL) isEditable							{ return _cl.editable; }

- (NSArray *) allKeys
{
	return [[[NSArray alloc] initWithArray: _keyArray] autorelease];
}

- (NSColor *) colorWithKey:(NSString*)key
{
	NSUInteger i;
	NSString *rep;
	NSColor	*c = nil;

	if ((i = [_keyArray indexOfObject: key]) != NSNotFound)
		return [_colorArray objectAtIndex: i];

	if ((rep = [_colorList objectForKey: key]) == nil)
		NSLog(@"Request for unknown system color - '%@'\n", key);
	else
		{
		const char *str = [rep cString];
		float r, g, b;

		if (sscanf(str, "%f %f %f", &r, &g, &b) != 3)
			NSLog(@"System color '%@' has bad string rep: '%@'\n", key, rep);
		else
			if ((c = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1]))
				[self setColor:c forKey:key];
		}

	return c;
}

- (void) insertColor:(NSColor*)color
				 key:(NSString*)key
				 atIndex:(unsigned)location
{
	NSUInteger i;

	if (!_cl.editable)								// Are we even editable?
		[NSException raise: NSColorListNotEditableException
					 format: @"Color list cannot be edited\n"];

	[self removeColorWithKey: key];

	[_keyArray insertObject: key atIndex: location];
	[_colorArray insertObject: key atIndex: location];
	[_colorList setObject: [color description] forKey: key];	// add color

	[NSNotificationCenter post:NSColorListDidChangeNotification object:self];
}

- (void) removeColorWithKey:(NSString*)key
{
	NSUInteger i;

	if (!_cl.editable)
		[NSException raise: NSColorListNotEditableException
					 format: @"Color list cannot be edited\n"];

	[_colorList removeObjectForKey: key];		// FIX ME warn if bad key

	if ((i = [_keyArray indexOfObject: key]) != NSNotFound)
		{
		[_colorArray removeObjectAtIndex: i];
		[_keyArray removeObject: key];
		}
														   // post notification
	[NSNotificationCenter post:NSColorListDidChangeNotification object:self];
}

- (void) setColor:(NSColor*)aColor forKey:(NSString*)key
{
	NSUInteger i;

	if (!_cl.editable)
		[NSException raise: NSColorListNotEditableException
					 format: @"Color list cannot be edited\n"];

	if ((i = [_keyArray indexOfObject: key]) != NSNotFound)
		{
		[_colorArray replaceObjectAtIndex: i withObject: aColor];
		[_colorList setObject: [aColor description] forKey: key];

		[NSNotificationCenter post:NSColorListDidChangeNotification object:self];
		}
	else
		{
		[_keyArray addObject: key];
		[_colorArray addObject: aColor];
		}
}

- (BOOL) writeToFile:(NSString*)path					// FIX ME not to spec
{														// Archive to the file
	return [NSArchiver archiveRootObject:self toFile:path];
}

- (void) removeFile
{								// FIX ME Tell NSWorkspace to remove the file
	[__colorListLock lock];								// Remove from global
	[__availableColorLists  removeObject: self];			// list of colors
	[__colorListLock  unlock];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeObject: _name];
	[aCoder encodeObject: _colorList];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	_name = [aDecoder decodeObject];
	_colorList = [aDecoder decodeObject];

	return self;
}

@end /* NSColorList */


NSString *
NSColorSpaceFromDepth(NSWindowDepth depth)
{
	return depth > 8 ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace;
}

int 
NSNumberOfColorComponents(NSString *colorSpace)
{
	if ([colorSpace isEqualToString: NSCalibratedRGBColorSpace]
			|| [colorSpace isEqualToString: NSDeviceRGBColorSpace])
		return 3;
	if ([colorSpace isEqualToString: NSDeviceCMYKColorSpace])
		return 4;
	
	return 1;
}

BOOL 
NSPlanarFromDepth(NSWindowDepth depth)
{
	return depth > 8 ? YES : NO;
}
