/*
   CGColor.m

   mini Core Graphics color functions

   Copyright (C) 2006-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CFRuntime.h>

#include <AppKit/NSColor.h>


#define CTX				((CGContext *)cx)
#define COLOR			CTX->_gs->stroke.color
#define COLOR_FILL		CTX->_gs->fill.color
#define GSTATE			CTX->_gs

#define XDISPLAY		CTX->_display->xDisplay
#define XCOLORMAP		CTX->_display->_colormap
#define XVISUAL			CTX->_display->_visual
#define XGC				CTX->_gs->xGC


/* ****************************************************************************

		CG ColorSpace -- FIX ME psuedo implementation

** ***************************************************************************/

static const CFRuntimeClass __CGColorSpaceClass = {
	_CF_VERSION,
	"CGColorSpace",
	NULL
};

const CFStringRef kCGColorSpaceGenericGray = (CFStringRef) @"GenericGray";
const CFStringRef kCGColorSpaceGenericRGB = (CFStringRef) @"GenericRGB";
const CFStringRef kCGColorSpaceGenericRGBLinear = (CFStringRef) @"LinearRGB";

static CGColorSpaceRef __colorSpaceRGB = NULL;
static CGColorSpaceRef __colorSpaceGray = NULL;

void _CGColorSpaceInitDeviceRGB(CGColorSpace *);


CGColorSpaceRef
CGColorSpaceCreateDeviceRGB(void)
{
	if (!__colorSpaceRGB)
		{
		__colorSpaceRGB = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		_CGColorSpaceInitDeviceRGB((CGColorSpace *)__colorSpaceRGB);
		}

	return __colorSpaceRGB;
}

CGColorSpaceRef
CGColorSpaceCreateDeviceGray(void)
{
	if (!__colorSpaceGray)
		__colorSpaceGray = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);

	return __colorSpaceGray;
}

CGColorSpaceRef
CGColorSpaceCreateWithName(CFStringRef name)
{
	CGColorSpace *cs;

	if (name == kCGColorSpaceGenericRGB && __colorSpaceRGB)
		return __colorSpaceRGB;

	cs = CFAllocatorAllocate(NULL, sizeof(CGColorSpace), 0);
	cs->name = CFRetain(name);

	if (name == kCGColorSpaceGenericRGB || name == kCGColorSpaceGenericRGBLinear)
		cs->model = kCGColorSpaceModelRGB;
	else if (name == kCGColorSpaceGenericGray)
		cs->model = kCGColorSpaceModelMonochrome;
	else if (name == (CFStringRef)@"ColorPatternSpace")
		cs->model = kCGColorSpaceModelPattern;
	else
		cs->model = kCGColorSpaceModelUnknown;

	return (CGColorSpaceRef)cs;
}

CGColorSpaceModel
CGColorSpaceGetModel(CGColorSpaceRef s)
{
	return ((CGColorSpace *)s)->model;
}

CFStringRef
CGColorSpaceCopyName(CGColorSpaceRef s)
{
	return ((CGColorSpace *)s)->name;
}

CGColorSpaceRef
CGolorSpaceRetain(CGColorSpaceRef cs)
{
	return (cs) ? (CGColorSpaceRef)CFRetain(cs) : cs;
}

void
CGColorSpaceRelease(CGColorSpaceRef cs)
{
	if (cs && cs != __colorSpaceRGB && cs != __colorSpaceGray)
		CFRelease(cs);
}

size_t
CGColorSpaceGetNumberOfComponents (CGColorSpaceRef cs)
{
	if (((CGColorSpace *)cs)->name == kCGColorSpaceGenericRGB
			|| ((CGColorSpace *)cs)->name == kCGColorSpaceGenericRGBLinear)
		return 3;
		
	return 1;		// CGColorSpaceCreateDeviceGray
}

CGColorSpaceRef
CGColorSpaceCreatePattern(CGColorSpaceRef baseSpace)
{
	if (!baseSpace)
		return CGColorSpaceCreateWithName((CFStringRef)@"ColorPatternSpace");

	return CGColorSpaceCreateWithName(((CGColorSpace *)baseSpace)->name);
}

#ifdef FB_GRAPHICS  /* ****************************************** ColorSpace */

void _CGColorSpaceInitDeviceRGB(CGColorSpace *cs)		// RGB pixel order
{
	cs->_red = 0;
	cs->_green = 8;
	cs->_blue = 16;
}

#else

void _CGColorSpaceInitDeviceRGB(CGColorSpace *cs)		// BGR pixel order
{
	CGContextRef cx = _CGContext();

	while (XVISUAL->blue_mask >> cs->_blue + 8)    cs->_blue++;
	while (XVISUAL->green_mask >> cs->_green + 8)  cs->_green++;
	while (XVISUAL->red_mask >> cs->_red + 8)      cs->_red++;
}

