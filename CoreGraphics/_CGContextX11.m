/*
   _CGContextX11.m

   Xlib graphics interface

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>


#ifndef FB_GRAPHICS

#define CTX				((CGContext *)cx)
#define XDRAWABLE		CTX->xDrawable
#define XPIXMAP			CTX->xPixmap
#define XWINDOW			CTX->xWindow
#define WINDOW			CTX->_window
#define XROOTWIN		CTX->_display->xRootWindow
#define XDISPLAY		CTX->_display->xDisplay
#define XDEPTH			CTX->_display->_depth
#define XVISUAL			CTX->_display->_visual
#define GSTATE			CTX->_gs
#define ISFLIPPED		CTX->_gs->isFlipped
#define CONTEXT			((CGContext *)cx)->_mg->_ctx
#define XRGC			((CGContext *)CTX->_mg->_rcx)->_gs->xGC
#define XGC				CTX->_gs->xGC
#define XCANVAS			CTX->_gs->xCanvas
#define CTM				CTX->_gs->hasCTM
#define FLUSH_ME		CTX->_flushRect

#define ALPHA_THRESHOLD  158
												// convert Y coord to X11 device
												// space per flipped state
#define NO_FLIP_TO_X(a, b)  (NSHeight(b) - NSMinY(a) - NSMinY(b) - NSHeight(a))
#define	CONVERT_Y(a, b, f)	((f) ? NSMinY(a) + NSMinY(b) : NO_FLIP_TO_X(a, b))



void _CGContextInitDisplay(CGContextRef cx)
{
	CGDisplay *d = (CGDisplay *)[_NSScreen alloc];

	((CGContext *)cx)->_display = _CGInitDisplay( d );
	[(CTX->_gs = _CGContextGetGState(cx, _CGContextAllocGState(cx))) init];
	_CGContextInitBlendModes(cx);
}

void
_CGContextInitWindow(CGContext *cx, NSRect f)
{
	XSetWindowAttributes wa = {0};
	XRectangle r = {(int)f.origin.x, (int)f.origin.y,
					(int)f.size.width, (int)f.size.height};
	unsigned long valuemask = [cx->_window xGetWindowAttributes: &wa];

	[cx->_gs init];										// init gState

	cx->xWindow = XCreateWindow(XDISPLAY, XROOTWIN, r.x, r.y, r.width, r.height,
								0,
								CopyFromParent,			// create an X window
								CopyFromParent,
								CopyFromParent,
								valuemask, &wa);

	XSelectInput(XDISPLAY, cx->xWindow, XREventMask );	// desired X events mask
}

void NSBeep(void)
{
	XBell([[NSGraphicsContext currentContext] xDisplay], 50);
}

void
_x11_release_context(CGContextRef cx)
{
	Window w = CTX->xWindow;
	Pixmap p = CTX->xPixmap;

	CTX->xPixmap = CTX->xWindow = CTX->xDrawable = None;
	if (w)
		XDestroyWindow(XDISPLAY, w);				// Destroy the X Window
	if (p)
		XFreePixmap(XDISPLAY, p);

#ifdef CAIRO_GRAPHICS
	_cairo_release (cx);
#endif
}

void CGContextSynchronize (CGContextRef cx)
{
	XSync(XDISPLAY, False);
}

/* ****************************************************************************

	X11 utility functions

	XRSendString 	send a text string to an X window
	XRFindWindow	find lowest X window for a given global coordinate
	xSendKeyCode	send a KeyCode to an X window
	xSendKeysym		send a Keysym to an X window

** ***************************************************************************/

