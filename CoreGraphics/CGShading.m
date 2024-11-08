/*
   CGShading.m

   Gradient and shader rendering functions

   Copyright (C) 2006-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CFRuntime.h>

#include <AppKit/NSView.h>
#include <AppKit/NSColor.h>


#define CTX				((CGContext *)cx)
#define GSTATE			((CGContext *)cx)->_gs
#define CTM				((CGContext *)cx)->_gs->hasCTM
#define WINDOW			((CGContext *)cx)->_gs->window
#define FOCUS_VIEW		((CGContext *)cx)->_gs->focusView



/* ****************************************************************************

		CG Function

** ***************************************************************************/

static const CFRuntimeClass __CGFunctionClass = {
	_CF_VERSION,
	"CGFunction",
	NULL
};

CGFunctionRef
CGFunctionCreate(void *info,
				 size_t domainDimension,
				 const CGFloat *domain,
				 size_t rangeDimension,
				 const CGFloat *range,
				 const CGFunctionCallbacks *callbacks)
{
	CGFunction *f = CFAllocatorAllocate(NULL, sizeof(struct CGFunction), 0);

	f->cf_pointer = (void *)&__CGFunctionClass;
	f->info = info;
	f->domainDimension = domainDimension;
	f->rangeDimension = rangeDimension;
	f->domain = domain;
	f->range = range;
	f->callbacks = callbacks;

	return f;
}

CGFunctionRef
CGFunctionRetain(CGFunctionRef function)
{
	return (function) ? CFRetain(function) : function;
}

void
CGFunctionRelease(CGFunctionRef function)
{
	if (function)
		CFRelease(function);
}

/* ****************************************************************************

		CG Shading

** ***************************************************************************/

static void __CGShadingDeallocate(CFTypeRef cf)
{
	if ( ((CGShading *)cf)->function )
		CGFunctionRelease( ((CGShading *)cf)->function);
}

static const CFRuntimeClass __CGShadingClass = {
	_CF_VERSION,
	"CGShading",
	__CGShadingDeallocate
};

CGShadingRef
CGShadingCreateAxial (CGColorSpaceRef colorspace,
					  CGPoint start,
					  CGPoint end,
					  CGFunctionRef function,
					  bool extendStart,
					  bool extendEnd)
{
	CGShading *s = CFAllocatorAllocate(NULL, sizeof(CGShading), 0);

	s->cf_pointer = (void *)&__CGShadingClass;
	s->colorspace = colorspace;
	s->start = start;
	s->end = end;
	s->function = CGFunctionRetain(function);
	s->_sh.extendStart = extendStart;
	s->_sh.extendEnd = extendEnd;

	return (CGShadingRef)s;
}

CGShadingRef
CGShadingCreateRadial (CGColorSpaceRef colorspace,
					   CGPoint start,
					   CGFloat startRadius,
					   CGPoint end,
					   CGFloat endRadius,
					   CGFunctionRef function,
					   bool extendStart,
					   bool extendEnd)
{
	CGShading *s = CFAllocatorAllocate(NULL, sizeof(CGShading), 0);

	s->cf_pointer = (void *)&__CGShadingClass;
	s->colorspace = colorspace;
	s->start = start;
	s->end = end;
	s->function = CGFunctionRetain(function);
	s->_sh.extendStart = extendStart;
	s->_sh.extendEnd = extendEnd;
	s->_sh.radial = YES;
	s->startRadius = startRadius;
	s->endRadius = endRadius;

	return (CGShadingRef)s;
}

CGShadingRef
CGShadingRetain(CGShadingRef shading)
{
	return (shading) ? CFRetain(shading) : shading;
}

void
CGShadingRelease(CGShadingRef shading)
{
	if (shading)
		CFRelease(shading);
}

/* ****************************************************************************

		CG Gradient

** ***************************************************************************/

static const CFRuntimeClass __CGGradientClass = {
	_CF_VERSION,
	"CGGradient",
	NULL
};

void CGContextDrawRadialGradient( CGContextRef cx,
								  CGGradientRef gradient,
								  CGPoint startCenter,
								  CGFloat startRadius,
								  CGPoint endCenter,
								  CGFloat endRadius,
								  CGGradientDrawingOptions options)
{
}

