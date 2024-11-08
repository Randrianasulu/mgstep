/*
   NSColor.h

   Color class interface

   Copyright (C) 2000-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSColor
#define _mGSTEP_H_NSColor

#include <Foundation/NSCoder.h>
#include <CoreGraphics/CGColor.h>

@class NSArray;
@class NSImage;
@class NSString;
@class NSDictionary;
@class NSPasteboard;


struct Gray_Color {
	float white;
} gray;

struct RGB_Color {
	float red;
	float green;
	float blue;
} rgb;

struct HSB_Color {
	float hue;
	float saturation;
	float brightness;
} hsb;

struct CMYK_Color {
	float cyan;
	float magenta;
	float yellow;
	float black;
} cmyk;


@interface NSColor : NSObject  <NSCoding, NSCopying>
{
	NSString *_colorName;
	NSString *_catalogName;
	NSString *_colorspaceName;

	void *pattern;

	union _Color {
		struct {
			float red;
			float green;
			float blue;
		};
		float white;
		float components[4];
		struct RGB_Color rgb;
		struct HSB_Color hsb;
		struct CMYK_Color cmyk;
	} _c;

	float _alpha;

	unsigned short _red;
	unsigned short _green;
	unsigned short _blue;

	struct __ColorFlags {
		unsigned int rgb:1;
		unsigned int hsb:1;
		unsigned int cmyk:1;
		unsigned int gray:1;
		unsigned int xcolor:1;
		unsigned int pattern:1;
		unsigned int reserved:2;
	} _f;
}

+ (NSColor *) colorWithCalibratedWhite:(float)white alpha:(float)alpha;
+ (NSColor *) colorWithDeviceWhite:(float)white alpha:(float)alpha;

+ (NSColor *) colorWithCalibratedRed:(float)red
							   green:(float)green
							    blue:(float)blue
							   alpha:(float)alpha;

+ (NSColor *) colorWithDeviceRed:(float)red
						   green:(float)green
						    blue:(float)blue
						   alpha:(float)alpha;

+ (NSColor *) colorWithCalibratedHue:(float)hue
						  saturation:(float)saturation
						  brightness:(float)brightness
						       alpha:(float)alpha;

+ (NSColor *) colorWithDeviceHue:(float)hue
					  saturation:(float)saturation
					  brightness:(float)brightness
					       alpha:(float)alpha;

+ (NSColor *) colorWithDeviceCyan:(float)cyan
						  magenta:(float)magenta
						   yellow:(float)yellow
						    black:(float)black
						    alpha:(float)alpha;

+ (NSColor *) blackColor;								// Named colors
+ (NSColor *) whiteColor;
+ (NSColor *) grayColor;
+ (NSColor *) darkGrayColor;
+ (NSColor *) lightGrayColor;

+ (NSColor *) blueColor;
+ (NSColor *) brownColor;
+ (NSColor *) clearColor;
+ (NSColor *) cyanColor;
+ (NSColor *) greenColor;
+ (NSColor *) magentaColor;
+ (NSColor *) orangeColor;
+ (NSColor *) purpleColor;
+ (NSColor *) redColor;
+ (NSColor *) yellowColor;

+ (NSColor *) controlBackgroundColor;					// System colors
+ (NSColor *) controlColor;
+ (NSColor *) controlHighlightColor;
+ (NSColor *) controlLightHighlightColor;
+ (NSColor *) controlShadowColor;
+ (NSColor *) controlDarkShadowColor;
+ (NSColor *) controlTextColor;
+ (NSColor *) disabledControlTextColor;
+ (NSColor *) gridColor;
+ (NSColor *) highlightColor;
+ (NSColor *) knobColor;
+ (NSColor *) scrollBarColor;
+ (NSColor *) selectedControlColor;
+ (NSColor *) selectedControlTextColor;
+ (NSColor *) selectedMenuItemColor;
+ (NSColor *) selectedMenuItemTextColor;
+ (NSColor *) selectedTextBackgroundColor;
+ (NSColor *) selectedTextColor;
+ (NSColor *) selectedKnobColor;
+ (NSColor *) shadowColor;
+ (NSColor *) textBackgroundColor;
+ (NSColor *) textColor;
+ (NSColor *) windowFrameColor;
+ (NSColor *) windowFrameTextColor;
+ (NSColor *) headerColor;								// Table/OutlineView
+ (NSColor *) headerTextColor;

+ (NSColor *) colorWithCatalogName:(NSString *)listName	  // Pantone ...etc
						 colorName:(NSString *)colorName;
+ (NSColor *) colorFromPasteboard:(NSPasteboard *)pb;

+ (BOOL) ignoresAlpha;									// global alpha
+ (void) setIgnoresAlpha:(BOOL)flag;

- (void) getCyan:(float *)cyan							// get components
		 magenta:(float *)magenta
		 yellow:(float *)yellow
		 black:(float *)black
		 alpha:(float *)alpha;
- (void) getHue:(float *)hue
		 saturation:(float *)saturation
    	 brightness:(float *)brightness
		 alpha:(float *)alpha;
- (void) getRed:(float *)red
		 green:(float *)green
		 blue:(float *)blue
		 alpha:(float *)alpha;
- (void) getWhite:(float *)white alpha:(float *)alpha;

- (float) alphaComponent;								// access components
- (float) blackComponent;
- (float) blueComponent;
- (float) brightnessComponent;
- (float) cyanComponent;
- (float) greenComponent;
- (float) hueComponent;
- (float) magentaComponent;
- (float) redComponent;
- (float) saturationComponent;
- (float) whiteComponent;
- (float) yellowComponent;

- (NSString *) catalogNameComponent;
- (NSString *) colorNameComponent;
- (NSString *) colorSpaceName;
														// convert color Space
- (NSColor *) colorUsingColorSpaceName:(NSString *)colorSpace;

- (void) writeToPasteboard:(NSPasteboard *)pasteBoard;	// copy / paste

- (void) drawSwatchInRect:(NSRect)rect;

- (void) setStroke;										// set draw color in gc
- (void) setFill;
- (void) set;											// set fill & stroke

- (NSColor *) blendedColorWithFraction:(float)fraction ofColor:(NSColor *)c;
- (NSColor *) colorWithAlphaComponent:(float)alpha;
- (NSColor *) highlightWithLevel:(float)level;
- (NSColor *) shadowWithLevel:(float)level;

@end


extern NSString	*NSSystemColorsDidChangeNotification;


@interface NSColor (NotImplemented)

- (NSString *) localizedCatalogNameComponent;
- (NSString *) localizedColorNameComponent;

//- (NSColor *) colorUsingColorSpace:(NSColorSpace *)space;
- (NSColor *) colorUsingColorSpaceName:(NSString *)colorSpace
								device:(NSDictionary *)description;

+ (NSColor *) keyboardFocusIndicatorColor;
+ (NSColor *) alternateSelectedControlColor;
+ (NSColor *) alternateSelectedControlTextColor;
+ (NSArray *) controlAlternatingRowBackgroundColors;

+ (NSColor *) colorWithPatternImage:(NSImage *)image;
- (NSImage *) patternImage;

@end


#ifndef __cplusplus
typedef struct _NSColor  { @defs(NSColor); } CGColor;
#endif


#endif /* _mGSTEP_H_NSColor */