static int
xSendKeyCode(Display *display, Window window, KeyCode keycode, int state)
{
	XKeyEvent event;								// Send a keycode to an X
	int status;										// window
	XEvent *xEvent;

    event.type        = KeyPress;					// fill in all fields of
    event.display     = display;					// the event structure.
    event.window      = window;	
    event.root        = RootWindow(display, DefaultScreen(display));
    event.keycode     = keycode;
    event.state       = state;
    event.time        = CurrentTime;
    event.same_screen = True;
    event.x           = 0;
    event.y           = 0;
    event.x_root      = 0;
    event.y_root      = 0;
    event.subwindow   = (Window)None;

	xEvent = (XEvent *)&event;
	status = XSendEvent(display, window, False, KeyPressMask, xEvent);

    if (status != 0) 								// if send is successful
		{											// send a KeyRelease event
        event.type = KeyRelease;					// for each KeyPress event
        event.time = CurrentTime;					// sent

        status = XSendEvent(display, window, True, KeyReleaseMask, xEvent);
		}

    return status;
}   

static int
xSendKeysym(Display *display, Window window, KeySym ks)
{
	KeyCode	keycode;								// send KeySym to X window
	int status = 0;
	int state = 0;

    if (ks != NoSymbol)
		{
        if ((( ks >= XK_greater ) && ( ks <= XK_Z ))
				|| (  ks == XK_underscore ) || ( ks == XK_asciicircum )
				|| (  ks == XK_colon )      || ( ks == XK_less )
				|| (( ks >= XK_exclam )     && ( ks <= XK_ampersand ))
				|| (( ks >= XK_braceleft )  && ( ks <= XK_asciitilde ))
				|| (( ks >= XK_parenleft )  && ( ks <= XK_plus ))) 
            state = ShiftMask;			// set shift on keysyms that require it
										// translate Keysym to Keycode and send
        if ((keycode = XKeysymToKeycode(display, ks)) != 0)
            status = xSendKeyCode( display, window, keycode, state );
    	}

    return status;
}

int
XRSendString(CGContext *cx, Window window, const char *string)
{
	int	i, status = 0;						// send a text string to another X
											// window as a series of KeyPress
    for (i = 0; string[i] != '\0'; i++)		// and KeyRelease events
		{
		if (string[i] == '\n')
			status = xSendKeysym(XDISPLAY, window, XK_Return);	// send CR
		else
        	if ((status = xSendKeysym(XDISPLAY, window, string[i])) == 0)
				break;						// return immediately on errors
    	}

    XFlush(XDISPLAY);

    return status;
}

Window
XRFindWindow(CGContextRef cx, Window top, Window win_to_check, int x, int y)
{
	int newx, newy;
	Window window = win_to_check;

    if (top == (Window)None)
		{
		NSLog(@"XRFindWindow() top window == (Window)None\n");

        return (Window)None;
    	}

    if (win_to_check == (Window)None)
		{
		NSLog(@"XRFindWindow() win_to_check == (Window)None\n");

        return top;
    	}

    while ((XTranslateCoordinates( XDISPLAY, top, win_to_check,
									x, y, &newx, &newy, &window) != 0 ) 
									&& (window != (Window)None)) 
		{
        if (window != (Window)None) 		// find the lowest X window in the
			{								// heirarchy that the global x, y
            top = win_to_check;				// coordinates are in by iterating
            win_to_check = window;			// thru the X window's heirarchy
            x = newx;						// while XTranslateCoordinates
            y = newy;						// returns an X Window in 'window'
       	}	}

    if (window == (Window)None)
        window = win_to_check;

    return window;
}

Drawable
XRCreatePixmap(CGContextRef cx, int w, int h)
{
	Drawable d = None;

	if (w > 0 && h > 0)
		if ((d = XCreatePixmap(XDISPLAY, XROOTWIN, w, h, XDEPTH)) == None)
			NSLog (@"cannot create pixmap backing store!");

	DBLog(@"new backing: %d (%d, %d), depth = %d\n", d, w, h, XDEPTH);

	return d;
}

Drawable
XRCreatePixmapBitPlane(CGContextRef cx, CGImage *ci)
{
	Drawable d = None;

	if (ci->width > 0 && ci->height > 0 && ci->samplesPerPixel == 4)
		{
		CGFloat components[] = {ALPHA_THRESHOLD,255, 255,255, 255,255, 255,255};
		CGImageRef ni = _CGImageMaskCreateWithMaskingColors(ci, components);

		d = XCreatePixmapFromBitmapData(XDISPLAY, XROOTWIN, ni->idata,
										ni->width, ni->height, 1L, 0, 1);
		CGImageRelease(ni);
		}

	return d;
}

