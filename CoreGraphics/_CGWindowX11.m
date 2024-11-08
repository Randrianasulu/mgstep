/*
   _CGWindowX11.m

   X11 window category

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSApplication.h>


#ifndef FB_GRAPHICS

#define CTX				((CGContext *)_context)
#define CONTEXT			((CGContextRef)_context)
#define XDISPLAY		CTX->_display->xDisplay
#define XSCREEN			CTX->_display->_xScreen
#define XROOTWIN		CTX->_display->xRootWindow
#define SCREEN			CTX->_display
#define SCREEN_HEIGHT	CTX->_display->_frame.size.height
#define CTX_HAS_LUZ_WM  CTX->_display->_sf.hasLuzWM
#define XRGC			((CGContext *)CTX->_mg->_rcx)->_gs->xGC
#define XGC				CTX->_gs->xGC
#define GS_SIZE			CTX->_gs->xCanvas.size
#define XWINDOW			CTX->xWindow
#define XDRAWABLE		CTX->xDrawable
#define XPIXMAP			CTX->xPixmap
#define YOFFSET			CTX->_yOffset
#define TRANSIENTS		CTX->_mg->_transients

#define NOTE(n_name)	NSWindow##n_name##Notification



/* ****************************************************************************

	XR Window

** ***************************************************************************/

static BOOL
XRWindowIsVisible(Display *dpy, Window xWindow)
{
	XWindowAttributes wa;

	if (XGetWindowAttributes(dpy, xWindow, &wa))
		if (wa.map_state == IsViewable)						// viewable == 2
			return YES;

	return NO;
}


@implementation NSWindow  (XRBackend)

- (void) _initWindowBackend
{
	XRAttributes attrs = {0};
	XWMHints wm_hints = {0};
	Atom atoms[5];
	int na = 0;

	_w.deferred = NO;
	[_context _initWindowContext:_frame];

	if (_windowTitle)
		[self _setTitle];

	if (_styleMask != NSBorderlessWindowMask)
		{
		int y = SCREEN_HEIGHT - (int)(NSMaxY(_frame) + YOFFSET);
		XClassHint h;

		[self xSetSizeHints:(NSPoint){NSMinX(_frame),y}];
		h.res_class = "XRWindow";
		h.res_name = (char*)[[[NSProcessInfo processInfo] processName] cString];
		XSetClassHint(XDISPLAY, XWINDOW, &h);
		}

	wm_hints.initial_state = NormalState;			// set window manager hints
	wm_hints.input = True;		// requires WM assist in acquiring input focus
	wm_hints.flags = StateHint | InputHint;			// WindowMaker ignores the
	XSetWMHints(XDISPLAY, XWINDOW, &wm_hints);		// frame origin unless it's
													// also specified as a hint
	if (_styleMask & (NSClosableWindowMask | NSTitledWindowMask))
		{												// if window has close
		atoms[na++] = SCREEN->_deleteWindowAtom;		// button inform WM
		attrs.window_level = NSNormalWindowLevel;
		}
	else
		attrs.window_level = NSSubmenuWindowLevel;		// level for panels

	atoms[na++] = SCREEN->_takeFocusAtom;
	XSetWMProtocols(XDISPLAY, XWINDOW, atoms, na);

	if (_styleMask & NSTitledWindowMask)
		{
		PropMwmHints mhints = {0};						// set Motif WM
														// window style hints
		atoms[0] = XInternAtom(XDISPLAY, "_MOTIF_WM_HINTS", False);
		mhints.flags = MWM_HINTS_FUNCTIONS;
		mhints.functions = MWM_FUNC_MOVE;
		if (_styleMask & NSClosableWindowMask)
			mhints.functions |= MWM_FUNC_CLOSE;
		if (_styleMask & NSMiniaturizableWindowMask)
			mhints.functions |= MWM_FUNC_MINIMIZE;
		if (_styleMask & NSResizableWindowMask)
			mhints.functions |=  MWM_FUNC_RESIZE | MWM_FUNC_MAXIMIZE;
		XChangeProperty(XDISPLAY, XWINDOW, atoms[0], atoms[0],
						32, PropModeReplace, (unsigned char *)&mhints,
						sizeof(PropMwmHints)/sizeof(CARD32));
		}
														// set Luz WM
	atoms[0] = SCREEN->_windowDecorAtom;				// window style hints
	attrs.flags = XRWindowStyle | XRWindowLevel;
	attrs.window_style = _styleMask;
	XChangeProperty(XDISPLAY, XWINDOW, atoms[0], atoms[0],
					32, PropModeReplace, (unsigned char *)&attrs,
					sizeof(XRAttributes)/sizeof(CARD32));
}

