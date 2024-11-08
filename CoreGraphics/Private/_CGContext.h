/*
   _CGContext.h

   Graphics Context private interface

   Copyright (C) 1998-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _H_CGContext
#define _H_CGContext

#include <Foundation/NSDate.h>
#include <Foundation/NSMapTable.h>

#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSImage.h>

#define GS_STACK_SIZE   32

@class NSCursor;
@class NSWindow;
@class NSMutableArray;
@class NSImageRep;
@class NSView;


struct _CGLineDash {

	CGFloat phase;
	CGFloat *lengths;
	int count;
};

struct _CGLine {

	int joinStyle;
	int capStyle;
	CGFloat width;
	CGFloat flatness;
	CGFloat miterLimit;
	struct _CGLineDash dash;
};

struct _CGShadow {

	CGColorRef color;
	CGFloat    blur;
	CGSize     offset;
};

typedef struct _CGInkContext {

	unsigned char *rgba;
	unsigned int   length;
	unsigned char  cov;
	CGPatternRef   pattern;
	CGColorRef     color;
	int			   yb;
	bool           mask;

} _CGInk;

union _CGColorState {

	struct {
		NSColor *color;
		CGColorSpaceRef colorSpace;
		unsigned char rgba[4];
	};

	struct {
		CGColorRef c;
		CGColorSpaceRef s;
		unsigned char red;
		unsigned char green;
		unsigned char blue;
		unsigned char alpha;
	};
};


@interface _GState : NSObject
{
@public
	union _CGColorState stroke;
	union _CGColorState fill;

	CGFloat alpha;
	unsigned char dissolve;

	CGInterpolationQuality _interpolationQuality;

	CGBlendMode blendMode;
	void (*colorBlend)  (unsigned char *, _CGInk *, int, unsigned char *);
	void (*imageBlend)  (unsigned char *, _CGInk *, int, unsigned char *);
	void (*pathBlend)   (unsigned char *, _CGInk *, int, unsigned char *);
	void (*textBlend)   (unsigned char *, unsigned char, int, unsigned char *);

	NSFont *font;
	int ascender;
	int descender;
	CGFloat tabSize;
	CGFloat spacing;						// spacing added between chars

	struct _CGLine   _line;
	struct _CGShadow _shadow;

	NSImage *image;							// for PS single ops
	NSImageRep *imageRep;

	NSGraphicsContext *context;
	NSGraphicsContext *current;

	bool isFlipped;
	bool hasCTM;
	CGAffineTransform _ctm;

	NSView *focusView;
	NSRect xCanvas;

	NSRect clip;
	bool mask;

#ifndef FB_GRAPHICS

	GC xGC;

#endif
}

@end


typedef struct _GraphicsContextMeta {

	NSGraphicsContext *_ctx;				// current context
	NSGraphicsContext *_rcx;				// root context

	_GState *_gsStack[GS_STACK_SIZE];
	int _gsStackIndex;						// GS stack s/b per thread

	NSInteger _uniqueGStateTag;				// monotonic tag of a gState object

	NSMutableArray *_gStateArray;			// list of all G state objects
	NSMapTable *_winToTag;					// map NS windows to unique int

	NSMutableArray *_transients;
	NSMutableArray *_appEventQueue;

	NSCursor  *_cursor;

#ifdef FB_GRAPHICS

	unsigned int _curorWidth;
	unsigned int _curorHeight;
	unsigned int _curorNumColors;
	unsigned char *_cursorBitmap;
	unsigned char *_cursorRestoreBuf;
	unsigned char *_cursorRestorePtr;
	unsigned int _cursorRestoreSize;

	int _mouse;
	int _console;

#else  /* !FB_GRAPHICS  **************************************** XR Graphics */

	NSMapTable *_winToX11;					// maps NS windows to X11 windows

	void *_dnd;								// XDND context

#endif

} _GCMeta;


@interface _NSGraphicsContext : NSGraphicsContext
{
	_GState *_gs;
	_GCMeta *_mg;							// GC Meta data stor

	NSWindow *_window;
	NSInteger _gState;						// also Window CTX's windowNumber

	CGDisplay *_display;					// display screen

	CGPath *_path;
	void *_get;								// global edges table
	void *_aet;								// active edges table

	struct _IntegerRect {
		int x0, y0;
		int x1, y1;
	} clip;

	CGImageRef _bitmap;						// bitmap drawing canvas

	NSRect _flushRect;

	int _yOffset;							// offset from parent (title bar)
	int _xOffset;

	CGAffineTransform _ttm;					// text transform matrix
	CGPoint _pen;

	CGLayer *_layer;						// default drawing layer ptr
	struct _CGLayer _back;					// context back store layer

#ifdef FB_GRAPHICS

	struct _CGLayer _fb;					// screen frame buffer layer

#else   /* !FB_GRAPHICS */

	Window xWindow;
	Drawable xPixmap;						// xWin backstor canvas (Pixmap)
	Drawable xDrawable;						// default Drawable (xWin or Pixmap)

 #ifdef CAIRO_GRAPHICS
	void *_cairoContext;					// cairo_t *
	void *_surface;							// cairo_surface_t * or AGG surface
 #endif

#endif  /* !FB_GRAPHICS */