#endif  /* !FB_GRAPHICS  **************************************** ColorSpace */

/* ****************************************************************************

		CG Color  (bridged to NSColor)

** ***************************************************************************/

CGColorRef
CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat alpha)
{
	CGColorSpace *cs = ((CGColorSpace*)CGColorSpaceCreateDeviceRGB());
//	NSColor *c = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
	CGColor *c = (CGColor *)[NSColor alloc];
	
	c->_colorspaceName = (NSString*)cs->name;
	c->_c.red   = r;
	c->_c.green = g;
	c->_c.blue  = b;
	c->_alpha   = alpha;
	c->_f.rgb = YES;

	return (CGColorRef)c;
}

CGColorRef
CGColorCreateGenericGray(CGFloat gray, CGFloat alpha)
{
	CGColorSpace *cs = ((CGColorSpace*)CGColorSpaceCreateDeviceGray());
	CGColor *c = (CGColor *)[NSColor alloc];
	
	c->_colorspaceName = (NSString*)cs->name;
	c->_c.white = gray;
	c->_alpha = alpha;
	c->_f.gray = YES;

	return (CGColorRef)c;
}

CGColorRef CGColorCreate(CGColorSpaceRef s, const CGFloat cpt[])
{
	if (CGColorSpaceGetNumberOfComponents(s) == 3)	// FIX ME must retain space
		return CGColorCreateGenericRGB(cpt[0], cpt[1], cpt[2], cpt[3]);

	return CGColorCreateGenericGray(cpt[0], cpt[1]);
}

void CGColorRelease(CGColorRef color)
{
	[(id)color release];
}

CGColorRef CGColorRetain(CGColorRef color)
{
	return (CGColorRef) [(id)color retain];
}
					//  hue = 0-1.0, saturation = 0-1.0, brightness = 0-1.0
void _CGColorConvertHSBtoRGB(struct HSB_Color hsb, struct RGB_Color *rgb)
{
    if (hsb.saturation == 0 || hsb.brightness == 0)
		rgb->red = rgb->green = rgb->blue = hsb.brightness * 255;
	else
		{
		int h = hsb.hue * 359;
		int s = hsb.saturation * 255;
		int v = hsb.brightness * 255;
		int i = h / 60;
		int f = h % 60;
		int p = v * (255 - s) / 255;
		int q = v * (255 - s * f / 60) / 255;
		int t = v * (255 - s * (60 - f) / 60) / 255;

		switch (i)
			{
			case 0: rgb->red = v; rgb->green = t; rgb->blue = p; break;
			case 1: rgb->red = q; rgb->green = v; rgb->blue = p; break;
			case 2: rgb->red = p; rgb->green = v; rgb->blue = t; break;
			case 3: rgb->red = p; rgb->green = q; rgb->blue = v; break;
			case 4: rgb->red = t; rgb->green = p; rgb->blue = v; break;
			case 5: rgb->red = v; rgb->green = p; rgb->blue = q; break;
		}	}
}
					//  hue = 0-359, saturation = 0-255, brightness = 0-255
void _CGColorConvertHSBtoRGB_n(struct HSB_Color hsb, struct RGB_Color *rgb)
{
    if (hsb.saturation == 0 || hsb.brightness == 0)
		rgb->red = rgb->green = rgb->blue = hsb.brightness;
	else
		{
		int h = (unsigned short)hsb.hue % 360;
		int s = hsb.saturation;
		int v = hsb.brightness;
		int i = h / 60;
		int f = h % 60;
		int p = v * (255 - s) / 255;
		int q = v * (255 - s * f / 60) / 255;
		int t = v * (255 - s * (60 - f) / 60) / 255;

		switch (i)
			{
			case 0: rgb->red = v; rgb->green = t; rgb->blue = p; break;
			case 1: rgb->red = q; rgb->green = v; rgb->blue = p; break;
			case 2: rgb->red = p; rgb->green = v; rgb->blue = t; break;
			case 3: rgb->red = p; rgb->green = q; rgb->blue = v; break;
			case 4: rgb->red = t; rgb->green = p; rgb->blue = v; break;
			case 5: rgb->red = v; rgb->green = p; rgb->blue = q; break;
		}	}
}

CGFloat
CGColorGetAlpha(CGColorRef c)
{
	return (CGFloat)((CGColor *)c)->_alpha; // FIX ME float s/b CGFloat
}

const CGFloat *
CGColorGetComponents(CGColorRef c)
{
	((CGColor *)c)->_c.components[3] = ((CGColor *)c)->_alpha;

	return (CGFloat *)((CGColor *)c)->_c.components; // FIX ME float s/b CGFloat
}

