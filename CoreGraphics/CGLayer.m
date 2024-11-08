/*
   CGLayer.m

   mini Core Graphics drawing layer

   Copyright (C) 2006-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSView.h>
#include <AppKit/NSAffineTransform.h>


#define CTX				((CGContext *)cx)
#define FOCUS_VIEW		((CGContext *)cx)->_gs->focusView
#define XPIXMAP			CTX->xPixmap
#define XDRAWABLE		CTX->xDrawable


/* ****************************************************************************

		CG Layer

** ***************************************************************************/

static const CFRuntimeClass __CGLayerClass = {
	_CF_VERSION,
	"CGLayer",
	NULL
};

CGLayerRef
CGLayerCreateWithContext( CGContextRef cx, CGSize z, CFDictionaryRef auxInfo)
{
	CGLayer *ly = CFAllocatorAllocate(NULL, sizeof(struct _CGLayer), 0);

	ly->cf_pointer = (void *)&__CGLayerClass;
	ly->_size = z;
//	ly->_auxInfo = auxInfo;
	ly->context = (CGContextRef) CFRetain(cx);			// retain ref context

	return ly;
}

CGLayerRef
CGLayerRetain( CGLayerRef ly)
{
	return (ly) ? CFRetain(ly) : ly;
}

void
CGLayerRelease( CGLayerRef ly)
{
	if (ly && !ly->_ly.dontFree)
		{
		if (ly->context)
			CFRelease(ly->context);
		CFRelease(ly);
		}
}

CGSize
CGLayerGetSize( CGLayerRef ly )
{
	return ly->_size;
}

/* ****************************************************************************

	_CGLayerGetContext()

	A CG layer is created relative to a CTX.  The CG layer uses this CTX as a
	reference for initialization.  Its own CTX will reflect the limitations of
	the reference CTX as either a Bitmap CTX or a Bitmap+Pixmap CTX.

** ***************************************************************************/

static CGContextRef
_CGLayerCreateContext( CGLayer *ly )
{
	NSGraphicsContext *cx = (NSGraphicsContext *)ly->context;

	cx = [NSGraphicsContext graphicsContextWithGraphicsPort:cx flipped:YES];

	CTX->_gs->xCanvas = ((CGContext *)ly->context)->_gs->xCanvas;
	CTX->_gs->xCanvas.origin = NSZeroPoint;
	CTX->_gs->hasCTM = ((CGContext *)ly->context)->_gs->hasCTM;
	CTX->_gs->_ctm = ((CGContext *)ly->context)->_gs->_ctm;

	if (((CGContext *)ly->context)->_f.isWindow)
		{
#ifndef FB_GRAPHICS
		int w = (int)NSWidth(CTX->_gs->xCanvas);
		int h = (int)NSHeight(CTX->_gs->xCanvas);

		if ((XPIXMAP = XRCreatePixmap((CGContextRef)cx, w, h)))
			XDRAWABLE = XPIXMAP;
#endif
		CTX->_bitmap = _CGContextCreateImage((CGContextRef)cx, CTX->_gs->xCanvas.size);
		}
	else
		CTX->_bitmap = _CGContextCreateImage((CGContextRef)cx, ly->_size);

	[CTX->_gs init];								// init gState

	return (CGContextRef)cx;
}

CGContextRef
CGLayerGetContext( CGLayerRef ly )
{
	if (!ly->_ly.hasContext)
		{
		CGContextRef cx = _CGLayerCreateContext((CGLayer *)ly);

		CFRelease(ly->context);					// release ref CTX, retain new
		((CGLayer *)ly)->context = (CGContextRef) CFRetain(cx);

		((CGLayer *)ly)->_ly.hasContext = YES;
		((CGLayer *)ly)->_origin = NSZeroPoint;
		((CGContext *)ly->context)->_f.isCache = 1;
		}
	((CGContext *)ly->context)->_layer = (CGLayer *)ly;

	return ly->context;
}

/* ****************************************************************************

		CG Context

** ***************************************************************************/

CGLayer *
_CGContextWindowBackingLayer( CGContextRef cx, CGSize z)
{
	CGLayer *ly = &((CGContext *)cx)->_back;

	if (ly->context == NULL)
		ly->context = (CGContextRef) CFRetain(cx);
	ly->_size = z;
	ly->_ly.active = YES;
	ly->_ly.dontFree = YES;

	return ly;
}

void
CGContextBeginTransparencyLayerWithRect ( CGContextRef cx,
										  CGRect r,
										  CFDictionaryRef aux )
{
	CGLayer *ly;

	if ((ly = CTX->_layer))
		{
		CGLayer *nly = (CGLayer *)CGLayerCreateWithContext(cx, r.size, aux);

		nly->_prev = ly;
		ly = nly;						// nest layer
		}
	else
		ly = (CGLayer *)CGLayerCreateWithContext(cx, r.size, aux);

	ly->_ly.active = YES;
	CTX->_layer = ly;
	CTX->_f.isCache = YES;
	ly->_origin = r.origin;
}

void
CGContextBeginTransparencyLayer( CGContextRef cx, CFDictionaryRef auxInfo)
{
	NSRect r = [FOCUS_VIEW bounds];

	CGContextBeginTransparencyLayerWithRect(cx, r, auxInfo);
}

void
CGContextEndTransparencyLayer ( CGContextRef cx )
{
	CGLayer *ly;

	if ((ly = CTX->_layer) && ly->_ly.active)
		{
		ly->_ly.active = NO;

		if ((ly->_prev))							// restore CTX's top layer
			CTX->_layer = (CGLayer *)ly->_prev;
		else
			CTX->_f.isCache = 0;

		if (((CGContext *)ly->context)->_bitmap)	// draw nested layer to CTX
			CGContextDrawLayerAtPoint(cx, ly->_origin, ly);
		else										// no bitmap, copy backstor
			NSCopyBits(((CGContext *)ly->context)->_gState,
						(CGRect){ly->_origin, ly->_size}, NSZeroPoint);

		if ((ly->_prev))							// release nested layer
			CGLayerRelease(ly);
		}
	else
		NSLog(@"CGContextEndTransparencyLayer ** called w/o begin layer");
}

void									// FIX ME must scale layer if needed
CGContextDrawLayerInRect(CGContextRef cx, CGRect r, CGLayerRef ly)
{
	if (((CGContext *)ly->context)->_gs == ((CGContext *)cx)->_gs)	// FIX ME menu flush
		_CGContextCompositeImage(cx, r, ((CGContext *)ly->context)->_bitmap);
	else
		NSCopyBits(((CGContext *)ly->context)->_gState, r, NSZeroPoint);
}

void
CGContextDrawLayerAtPoint(CGContextRef cx, CGPoint point, CGLayerRef ly)
{
	CGContextDrawLayerInRect(cx, (CGRect){point, ly->_size}, ly);
}
