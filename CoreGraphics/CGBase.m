/*
   CGBase.m

   Geometry and Affine Transform functions

   Copyright (C) 2006-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CFRuntime.h>

#include <AppKit/NSView.h>
#include <AppKit/NSAffineTransform.h>


#define CTX				((CGContext *)cx)
#define GSTATE			((CGContext *)cx)->_gs
#define FOCUS_VIEW		((CGContext *)cx)->_gs->focusView
#define WINDOW			((CGContext *)cx)->_window


/* ****************************************************************************

		CG Geometry

** ***************************************************************************/

CGRect
CGRectStandardize(CGRect rect)
{
	CGRect r = rect;
	
	if (rect.size.width < 0.0f)
		{
        r.origin.x = NSMaxX(rect);
        r.size.width = -rect.size.width;
		}
	if (rect.size.height < 0.0f)
		{
        r.origin.y = NSMaxY(rect);
        r.size.height = -rect.size.height;
		}

	return r;
}

const CGPoint CGPointZero = (CGPoint){0, 0};
const CGSize  CGSizeZero  = (CGSize) {0, 0};
const CGRect  CGRectZero  = (CGRect) {0, 0, 0, 0};

const CGRect  CGRectNull     = {-FLT_MAX,-FLT_MAX, 0,0};
const CGRect  CGRectInfinite = {-FLT_MAX,-FLT_MAX, FLT_MAX,FLT_MAX};

CGVector
CGVectorMake(CGFloat a, CGFloat b)			{ return (CGVector){a, b}; }

bool
CGRectContainsPoint(CGRect r, CGPoint p)	{ return NSPointInRect(p, r); }

/* ****************************************************************************

		CG AffineTransform

** ***************************************************************************/

const CGAffineTransform CGAffineTransformIdentity = {1, 0, 0, 1, 0, 0};

CGAffineTransform
CGAffineTransformMake( CGFloat a,  CGFloat b,
					   CGFloat c,  CGFloat d,
					   CGFloat tx, CGFloat ty)
{
	return (CGAffineTransform){a, b, c, d, tx, ty};
}

CGAffineTransform
CGAffineTransformMakeScale( CGFloat sx, CGFloat sy)
{
	return (CGAffineTransform){sx, 0, 0, sy, 0, 0};
}

CGAffineTransform
CGAffineTransformMakeTranslation( CGFloat tx, CGFloat ty)
{
	return (CGAffineTransform){1, 0, 0, 1, tx, ty};
}

CGAffineTransform
CGAffineTransformInvert( CGAffineTransform m)
{
	CGFloat determinant = m.a * m.d - m.b * m.c;

	if (FLT_EQ(determinant, 0.0))
		NSLog (@"Error: determinant of matrix is 0 !");
	else											// if matrix transform
		{											// of (X,Y) = (X',Y') then
		CGFloat a =  m.d / determinant;				// its inverse matrix
		CGFloat b = -m.b / determinant;				// makes (X',Y') = (X,Y)
		CGFloat c = -m.c / determinant;
		CGFloat d =  m.a / determinant;
		CGFloat tx = (-m.d * m.tx + m.c * m.ty) / determinant;
		CGFloat ty = ( m.b * m.tx - m.a * m.ty) / determinant;

		return (CGAffineTransform){a, b, c, d, tx, ty};
		}

	return m;
}

CGAffineTransform
CGAffineTransformTranslate( CGAffineTransform m, CGFloat tx, CGFloat ty)
{
	CGFloat dx = tx * m.a + ty * m.c + m.tx;
	CGFloat dy = tx * m.b + ty * m.d + m.ty;

	return (CGAffineTransform){ m.a, m.b, m.c, m.d, dx, dy };
}

CGAffineTransform
CGAffineTransformScale( CGAffineTransform m, CGFloat sx, CGFloat sy)
{
	return (CGAffineTransform){ m.a * sx, m.b, m.c, m.d * sy, m.tx, m.ty };
}

CGAffineTransform
CGAffineTransformRotate( CGAffineTransform m, CGFloat angleRad)
{
	CGFloat sine = sin(angleRad);
	CGFloat cosine = cos(angleRad);

	CGFloat a = m.a * cosine + m.c * sine;
	CGFloat b = m.b * cosine + m.d * sine;
	CGFloat c = -m.a * sine + m.c * cosine;
	CGFloat d = -m.b * sine + m.d * cosine;

	return (CGAffineTransform){a, b, c, d, m.tx, m.ty};
}

CGAffineTransform
CGAffineTransformConcat( CGAffineTransform t1, CGAffineTransform t2)
{
	CGFloat a = t1.a * t2.a + t1.b * t2.c;
	CGFloat b = t1.a * t2.b + t1.b * t2.d;
	CGFloat c = t1.c * t2.a + t1.d * t2.c;
	CGFloat d = t1.c * t2.b + t1.d * t2.d;
	CGFloat tx = t1.tx * t2.a + t1.ty * t2.c + t2.tx;
	CGFloat ty = t1.tx * t2.b + t1.ty * t2.d + t2.ty;

	return (CGAffineTransform){a, b, c, d, tx, ty};
}

CGRect
CGRectApplyAffineTransform( CGRect r, CGAffineTransform m)
{
	CGRect tr;

	tr.origin.x = m.a * r.origin.x + m.c * r.origin.y + m.tx;
	tr.origin.y = m.b * r.origin.x + m.d * r.origin.y + m.ty;
	tr.size.width = m.a * r.size.width + m.c * r.size.height;
	tr.size.height = m.b * r.size.width + m.d * r.size.height;

	return tr;
}

/* ****************************************************************************

		CG Context

** ***************************************************************************/