- (void) setAspectRatio:(NSSize)aSize
{
	NSSize a = _aspectRatio;

	_aspectRatio = aSize;
	if (a.width == 0 && a.height == 0)
		{
		int y = SCREEN_HEIGHT - (int)(NSMaxY(_frame) + YOFFSET);
		XClassHint h;

		[self xSetSizeHints:(NSPoint){NSMinX(_frame),y}];
		}
}

- (void) _setTitle
{
	if (_windowTitle && XWINDOW)
		{
		const char *newTitle = [_windowTitle cString];
		XTextProperty windowName;

		XStringListToTextProperty((char**)&newTitle, 1, &windowName);
		XSetWMName(XDISPLAY, XWINDOW, &windowName);
		XSetWMIconName(XDISPLAY, XWINDOW, &windowName);
		}
}

- (void) setDocumentEdited:(BOOL)flag					// mark doc as edited
{
	Atom atom = SCREEN->_windowDecorAtom;
	XRAttributes attrs = {0};

	_w.isEdited = flag;
	[NSApp updateWindowsItem: self];

	attrs.flags = XRExtraFlags;							// set WM style hints
	attrs.extra_flags = (_w.isEdited) ? XRDocumentEditedFlag : 0;

	XChangeProperty(XDISPLAY, XWINDOW, atom, atom,
					32, PropModeReplace, (unsigned char *)&attrs,
					sizeof(XRAttributes)/sizeof(CARD32));
}

- (void) _orderFront
{
	if (_w.miniaturized)
		{
		Atom a = SCREEN->_stateAtom;
		unsigned long data[2] = { NormalState, None };
		unsigned char *d = (unsigned char*)data;

		XChangeProperty(XDISPLAY, XWINDOW, a, a, 32, PropModeReplace, d, 2);
		}

	XMapRaised(XDISPLAY, XWINDOW);				// place window on screen
}

- (void) _orderOut:(BOOL)fullRemoval
{
	if (fullRemoval)							// permanent removal from
		[TRANSIENTS removeObject:self];			// screen if app is not hidden
	if ((XWINDOW != None))
		XUnmapWindow(XDISPLAY, XWINDOW);
	XFlush(XDISPLAY);
}														

- (void) orderBack:(id)sender
{
	if (_w.visible)							
		XLowerWindow(XDISPLAY, XWINDOW);
}

- (void) _becomeTransient
{
	NSWindow *w;

	if ((w = [NSApp mainWindow]))
		{									// set WM_TRANSIENT_FOR
NSLog(@"set as X transient of %@ with id %lu", [w title], [w xWindow]);
		XSetTransientForHint(XDISPLAY, XWINDOW, [w xWindow]);
		[TRANSIENTS addObject: self];
		}
	else
		NSLog(@"unable to become transient, no main window");
	[self xSetInputFocus];
}

- (void) _becomeOwnerOfTransients
{
	int count = [TRANSIENTS count];			// set self as owner of any
											// transients if we can be main
	while (count--)
		{
		NSWindow *w = [TRANSIENTS objectAtIndex: count];

		XSetTransientForHint(XDISPLAY, [w xWindow], XWINDOW);
		}
	[self xSetInputFocus];
}

- (void) _miniaturize
{
	XIconifyWindow(XDISPLAY, XWINDOW, XSCREEN);
}

- (void) _setFrameTopLeftPoint:(NSPoint)p
{
	XMoveWindow(XDISPLAY, XWINDOW, (int)p.x, (int)p.y);
}