static void
GradientShader (void *info, const CGFloat *in, CGFloat *out)
{
	CGGradientRef g = (CGGradientRef)info;
	CGFloat iv;
	CGFloat v = *in;						// 0.0 -> 1.0
	size_t k;
	size_t components = (size_t)CGColorSpaceGetNumberOfComponents(g->colorspace) + 1;
	const CGFloat *bc;						// base color
	const CGFloat *nc;						// next color
	int i;

	for (i = 1; i < g->count - 1; i++)		// ranges in the locations matrix
		if (v < g->locations[i])			// determine the index into the
			break;							// color components matrix

	v = 1.0 - ((v - g->locations[i-1]) / (g->locations[i] - g->locations[i-1]));
	iv = 1.0 - v;

	nc = (const CGFloat *)g->components + (components * i--);
	bc = (const CGFloat *)g->components + (components * i);

    for (k = 0; k < components - 1; k++)
        *out++ = (bc[k] * v) + (nc[k] * iv);
     *out++ = 1;							// alpha

//printf("GradientShader v=%f  (%f %f %f)\n",v, *(out-4), *(out-3), *(out-2));
}

static CGFunctionRef
GetShadingFunction (CGGradientRef g, CGFunctionCallbacks *callbacks)
{
	size_t components = CGColorSpaceGetNumberOfComponents(g->colorspace) + 1;

    return CGFunctionCreate( (void *) g,	// info
							g->count,				// domainDimension
							g->locations,			// CGFloat *domain
							g->count * components,	// rangeDimension
							g->components,			// CGFloat *range
							callbacks);
}

void CGContextDrawLinearGradient( CGContextRef cx,
								  CGGradientRef g,
								  CGPoint s,
								  CGPoint e,
								  CGGradientDrawingOptions options)
{
	CGFunctionCallbacks callbacks = { 0, &GradientShader, NULL };
	bool exStart = (options & kCGGradientDrawsBeforeStartLocation);
	bool exEnd   = (options & kCGGradientDrawsAfterEndLocation);
	CGShadingRef  shading;
	CGFunctionRef fn = GetShadingFunction(g, &callbacks);

//	shading = CGShadingCreateAxial(g->colorspace, s, e, fn, NO, NO);
	shading = CGShadingCreateAxial(g->colorspace, s, e, fn, exStart, exEnd);
    CGContextDrawShading (cx, shading);

    CGFunctionRelease (fn);
    CGShadingRelease (shading);
}

extern CGGradientRef
CGGradientCreateWithColorComponents(CGColorSpaceRef colorspace,
									const CGFloat components[],
									const CGFloat locations[],
									size_t count)
{
	size_t nc = CGColorSpaceGetNumberOfComponents(colorspace) + 1;
	unsigned int  szComponents = (count * nc * sizeof(CGFloat));
	unsigned int  szLocations = (count * sizeof(CGFloat));
	unsigned int  sz = sizeof(struct CGGradient) + szComponents + szLocations;
	CGGradient *g = CFAllocatorAllocate(NULL, sz, 0);

	g->cf_pointer = (void *)&__CGGradientClass;
	g->count = count;
	g->colorspace = colorspace;
	g->components = (void *)g + sizeof(struct CGGradient);
	g->locations  = (void *)g->components + szComponents;
	memcpy(g->components, components, szComponents);
	memcpy(g->locations, locations, szLocations);

	return g;
}

CGGradientRef
CGGradientRetain (CGGradientRef gradient)
{
	return (gradient) ? CFRetain(gradient) : gradient;
}

void
CGGradientRelease(CGGradientRef gradient)
{
	if (gradient)
		CFRelease(gradient);
}

/* ****************************************************************************

		Render Decor Gradients

** ***************************************************************************/

static void
MenuShader (void *info, const CGFloat *in, CGFloat *out)
{
	CGFloat v = *in;
	size_t k, components = (size_t)info;
	static const CGFloat c[] = {.75, .75, .75, 0};

    for (k = 0; k < components - 1; k++)
        *out++ = c[k] * v;
     *out++ = 1;						// alpha
}

static void
TitleShader (void *info, const CGFloat *in, CGFloat *out)
{
	CGFloat v = *in;
	size_t k, components = (size_t)info;
	static const CGFloat c[] = {.1, .1, .54, 0};	// dark blue

    for (k = 0; k < components - 1; k++)
        *out++ = c[k] * v;   
     *out++ = 1;						// alpha
}

CGFunctionRef
_CreateShadingFunction (CGColorSpaceRef cs, CGFunctionCallbacks *callbacks)
{
	size_t components = CGColorSpaceGetNumberOfComponents(cs) + 1;
	static const CGFloat input_value_range [2] = { 0, 1 };
	static const CGFloat output_value_ranges [8] = { 0, 1, 0, 1, 0, 1, 0, 1 };

    return CGFunctionCreate ((void *) components, 1,
							input_value_range,
							components,
							output_value_ranges,
							callbacks);
}