size_t
CGColorGetNumberOfComponents(CGColorRef c)
{
	NSString *n = ((CGColor *)c)->_colorspaceName;

	if (n == NSCalibratedRGBColorSpace || (n == NSDeviceRGBColorSpace))
		return CGColorSpaceGetNumberOfComponents(__colorSpaceRGB) + 1;
	if (n == NSDeviceCMYKColorSpace)
		return 4 + 1;
	if (n == NSNamedColorSpace || n == NSCustomColorSpace)
		return 1;									// FIX ME how to respond ?

	return CGColorSpaceGetNumberOfComponents(__colorSpaceGray) + 1;
}

/* ****************************************************************************

	NSColor

** ***************************************************************************/

@interface NSColor (_NSColor)

- (void) _convertToRGB;

@end

@implementation NSColor (_NSColor)

- (void) _convertToRGB
{
	struct RGB_Color rgb = _c.rgb;

	if (_f.hsb)
		{
		_CGColorConvertHSBtoRGB(_c.hsb, &rgb);				// 0-255
		
		_red   = (unsigned short)rgb.red;
		_green = (unsigned short)rgb.green;
		_blue  = (unsigned short)rgb.blue;
		_f.rgb = 1;
		
		return;
		}

	if (_f.gray)											// 0-1.0
		rgb.green = rgb.blue = rgb.red;

	_red   = (unsigned short)(65535 * rgb.red);
	_green = (unsigned short)(65535 * rgb.green);
	_blue  = (unsigned short)(65535 * rgb.blue);
	_f.rgb = 1;
}

- (void) setStroke
{
	CGContextRef cx = _CGContext();

	if (COLOR != self)
		{
		if (_f.hsb && !_f.rgb)
			[self _convertToRGB];
		if (_f.gray)
			CGContextSetGrayStrokeColor(cx, _c.white, _alpha);
		else if (_f.hsb)
			CGContextSetRGBStrokeColor(cx, (float)_red/255, (float)_green/255, (float)_blue/255, _alpha);
		else if (_f.rgb)
			CGContextSetRGBStrokeColor(cx, _c.red, _c.green, _c.blue, _alpha);
		COLOR = self;
		}
}

- (void) setFill
{
	CGContextRef cx = _CGContext();

	if (COLOR_FILL != self)
		{
		if (_f.hsb && !_f.rgb)
			[self _convertToRGB];
		if (_f.gray)
			CGContextSetGrayFillColor(cx, _c.white, _alpha);
		else if (_f.hsb)
			CGContextSetRGBFillColor(cx, (float)_red/255, (float)_green/255, (float)_blue/255, _alpha);
		else if (_f.rgb)
			CGContextSetRGBFillColor(cx, _c.red, _c.green, _c.blue, _alpha);
		COLOR_FILL = self;
		}
}

@end  /* NSColor (_NSColor) */

/* ****************************************************************************

	NSColor (FBColor / XRColor)

** ***************************************************************************/

#ifdef FB_GRAPHICS  /* ********************************************* FBColor */

@implementation NSColor (FBColor)

- (void) set
{
	CGContextRef cx = _CGContext();

	if (COLOR != self)
		[self setStroke];

	if (COLOR_FILL != self)
		[self setFill];
}

@end  /* NSColor (FBColor) */

#else  /* !FB_GRAPHICS  ******************************************** XRColor */

extern void _cairo_set_color( CGContextRef, unsigned r, unsigned g, unsigned b);


static void
_x11_set_color( CGContextRef cx, unsigned long color)
{
	XGC->values.foreground = color;
	XGC->dirty |= GCForeground;
}

static XColor
_XRColorNew(CGContextRef cx, CGColor *cl)
{
	XColor xc;

	[(NSColor *)cl _convertToRGB];

	if ((cl->_colorspaceName == NSCalibratedRGBColorSpace)
		  || (cl->_colorspaceName == NSCalibratedWhiteColorSpace)
		  || (cl->_colorspaceName == NSDeviceRGBColorSpace)
		  || (cl->_colorspaceName == NSDeviceWhiteColorSpace))
		xc = (XColor){0L, cl->_red, cl->_green, cl->_blue, 0, 0};
	else										// CMYK is not converted
		xc = (XColor){0L, 32000, 32000, 32000, 0, 0};

	if (!XAllocColor(XDISPLAY, XCOLORMAP, &xc))	// Allocate X color
		NSLog(@"Unable to allocate X color\n");
	else
		cl->_f.xcolor = YES;

	return xc;
}

@implementation NSColor (_XRColor)