	struct __gContextFlags {
		CGPathDrawingMode draw:3;
		CGTextDrawingMode drawText:3;
		unsigned int shouldAntialias:1;
		unsigned int allowsAntialiasing:1;
		unsigned int isPrinter:1;
		unsigned int isCache:1;
		unsigned int isWindow:1;
		unsigned int isBitmap:1;
		unsigned int pathClip:1;
		unsigned int textMatrix:1;
		unsigned int dirtyBitmap:1;
		unsigned int disableBitmapFlush:1;
		unsigned int disableWindowFlush:1;
		unsigned int reserved:15;
	} _f;
}

@end


@interface NSGraphicsContext  (GraphicsState)

- (_GState *) _gState;

@end


typedef struct { @defs(_NSGraphicsContext); }  CGContext;


typedef struct _BitmapContext
{
	CGImageRef img;
	void *info;
	void (*CGBitmapContextReleaseDataCallback)(void *info, void *data);

} _GCBitmapContext;


extern CGContextRef _CGContext(void);

extern void _CGContextInitDisplay(CGContextRef cx);
extern void _CGContextInitBlendModes(CGContextRef cx);

extern CGContextRef _CGBitmapContextCreate( CGContextRef c, CGSize z);

extern NSInteger _CGContextAllocGState(CGContextRef cx);
extern void      _CGContextReleaseGState(CGContextRef cx, NSInteger tag);
extern _GState * _CGContextGetGState(CGContextRef cx, NSInteger tag);

extern void _CGContextCopyRect( CGContextRef srcGC, NSRect src, NSPoint dst);

extern CGImageRef _CGContextCreateImage( CGContextRef c, CGSize z);
extern CGImageRef _CGContextResizeBitmap( CGContextRef c, CGSize z);
extern CGImageRef _CGContextGetImage(CGContextRef cx, NSRect r);

extern void _CGContextCompositeImage( CGContextRef cx, NSRect r, CGImageRef a);

extern void _CGContextDrawShadow(CGContextRef c, CGRect r);

extern NSRect _CGGetClipRect(CGContextRef cx, NSRect r);

extern CGLayer * _CGContextWindowBackingLayer( CGContextRef cx, CGSize z);

extern  void _CGDrawMenuTitleBar( CGContextRef gc, NSRect bounds);
extern CGContextRef _CGRenderMenuCell( CGContextRef gc, NSSize s, bool bevel);
extern CGContextRef _CGRenderHorzMenu( CGContextRef gc, NSSize s, bool bevel);

extern unsigned char * _CGRasterLine( CGContextRef cx, unsigned x, unsigned y, unsigned w);

extern void _CGRenderPath(CGContextRef, CGPath *, CGAffineTransform *, bool fill);

extern void _CGContextSetHSBColor( CGContextRef cx,
								   CGFloat h,
								   CGFloat s,
								   CGFloat b);

extern void  _CGContextDrawGlyphs( CGContextRef cx,
								   int *glyphs,
								   int nglyphs,
								   CGFloat x, CGFloat y);

extern CGFloat _CGContextTextWidth( CGContextRef cx,
									CGFontRef f,
									const char *bytes,
									int length);

/* ****************************************************************************

	Platform

** ***************************************************************************/

#ifdef FB_GRAPHICS

extern void FBGetKeyEvent(CGContextRef cx);
extern void FBGetMouseEvent(CGContextRef cx);

extern void FBConsoleClose(CGContextRef cx);

extern void FBEraseScreen(CGContextRef cx, NSRect rect);

extern void FBFlushCursor(CGContextRef cx);
extern void FBDrawCursor(CGContextRef cx);
extern void FBDrawCursorRect(CGContextRef cx, NSRect rect);
extern void FBRestoreCursorRect(CGContextRef cx, NSRect rect);

extern void FBDrawImage(CGContextRef cx, CGImage *c, NSPoint src, NSRect rect);


#else  /* !FB_GRAPHICS  **************************************** XR Graphics */


@interface NSGraphicsContext  (XRContext)

- (Display *) xDisplay;
- (Window) xRootWindow;
- (Window) xAppRootWindow;

@end


extern Drawable XRCreatePixmap(CGContextRef cx, int w, int h);
extern Drawable XRCreatePixmapMask(CGContextRef cx, CGImage *img);
extern Drawable XRCreatePixmapBitPlane(CGContextRef cx, CGImage *img);

extern void XRUpdateBitmap(CGContextRef cx, NSRect rect, CGImageRef ci);

extern Window XRFindWindow(CGContextRef cx, Window top, Window w, int x, int y);
extern int    XRSendString(CGContext *cx, Window w, const char *string);

extern void  XRSelectionRequest(CGContext *cx, XSelectionRequestEvent *xe);
extern void  XRSelectionNotify(CGContext *cx, XSelectionEvent *xe);

extern XImage *XRGetXImageFromRootWindow(CGContextRef cx, NSRect r);

extern void _CGContextDisableBitmapFlush(CGContextRef cx);

#endif

#endif /* _H_CGContext */