Drawable
XRCreatePixmapMask(CGContextRef cx, CGImage *ci)
{
	Drawable d = None;

	if (ci->width > 0 && ci->height > 0 && ci->samplesPerPixel == 4)
		{
		CGFloat components[] = {255,255, 255,255, 255,255, ALPHA_THRESHOLD,255};
		CGImageRef ni = _CGImageMaskCreateWithMaskingColors(ci, components);

		d = XCreatePixmapFromBitmapData(XDISPLAY, XROOTWIN, ni->idata,
										ni->width, ni->height, 1L, 0, 1);
		CGImageRelease(ni);
		}

	return d;
}

/* ****************************************************************************

	XRGetXImageFromRootWindow()

	Grab rect display root window.
	BadMatch error if rect lies outside of xdrawable.

** ***************************************************************************/

XImage *
XRGetXImageFromRootWindow(CGContextRef cx, NSRect r)
{
	NSRect screen = [(NSScreen *)CTX->_display frame];

	if (r.origin.x + NSWidth(r) > NSWidth(screen))
		r.origin.x = NSWidth(screen) - NSWidth(r);
	if (r.origin.y + NSHeight(r) > NSHeight(screen))
		r.origin.y = NSHeight(screen) - NSHeight(r);

	if (r.origin.x < 0 || r.origin.y < 0)
		{
		NSLog(@"XRGetXImageFromRootWindow: %f %f %f %f  root window: %f %f",
						r.origin.x, r.origin.y, NSWidth(r), NSHeight(r),
						NSWidth(screen), NSHeight(screen));
		return None;
		}

	return XGetImage(XDISPLAY, XROOTWIN, (int)r.origin.x, (int)r.origin.y,
					 (int)NSWidth(r), (int)NSHeight(r),
					 AllPlanes, ZPixmap);
}

CGImageRef _CGContextCreateImage(CGContextRef cx, CGSize z)
{
	int w = z.width;
	int h = z.height;
	unsigned m_sys_bpp = 32;	// also quantum of a scanline (8, 16, or 32)

	CGImageRef img = CGImageCreate( w, h, 8, 32, 0, NULL, 0, NULL, NULL, 0, 0);

	XImage *xi = XCreateImage( XDISPLAY,
							   XVISUAL, //CopyFromParent,
							   XDEPTH,
							   ZPixmap,
							   0,
							   (char*)img->idata,
							   w,
							   h,
							   m_sys_bpp, 			// bitmap_pad
							   w * (m_sys_bpp / 8));
	((CGImage *)img)->ximage = xi;
//	((CGImage *)img)->_f.bitmapInfo = _kCGBitmapByteOrderBGR;

	return img;
}

CGImageRef _CGContextResizeBitmap(CGContextRef cx, CGSize z)
{
	int w = z.width;
	int h = z.height;
	CGImageRef img = CTX->_bitmap;
	XImage *xi = ((CGImage *)img)->ximage;

	img = _CGImageResize( img, w, h);
	xi->width = img->width;
	xi->height = img->height;
	xi->bytes_per_line = img->bytesPerRow;
	xi->data = (char*)img->idata;

	return img;
}

/* ****************************************************************************

	XRUpdateBitmap	--  Reverse flush

	Update rect of bitmap XImage (ci) from the context's Drawable.

** ***************************************************************************/