static CGShadingRef
_TitleBarShading(void)
{
	static CGFunctionRef fn;
	static CGShadingRef shading = NULL;
	static CGFunctionCallbacks callbacks = { 0, &TitleShader, NULL };

	if (!shading)
		{
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
		CGPoint s = CGPointMake(1.0, 0.0);		// diagonal
		CGPoint e = CGPointMake(0.0, 1.0);

		fn = _CreateShadingFunction(colorspace, &callbacks);
		shading = CGShadingCreateAxial(colorspace, s, e, fn, NO, NO);
		}

 	return shading;
}

static CGShadingRef
_MenuShading(void)
{
	static CGFunctionRef fn;
	static CGShadingRef shading = NULL;
	static CGFunctionCallbacks callbacks = { 0, &MenuShader, NULL };

	if (!shading)
		{
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
		CGPoint s = CGPointMake(1.0, 0.0);		// horiz gradient white left
		CGPoint e = CGPointMake(0.0, 0.0);

		fn = _CreateShadingFunction(colorspace, &callbacks);
		shading = CGShadingCreateAxial(colorspace, s, e, fn, NO, NO);
		}

 	return shading;
}

static CGShadingRef
_CGMenuHorzShading(void)
{
	static CGFunctionRef fn;
	static CGShadingRef shading = NULL;
	static CGFunctionCallbacks callbacks = { 0, &MenuShader, NULL };

	if (!shading)
		{
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
		CGPoint s = CGPointMake(0.0, 0.0);
		CGPoint e = CGPointMake(0.0, 1.0);

		fn = _CreateShadingFunction(colorspace, &callbacks);
		shading = CGShadingCreateAxial(colorspace, s, e, fn, NO, NO);
		}

 	return shading;
}

static void _BevelContext(CGContextRef cx, NSRect r, bool highlight, bool bevel)
{
	_CGBevelImage((CGImage *)((CGContext *)cx)->_bitmap, r, highlight, bevel);
}

void
_CGDrawMenuTitleBar(CGContextRef gc, NSRect bounds)
{
	CGAffineTransform at;

    at = CGAffineTransformMakeScale (NSWidth(bounds), NSHeight(bounds));
    CGContextSaveGState (gc);
    CGContextConcatCTM (gc, at);

//    CGContextClipToRect (gc, CGRectMake(0, 0, 1, 1));

	CGContextBeginTransparencyLayerWithRect (gc, bounds, NULL);
    CGContextDrawShading (gc, _TitleBarShading());
	_BevelContext(gc, bounds, NO, YES);
	CGContextEndTransparencyLayer(gc);

    CGContextRestoreGState (gc);
}

CGContextRef
_CGRenderMenuCell( CGContextRef gc, NSSize cs, bool bevel )
{
	CGAffineTransform at = CGAffineTransformMakeScale (cs.width*4, cs.height);

	CGContextSaveGState (gc);
	CGContextConcatCTM (gc, at);

//	CGContextClipToRect (gc, CGRectMake(0, 0, 1, 1));

	CGContextRef cx = _CGBitmapContextCreate(gc, cs);

	CGContextDrawShading(cx, _MenuShading());
	_BevelContext(cx, (NSRect){NSZeroPoint, cs}, NO, bevel);

	CGContextRestoreGState (gc);

	return cx;
}

CGContextRef
_CGRenderHorzMenu( CGContextRef gc, NSSize cs, bool bevel )
{
	CGAffineTransform at = CGAffineTransformMakeScale(cs.width*4, cs.height*3);

	CGContextSaveGState(gc);
	CGContextConcatCTM(gc, at);

//	CGContextClipToRect (gc, CGRectMake(0, 0, 1, 1));

	CGContextRef cx = _CGBitmapContextCreate(gc, cs);

	CGContextDrawShading(cx, _CGMenuHorzShading());
	_BevelContext(cx, (NSRect){NSZeroPoint, cs}, NO, bevel);

	CGContextRestoreGState (gc);
		
	return cx;
}

/* ****************************************************************************

	LineCircleIntersection

	Determine the intersection point of a line between p1 and p2 and a circle
	centered at p with radius r.  Optimized for the case where line is a radial
	with origin within the circle and extending outside.

** ***************************************************************************/