void
CGContextSetCTM( CGContextRef cx, CGAffineTransform tm)
{
	GSTATE->_ctm = tm;
	GSTATE->hasCTM = YES;
}

CGAffineTransform
CGContextGetCTM( CGContextRef cx )
{
	return GSTATE->_ctm;
}

void CGContextTranslateCTM( CGContextRef cx, CGFloat x, CGFloat y)
{
    GSTATE->_ctm = CGAffineTransformTranslate(GSTATE->_ctm, x, y);
}

void CGContextScaleCTM( CGContextRef cx, CGFloat sx, CGFloat sy)
{
    GSTATE->_ctm = CGAffineTransformScale(GSTATE->_ctm, sx, sy);
}

void CGContextRotateCTM( CGContextRef cx, CGFloat angle)
{
    GSTATE->_ctm = CGAffineTransformRotate(GSTATE->_ctm, angle);
}

void
CGContextConcatCTM( CGContextRef cx, CGAffineTransform tm)
{
	CGAffineTransform m;

	if (!GSTATE->hasCTM)									// FIX ME s/b set
		{													// in lockFocus
		NSAffineTransform *ctm = [FOCUS_VIEW _matrixFromSubview:FOCUS_VIEW
											 toSuperview:[WINDOW contentView]];
		m = [ctm transformStruct];
		}
	else
		m = GSTATE->_ctm;

	CGContextSetCTM(cx, CGAffineTransformConcat(tm, m));
}

void
_CGOutOfBoundsAccess(const char *caller, CGLayer *ly, int x, int y, int location)
{
	int xoff = 0;
	int yoff = 0;

	if (ly)
		{
		xoff = (int)ly->_origin.x;		// SXOFF
		yoff = (int)ly->_origin.y;		// SYOFF
		}

	fprintf(stderr, "CG out of bounds access in function: (%s) xy %d %d  "
			"offset %d %d  loc %d\n", caller, x, y, xoff, yoff, location);
//	[NSException raise: NSGenericException format:@"FB out of bounds access."];
}

/* ****************************************************************************

		CG DataProvider

** ***************************************************************************/

typedef struct _CGDataProvider {

	void *class_pointer;
	void *cf_pointer;

	bool isDirect;
	bool isSequential;

	void *info;
	const void *data;
	off_t size;

	union {
		CGDataProviderDirectCallbacks	  cb_direct;
		CGDataProviderSequentialCallbacks cb_seqtial;
		CGDataProviderReleaseDataCallback cb_release;
	};

} CGDataProvider;


static void __CGDataProviderDeallocate(CFTypeRef cf)
{
	CGDataProvider *p = ((CGDataProvider *)cf);

	if ( p->isDirect )
		{
		p->cb_direct.releaseBytePointer(p->info, p->data);
		p->cb_direct.releaseInfo(p->info);
		}
	else if ( p->isSequential )
		p->cb_seqtial.releaseInfo(p->info);
	else
		p->cb_release(p->info, p->data, p->size);
}

static const CFRuntimeClass __CGDataProviderClass = {
	_CF_VERSION,
	"CGDataProvider",
	__CGDataProviderDeallocate
};



CGDataProviderRef
CGDataProviderRetain(CGDataProviderRef dp)
{
	return (dp) ? (CGDataProviderRef) CFRetain(dp) : dp;
}

void
CGDataProviderRelease(CGDataProviderRef dp)
{
	if (dp)
		CFRelease(dp);
}

CGDataProviderRef
CGDataProviderCreateSequential( void *info,
								const CGDataProviderSequentialCallbacks *cb)
{
	CGDataProvider *p = NULL;

    if (cb && (p = CFAllocatorAllocate(NULL, sizeof(CGDataProvider), 0)))
		{
		p->cf_pointer = (void *)&__CGDataProviderClass;
		p->info = info;
		p->isSequential = YES;
		memcpy(&p->cb_seqtial, cb, sizeof(CGDataProviderSequentialCallbacks));
		}

	return (CGDataProviderRef)p;
}

CGDataProviderRef
CGDataProviderCreateDirect( void *info,
							off_t size,
							const CGDataProviderDirectCallbacks *cb)
{
	CGDataProvider *p = NULL;

    if (cb && (p = CFAllocatorAllocate(NULL, sizeof(CGDataProvider), 0)))
		{
		p->cf_pointer = (void *)&__CGDataProviderClass;
		p->info = info;
		p->size = size;
		p->isDirect = YES;
		memcpy(&p->cb_direct, cb, sizeof(CGDataProviderDirectCallbacks));
		}

	return (CGDataProviderRef)p;
}

CGDataProviderRef
CGDataProviderCreateWithData (void *info,
							  const void *data,
							  size_t size,
							  CGDataProviderReleaseDataCallback cb)
{
	CGDataProvider *p = NULL;

    if (data && (p = CFAllocatorAllocate(NULL, sizeof(CGDataProvider), 0)))
		{
		p->cf_pointer = (void *)&__CGDataProviderClass;
		p->info = info;
		p->data = data;
		p->size = size;
		if (cb)
			memcpy(&p->cb_release, cb, sizeof(CGDataProviderReleaseDataCallback));
		}

	return (CGDataProviderRef)p;
}

void
_CGDataProviderLoadImage(CGDataProviderRef p, CGImage *img)
{
	if (((CGDataProvider *)p)->isDirect)			// FIX ME sequential
		{
		CGDataProviderGetBytesAtPositionCallback gb;
		void *info = ((CGDataProvider *)p)->info;
		int i;
		
		gb = ((CGDataProvider *)p)->cb_direct.getBytesAtPosition;

		for (i = 0; i < img->height; i++)
			gb(info, img->idata + (i * img->bytesPerRow), i * img->width, img->width);
		}
	else
		img->idata = (void *)((CGDataProvider *)p)->data;
}