void
XRUpdateBitmap(CGContextRef cx, NSRect rect, CGImageRef ci)
{
	NSPoint org;

	if (rect.size.width <= 0 || rect.size.height <= 0)
		return;

	org.y = CONVERT_Y(rect, XCANVAS, ISFLIPPED);
	org.x = NSMinX(rect) + NSMinX(XCANVAS);

	if(org.x < 0 || org.y < 0 || ((org.x + NSWidth(rect)) > NSWidth(XCANVAS))
			|| ((org.y + NSHeight(rect)) > NSHeight(XCANVAS)))
		{
		NSLog(@"XRUpdateXImage: %f %f %f %f  outside of buffer: %f %f",
				org.x, org.y, NSWidth(rect), NSHeight(rect),
				NSWidth(XCANVAS), NSHeight(XCANVAS));
		return;
		}

	XGetSubImage( XDISPLAY, XDRAWABLE,
				  (int)org.x, (int)org.y,
				  (int)NSWidth(rect), (int)NSHeight(rect),
				  AllPlanes,
				  ZPixmap,
				  ((CGImage *)ci)->ximage,
				  0, 0 );
}

void
XRContextCopyRect( CGContextRef srcGC, NSRect srcRect, NSPoint destPoint )
{
	CGContextRef cx = (CGContextRef)((CGContext *)srcGC)->_mg->_ctx;

	if (destPoint.x < 0 || destPoint.y < 0
			|| ((destPoint.x + NSWidth(srcRect)) > NSWidth(XCANVAS))
			|| ((destPoint.y + NSHeight(srcRect)) > NSHeight(XCANVAS)))
		{
		NSLog(@"XRContextCopyRect: %f %f %f %f  outside of buffer: %f %f",
				destPoint.x, destPoint.y, NSWidth(srcRect), NSHeight(srcRect),
				NSWidth(XCANVAS), NSHeight(XCANVAS));
		return;
		}									// FIX ME  validate src rect

	XCopyArea(XDISPLAY, ((CGContext *)srcGC)->xDrawable, XDRAWABLE, XGC,
				srcRect.origin.x, srcRect.origin.y,
				srcRect.size.width, srcRect.size.height,
				destPoint.x, destPoint.y);
}

/* ****************************************************************************

	Clip drawing

** ***************************************************************************/

void _CGContextSetClipRect(CGContextRef cx, NSRect rect)
{														// X coords are assumed
	if (rect.origin.y < 0)
		{
		NSLog (@"_CGContextSetClipRect error: negative clip rect origin");
		return;											// should not happen
		}

#ifdef CAIRO_GRAPHICS
	_cairo_reset_clip (cx);
	_cairo_clip_rect(cx, rect);
#else
	_clip_reset(cx);
	_clip_rect(cx, rect);
#endif
}

void CGContextClipToRect(CGContextRef cx, CGRect rect)
{
	NSRect b;

	if (CTM)
		rect = CGRectApplyAffineTransform( rect, GSTATE->_ctm);

	b = (NSRect){{NSMinX(rect) + XCANVAS.origin.x, NSMinY(rect)}, rect.size};
	NSMinY(b) = CONVERT_Y(b, XCANVAS, ISFLIPPED);
													// FIX ME intersect w/clip
#ifdef CAIRO_GRAPHICS
	_cairo_clip_rect(cx, b);
#else
	_clip_rect(cx, b);
#endif
}

void _CGContextRectNeedsFlush(CGContextRef cx, CGRect r)
{
	if (r.origin.x < 0 || r.origin.y < 0 || r.size.width > XCANVAS.size.width
										 || r.size.height > XCANVAS.size.height)
		{
		NSLog (@"FIX ME Flush Rect (%f, %f) (%f, %f)\n",
				r.origin.x, r.origin.y, r.size.width, r.size.height);
		if (r.origin.x < 0)
			r.origin.x = 0;
		if (r.origin.y < 0)
			r.origin.y = 0;
		if (r.size.width < 0 || r.size.width > XCANVAS.size.width)
			r.size.width = XCANVAS.size.width;
		if (r.size.height < 0 || r.size.height > XCANVAS.size.height)
			r.size.height = XCANVAS.size.height;
		}

	FLUSH_ME = NSUnionRect(FLUSH_ME, r);

	DBLog (@"FlushPixmap (%f, %f) (%f, %f)\n",
			FLUSH_ME.origin.x, FLUSH_ME.origin.y,
			FLUSH_ME.size.width, FLUSH_ME.size.height);

	if (CTX->_window)
		[CTX->_window _needsFlush];
}