static void
LineCircleIntersection(NSPoint p, float r, NSPoint p1, NSPoint p2, NSPoint *ix)
{
	float dx = p2.x - p1.x;
	float dy = p2.y - p1.y;
	float a  = dx*dx + dy*dy;
	float b  = 2 * (dx * (p1.x - p.x) + dy * (p1.y - p.y));
	float pp = p.x*p.x + p.y*p.y;
	float c = pp + p1.x*p1.x + p1.y*p1.y - 2 * (p.x * p1.x + p.y * p1.y) - r*r;
	float det = b*b - 4*a*c;

//	if (det < 0)			printf("Outside\n");
//	else if (det == 0)		printf("Tangent\n");
//	else
		{
        float e = sqrt(det);
		float a2 = 2*a;
        float u1 = (-b + e) / a2;
        float u2 = (-b - e) / a2;

		ix->x = p1.x + u1*dx;
		ix->y = p1.y + u1*dy;

//		if (0 <= u1 && u1 <= 1)		// first intersection u1
//		if (0 <= u2 && u2 <= 1)		// second intersection u2
		}
}

/* ****************************************************************************

	CGContextDrawShading

	Fill current clipping region of context (bitmap) with shading.

** ***************************************************************************/

void
CGContextDrawShading( CGContextRef cx, CGShadingRef shading)
{
	CGImage *img;
	NSRect bounds;
	unsigned int row = 0;
	unsigned int col;
	CGColor c;
	NSPoint a;
	NSPoint b;
	bool freeBitmap = NO;

	if (CTX->_f.isCache && CTX->_layer)
		bounds = (NSRect){CTX->_layer->_origin, CTX->_layer->_size};
	else
		bounds = [FOCUS_VIEW bounds];

///	if (CTX->_bitmap && !CTX->_f.isCache)
	if (CTX->_bitmap && !CTX->_f.isWindow)
		{
		img = (CGImage *)CTX->_bitmap;
		bounds = (NSRect){NSZeroPoint, {img->width, img->height}};
		}
	else
		{
		NSLog(@"CGContextDrawShading no bitmap stor in context **********\n");

		img = (CGImage *)_CGContextCreateImage(cx, bounds.size);
//		img = (CGImage *)FBGetImage(cx, (NSRect){NSZeroPoint, bounds.size});

		if (CTX->_f.isCache && CTX->_layer)
			{
			freeBitmap = NO;
///			CTX->_bitmap = img;
			}
		else
			freeBitmap = YES;
		}

//	if (CTM)
///		bounds = NSIntersectionRect((NSRect){{0,0},[CTM transformSize: (NSSize){1.0,1.0}]},bounds);

	if (CTM)
		{
		b = CGPointApplyAffineTransform(shading->start, GSTATE->_ctm);
		a = CGPointApplyAffineTransform(shading->end, GSTATE->_ctm);

		NSLog(@"CGContextDrawShading from %f %f  to %f %f\n",a.x, a.y, b.x, b.y);
//		printf("CGContextDrawShading bounds %f %f  %f %f\n",
//				bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
//		NSLog(@"%@", [CTM description]);
		}
	else
		NSLog(@"CGContextDrawShading no CTM **************\n");

	if (shading->_sh.radial)
		{
		void *info = shading->function->info;
		NSPoint outer[360];
		float lens[360];
		float ir = shading->startRadius * NSWidth(bounds);
		float or = shading->endRadius * NSWidth(bounds);
		int i = 0;

		for (i = 0; i < 360; i++)
			{
			NSPoint radial = (NSPoint){b.x + cos(i * M_PI / 180) * or * 2,
									   b.y + sin(i * M_PI / 180) * or * 2};

//printf("CGContextDrawShading ray  deg %d  radial %2.2f %2.2f outer %2.2f %2.2f\n", i, radial.x, radial.y, outer[i].x, outer[i].y);
			LineCircleIntersection(a, or, b, radial, &outer[i]);
			}

		for (i = 0; i < 360; i++)
			{
			float x = b.x - outer[i].x;
			float y = b.y - outer[i].y;

			lens[i] = sqrt(x*x+y*y);
//printf("CGContextDrawShading deg %d  len %2.2f dist from %2.2f %2.2f  to %2.2f %2.2f\n", i, lens[i], b.x, b.y, outer[i].x, outer[i].y);
			}

		for (row = 0; row < NSHeight(bounds); row++)
			for (col = 0; col < NSWidth(bounds); col++)
				{
				double x = col - a.x + 0.5;
				double y = row - a.y - 0.5;
				CGFloat in = sqrt(x*x+y*y);
				CGFloat out[4];
				int deg;

				if (in > or)					// limit to outer radius
					continue;

				x = col - b.x + 0.5;
				y = row - b.y - 0.5;
				in = sqrt(x*x+y*y);

				if (in < ir)					// limit to inner radius
					continue;

				if ((deg = (atan2(y, x) * 180.0 / M_PI)) < 0)
					deg += 360;

//printf("CGContextDrawShading   %d %d  deg %d in %2.2f ir %2.2f lens[deg] %2.2f\n", row,col,deg,in, ir, lens[deg]);

				if ((in = in / lens[deg]) > 1.0)
					in = 1.0;
//				if (deg > 90 && deg < 95) 
//					in = 0;
				(*shading->function->callbacks->evaluate) (info, &in, out);

				c._red	 = 255 * out[0];
				c._green = 255 * out[1];
				c._blue	 = 255 * out[2];

//printf("CGContextDrawShading   %d %d  color %d %d %d \n", row,col,c.red,c.green,c.blue);
				_CGImagePutPixel(img, col, NSHeight(bounds) - 1 - row, &c);
				}
		}
	else									// axial gradient
		{
		void *info = shading->function->info;
		float dx = (a.x - b.x);
		float dy = (a.y - b.y);

		if (dy == 0)						// horizontal gradient
			{
			float xOff = MIN(a.x, b.x);
			float xEnd = MAX(a.x, b.x);
			float width = xEnd - xOff;
			unsigned int maxcol = MIN(xEnd - xOff, NSWidth(bounds));

			for (row = 0, col = 0; col < maxcol; col++, row = 0)
//			for (row = 0, col = xOff; col < maxcol; col++, row = 0)
				{
				CGFloat in = (a.x < b.x) ? 1.0 - col / width : col / width;
				CGFloat out[4];

				(*shading->function->callbacks->evaluate) (info, &in, out);

				c._red	 = 255 * out[0];
				c._green = 255 * out[1];
				c._blue	 = 255 * out[2];

				for (; row < NSHeight(bounds); row++)
					_CGImagePutPixel(img, col, row, &c);
				}
			}
		else if (dx == 0)					// vertical gradient
			{
			float yOff = MIN(a.y, b.y);
			float yEnd = MAX(a.y, b.y);
			float height = yEnd - yOff;
			unsigned int maxrow = MIN(yEnd - yOff, NSHeight(bounds));

//			for (col = 0, row = yOff; row < maxrow; row++, col = 0)
			for (col = 0; row < maxrow; row++, col = 0)
				{
				CGFloat in = (a.y < b.y) ? row / height : 1.0 - row / height;
				CGFloat out[4];

				(*shading->function->callbacks->evaluate) (info, &in, out);

				c._red	 = 255 * out[0];
				c._green = 255 * out[1];
				c._blue	 = 255 * out[2];

///				c.pixel = ((c.red) << 16) + (c.green << 8) + (c.blue);
				for (; col < NSWidth(bounds); col++)
					_CGImagePutPixel(img, col, row, &c);
				}
			}
		else								// diagonal gradient
			{
			float yOff = MIN(a.y, b.y);
			float yEnd = MAX(a.y, b.y);
			float xOff = MIN(a.x, b.x);
			float xEnd = MAX(a.x, b.x);
			float width = xEnd - xOff;
			float height = yEnd - yOff;
			unsigned int maxrow = MIN(yEnd - yOff, NSHeight(bounds));
			unsigned int maxcol = MIN(xEnd - xOff, NSWidth(bounds));

			for (; row < maxrow; row++)
//			for (; row < NSHeight(bounds); row++)
				{
//				float rowRatio = row / NSHeight(bounds);
				float rRatio = (a.y < b.y) ? row / height : 1.0 - row / height;

				for (col = 0; col < maxcol; col++)
					{
					float cRatio = (a.x < b.x) ? 1.0 - col / width : col / width;
					CGFloat in = (rRatio + cRatio) / 2;
					CGFloat out[4];

					(*shading->function->callbacks->evaluate) (info, &in, out);

	//	printf("in %f  red %f green %f blue %f  alpha %f\n",in, out[0],out[1],out[2],out[3]);

					c._red	 = 255 * out[0];
					c._green = 255 * out[1];
					c._blue	 = 255 * out[2];

					_CGImagePutPixel(img, col, row, &c);
		}	}	}	}

	CGContextSetBlendMode(cx, kCGBlendModeNormal);

	if (((CGContext *)cx)->_f.isBitmap == NO)
		_CGContextCompositeImage(cx, bounds, img);	// window or pixmap CTX

	if (freeBitmap)
		CGImageRelease(img);
}