- (void) _setFrame:(NSRect)rect withHint:(int)hint
{
	BOOL resize = !NSEqualSizes(_frame.size, rect.size);
	int w = (int)NSWidth(rect);
	int h = (int)NSHeight(rect);

	DBLog(@"_setFrame:toRect: ((%f, %f), (%f, %f))",
			NSMinX(rect), NSMinY(rect), NSWidth(rect), NSHeight(rect));

	if (hint)	// 0 = X11 event, 1 = AppKit method 
		{
		BOOL move = !NSEqualPoints(_frame.origin, rect.origin);
		int x = (int)rect.origin.x;
		int y = (int)rect.origin.y;

		if (!XWINDOW)	// FIX ME for future deferred window creation
			[NSException raise:NSGenericException format:@"No X Window"];

		if (move && resize)
			XMoveResizeWindow (XDISPLAY, XWINDOW, x, y, w, h);
		else if (resize)
			XResizeWindow(XDISPLAY, XWINDOW, w, h);
		else
			XMoveWindow (XDISPLAY, XWINDOW, x, y);

		if (!resize)
			[self xSetSizeHints:rect.origin];
		if (move && _delegate)
			[NSNotificationCenter post: NOTE(DidMove) object: self];
		if (!resize)
			return;
		}

	_frame.origin = (NSPoint){NSMinX(rect), SCREEN_HEIGHT - NSMaxY(rect)};

	if (resize || _w.showingModalFrame)
		{											 
		Drawable backstor = None;

		DBLog(@"*** _setWindowFrame:  old: ((%f, %f), new: (%f, %f))",
			  NSWidth(_frame), NSHeight(_frame), NSWidth(rect), NSHeight(rect));

		if (_w.backingType != NSBackingStoreNonretained)
			backstor = XPIXMAP;

		if (_w.visible)								// re-enabled by a flush
			_CGContextDisableBitmapFlush( (CGContextRef)_context);
		CTX->_f.disableWindowFlush = YES;			// NSDisableScreenUpdates()

		_frame.size = rect.size;
		GS_SIZE = rect.size;
		XPIXMAP = None;
		XDRAWABLE = [self xDrawable];				// create new backing store

		if (backstor != None)	// copy existing content to new backing store
			XCopyArea (XDISPLAY, backstor, XPIXMAP, XGC, 0, 0, w, h, 0, 0);

		if (XPIXMAP != None && XPIXMAP != XWINDOW)	// CWBackPixmap
			XSetWindowBackgroundPixmap(XDISPLAY, XWINDOW, XPIXMAP);

		if (backstor != None)
			XFreePixmap (XDISPLAY, backstor);

		if (_contentView) 			// inform content view  of the frame change
			{
			[_contentView setFrame:(NSRect){{0,0},_frame.size}];
			[_contentView setNeedsDisplayInRect:(NSRect){{0,0},_frame.size}];
			if (_w.visible && !_w.showingModalFrame && CTX_HAS_LUZ_WM)
				[_contentView viewWillStartLiveResize];
			}

		_w.showingModalFrame = resize;
		CTX->_f.disableWindowFlush = NO;			// post notification
		[NSNotificationCenter post: NOTE(DidResize) object:self];

		if (_w.visible)
			{
			NSView *focusView = [NSView focusView];

			[self resetCursorRects];

			if (focusView && [focusView window] == self)
				{
				[focusView unlockFocus];			// size change invalidated
				[focusView lockFocus];				// focus coords, re-lock
				}
			if (!resize && CTX_HAS_LUZ_WM)
				[_contentView viewDidEndLiveResize];
			if (_w.backingType != NSBackingStoreNonretained)
				[self display];						// redisplay window
		}	}

	if (!XDRAWABLE && (XDRAWABLE = [self xDrawable]) && _contentView)
		[_contentView setNeedsDisplayInRect:(NSRect){{0,0},_frame.size}];
}
													// return default drawing
- (Drawable) xDrawable								// canvas. (backing store
{													// if window has one) 
	if (_w.backingType == NSBackingStoreNonretained)
		return XWINDOW;

	if (!XPIXMAP)									// extended size produces
		{											// fewer resizing artifacts
		XPIXMAP = XRCreatePixmap(CONTEXT, NSWidth(_frame), NSHeight(_frame)+80);

#ifdef CAIRO_GRAPHICS
		_cairo_set_surface_for_window(CTX, self);
#else
		_CGContextSetWindowCanvas(CTX, self);
#endif
		CTX->_layer = _CGContextWindowBackingLayer(CONTEXT, _frame.size);
		}

	return XPIXMAP;
}

- (BOOL) xExposedRectangle:(XRectangle)r			// process expose event
{
	if (_w.backingType != NSBackingStoreNonretained)
		{											// window has backing store
		PSgsave();

		[_backgroundColor set];
													// copy exposed rect
		XCopyArea(XDISPLAY, XPIXMAP, XWINDOW, XGC,	// from pixmap backing
					r.x, r.y, r.width, r.height, r.x, r.y);
		PSgrestore();								// Restore graphics state

		return YES;
		}											// no backing store, so add 
													// rect to invalid rect
	_exposeRect = NSUnionRect(_exposeRect,
							  (NSRect){{r.x, r.y}, {r.width, r.height}});
	return NO;
}