void CGContextFlush( CGContextRef cx)
{
	int x = FLUSH_ME.origin.x;				// width/height requires
	int y = FLUSH_ME.origin.y;				// +1 pixel to copy out
	int width = FLUSH_ME.size.width + 1;
	int height = FLUSH_ME.size.height + 1;

	DBLog(@"FlushPixmap X rect (%d, %d), (%d, %d)", x, y, width, height);

	if (CTX->_f.disableWindowFlush)
		return;

	if (CTX->_f.dirtyBitmap)
		{
		CGImage *img = (CGImage *)((CGContext *)cx)->_bitmap;

		CTX->_f.disableBitmapFlush = NO;
		CTX->_f.dirtyBitmap = NO;
		if (img && x >= 0 && y >= 0 && width > 0 && height > 0)
			{
			XImage *xImage = img->ximage;

			XPutImage(XDISPLAY, XPIXMAP, XRGC, xImage, x, y, x, y, width, height);
		}	}

	XCopyArea(XDISPLAY, XPIXMAP, XWINDOW, XRGC, x, y, width, height, x, y);

	FLUSH_ME = NSZeroRect;
}

void
_CGContextFlushBitmap(CGContextRef cx, int x, int y, int xm, int ym)
{
	int width = xm - x;
	int height = ym - y;
	CGImage *img = (CGImage *)((CGContext *)cx)->_bitmap;

	DBLog (@"FlushBitmap canvas (%f, %f) (%f, %f)\n",
			FLUSH_ME.origin.x, FLUSH_ME.origin.y,
			FLUSH_ME.size.width, FLUSH_ME.size.height);

	if (CTX->_f.disableBitmapFlush)
		{
		CTX->_f.dirtyBitmap = YES;
		return;
		}

	DBLog(@"FlushBitmap X rect (%d, %d), (%d, %d)", x, y, width, height);

	if (img && x >= 0 && y >= 0 && width > 0 && height > 0 && XPIXMAP)
		{
		XImage *xImage = img->ximage;

		XPutImage(XDISPLAY, XPIXMAP, XRGC, xImage, x, y, x, y, width, height);
		}
}

void
_CGContextBitmapNeedsFlush(int x, int y, int xm, int ym)
{
//	_CGContextRectNeedsFlush( _CGContext(), (CGRect){{x, y}, {xm-x,ym-y}});
	_CGContextFlushBitmap( _CGContext(), x, y, xm, ym);
}

void _CGContextDisableBitmapFlush(CGContextRef cx)
{
	CTX->_f.disableBitmapFlush = YES;
}

/* ****************************************************************************

	Graphic state object

** ***************************************************************************/

@implementation _GState

- (id) init
{
	CGContext *cx = (CGContext *)context;

	xGC = XCreateGC(XDISPLAY, XROOTWIN, 0, 0);
	CGContextSetBlendMode( (CGContextRef)cx, cx->_gs->blendMode);

	return self;
}

- (void) dealloc
{
	CGContext *cx = (CGContext *)context;

	if (!cx || !cx->_display || !XDISPLAY)
		{
		NSLog(@"_GState -- dealloc: Invalid context *********** ");
		cx = (CGContext *)CONTEXT;
		}
	if (!cx || !cx->_display || !XDISPLAY)
		NSLog(@"_GState -- dealloc: Invalid current context ** ");
	else if (xGC && XFreeGC(XDISPLAY, xGC) == BadGC)
		NSLog(@"_GState -- XFreeGC(): BadGC");

	if (_line.dash.lengths)
		free(_line.dash.lengths),	_line.dash.lengths = NULL;

	[super dealloc];
}

@end  /* _GState */

#endif  /* !FB_GRAPHICS   */