+ (id) alloc
{
	return NSAllocateObject([XRColor class]);
}

@end  /* NSColor (XRColor) */


@implementation XRColor

- (XColor) xColor
{
	if (!_f.xcolor)
		xColor = _XRColorNew(_CGContext(), (CGColor *)self);

  	return xColor;
}

- (void) set
{
	CGContextRef cx = _CGContext();

	if (COLOR != self)
		[self setStroke];

	if (COLOR_FILL != self)
		[self setFill];

	if (!_f.xcolor)
		xColor = _XRColorNew(cx, (CGColor *)self);

	_x11_set_color(cx, xColor.pixel);
#ifdef CAIRO_GRAPHICS
	_cairo_set_color(cx, _red, _green, _blue);
#endif
}

@end  /* NSColor (XRColor) */

#endif  /* !FB_GRAPHICS  ******************************************* XRColor */

/* ****************************************************************************

		CG Pattern

** ***************************************************************************/

static const CFRuntimeClass __CGPatternClass = {
	_CF_VERSION,
	"CGPattern",
	NULL
};


CGColorRef
CGColorCreateWithPattern( CGColorSpaceRef s, CGPatternRef p, const CGFloat components[])
{
	CGColor *c = (CGColor *)[NSColor alloc];
	
	c->pattern = CGPatternRetain(p);
	c->_f.pattern = YES;
	c->_colorspaceName = NSCustomColorSpace;

	return (CGColorRef)c;
}

void
CGContextSetFillPattern(CGContextRef cx, CGPatternRef p, const CGFloat components[])
{
	CGColorSpaceRef patternSpace = NULL;	// CTX->colorSpace;
	CGColorRef c = CGColorCreateWithPattern(patternSpace, p, components);

	if (!p->bitmap)
		{
		CGImageRef bitmap = CTX->_bitmap;
		NSRect xCanvas = GSTATE->xCanvas;
		NSRect clip = GSTATE->clip;
		bool isWindow = CTX->_f.isWindow;

		CTX->_f.isWindow = NO;
		GSTATE->xCanvas = GSTATE->clip = ((CGPattern *)p)->bounds;
		CTX->_bitmap = _CGContextCreateImage( cx, GSTATE->xCanvas.size);
		((CGPattern *)p)->bitmap = CTX->_bitmap;
		CTX->_f.disableBitmapFlush = YES;

		((CGPattern *)p)->callbacks->drawPattern(p->info, cx);

		CTX->_bitmap = bitmap;
		GSTATE->xCanvas = xCanvas;
		GSTATE->clip = clip;
		CTX->_f.disableBitmapFlush = NO;
		CTX->_f.isWindow = isWindow;
		}

	CGContextSetFillColorWithColor( cx, c);
}

void
CGContextSetStrokePattern(CGContextRef cx, CGPatternRef p, const CGFloat components[])
{
	CGColorSpaceRef patternSpace = NULL;	// CTX->colorSpace;
	CGColorRef c = CGColorCreateWithPattern(patternSpace, p, components);

	CGContextSetStrokeColorWithColor( cx, c);
}

void CGContextSetFillColorSpace(CGContextRef cx, CGColorSpaceRef s)
{
	CGColorSpaceRef cs = GSTATE->fill.colorSpace;

	GSTATE->fill.colorSpace = CGolorSpaceRetain(s);
	CGColorSpaceRelease(cs);
}

void CGContextSetStrokeColorSpace(CGContextRef cx, CGColorSpaceRef s)
{
	CGColorSpaceRef cs = GSTATE->stroke.colorSpace;

	GSTATE->stroke.colorSpace = CGolorSpaceRetain(s);
	CGColorSpaceRelease(cs);
}

CGPatternRef
CGPatternCreate(void *info,
				CGRect bounds,
				CGAffineTransform m,
				CGFloat xStep, CGFloat yStep,
				CGPatternTiling pt,
				bool isColored,
				const CGPatternCallbacks *callbacks)
{
	CGPattern *pat = CFAllocatorAllocate(NULL, sizeof(CGPattern), 0);

    if (pat)
		{
		pat->cf_pointer = (void *)&__CGPatternClass;
		pat->bounds = bounds;
		pat->xStep = xStep;
		pat->yStep = yStep;
		pat->_pf.patternTiling = pt;
		pat->_pf.isColored = isColored;
		pat->callbacks = callbacks;
		pat->info = info;
		}

	return pat;
}

CGPatternRef
CGPatternRetain(CGPatternRef pat)
{
	return (pat) ? (CGPatternRef)CFRetain(pat) : pat;
}

void
CGPatternRelease(CGPatternRef pat)
{
	if (pat)
		CFRelease(pat);
}