- (void) xProcessExposedRectangles					// window has no backing
{													// and expose count is 0
	_exposeRect.origin.y = (_frame.size.height - NSMaxY(_exposeRect));
	[_contentView displayRectIgnoringOpacity:_exposeRect];
	_exposeRect = NSZeroRect;
}

- (void) xSetInputFocus
{
	if (!_w.miniaturized)
		if (_w.visible || (_w.visible = XRWindowIsVisible(XDISPLAY, XWINDOW)))
			{
NSLog(@"setInputFocus");
			XRaiseWindow(XDISPLAY, XWINDOW);
			XSetInputFocus(XDISPLAY, XWINDOW, RevertToNone, CurrentTime);
			}
}

- (void) xSetSizeHints:(NSPoint)org					// WM ignores frame origin
{													// unless it's also a hint
	XSizeHints size_hints = {0};

	size_hints.x = (int)org.x;
	size_hints.y = (int)org.y;
	size_hints.flags = PPosition | USPosition;		// WM can override Program
													// position but not User
	if (_aspectRatio.width > 0 && _aspectRatio.height > 0)
		{
		size_hints.min_aspect.x = (int)(_aspectRatio.width * 100000);
		size_hints.min_aspect.y = (int)(_aspectRatio.height * 100000);
		size_hints.max_aspect.x = (int)(_aspectRatio.width * 100000);
		size_hints.max_aspect.y = (int)(_aspectRatio.height * 100000);
		size_hints.flags |= PAspect;
		}

	if (_resizeIncrements.width > 0 && _resizeIncrements.height > 0)
		{
		size_hints.width_inc = (int)_resizeIncrements.width;
		size_hints.height_inc = (int)_resizeIncrements.height;
		size_hints.flags |= PResizeInc;
		}

	size_hints.min_width = (int)_minSize.width;
	size_hints.min_height = (int)_minSize.height;
	size_hints.max_width = (int)_maxSize.width;
	size_hints.max_height = (int)_maxSize.height;
	size_hints.flags |= PMinSize | PMaxSize;

	XSetNormalHints(XDISPLAY, XWINDOW, &size_hints);
}

- (unsigned long) xGetWindowAttributes:(XSetWindowAttributes *)wa
{
	unsigned long valuemask = (CWBackPixel | CWBorderPixel);

	wa->border_pixel = BlackPixel(XDISPLAY, XSCREEN);
	wa->background_pixel = [_backgroundColor xColor].pixel;

	if (_styleMask == NSBorderlessWindowMask)
		{
		if (!_w.appIcon)
			{
			wa->override_redirect = True;	  		// no border, X override
			valuemask |= CWOverrideRedirect;
			}
		valuemask |= CWSaveUnder;
		wa->save_under = True;
		}

	return valuemask;
}

- (int) xGrabMouse
{
	return XGrabPointer(XDISPLAY, XWINDOW, False,
					   PointerMotionMask | ButtonReleaseMask | ButtonPressMask,
					   GrabModeAsync, GrabModeAsync, None, None, CurrentTime);
}

- (int) xReleaseMouse
{
	return XUngrabPointer(XDISPLAY, CurrentTime);
}

- (Window) xWindow						{ return XWINDOW; }
- (GC) xGC								{ return XGC; }
- (GC) xRootGC							{ return XRGC; }
- (void) xTossFirstEvent				{ _w.tossFirstEvent = YES; }

- (void) xSetMapped:(BOOL)flag
{
	if (flag != _w.visible)
		{
		_w.visible = flag;
		if (flag && _w.needsFlush)
			[self flushWindow];
		}
}

- (NSPoint) xParentOffset
{
	if (!YOFFSET)
		{
		Window *children, root, parent, r;
		unsigned int nchld;
		int x, y;

		if (!XQueryTree(XDISPLAY, XWINDOW, &root, &parent, &children, &nchld))
			return NSZeroPoint;

		if (children)
			XFree((char *)children);

		if (XTranslateCoordinates(XDISPLAY, XWINDOW, parent, 0, 0, &x, &y, &r))
			{
			CTX->_xOffset = x;
			YOFFSET = y;
		}	}

	return (NSPoint){(float)CTX->_xOffset, (float)YOFFSET};
}

- (NSRect) xFrame
{
	Window r;
	int x, y;

	XTranslateCoordinates(XDISPLAY, XWINDOW, XROOTWIN, 0, 0, &x, &y, &r);

	return (NSRect){x-1, y-1, _frame.size};
}

@end  /* NSWindow  (XRWindow) */

#endif
