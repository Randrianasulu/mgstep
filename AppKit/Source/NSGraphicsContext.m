/*
   NSGraphicsContext.m

   Graphics destination management.

   Copyright (C) 1998-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>

#include <CoreFoundation/CFRunLoop.h>
#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSView.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>


#define CONTEXT		__gcMeta->_ctx
#define GS_ARRAY	__gcMeta->_gStateArray
#define TAG_MAP		__gcMeta->_winToTag
#define WIN_MAP		__gcMeta->_winToX11
#define WINDOW		((CGContext *)CONTEXT)->_window
#define FOCUS_VIEW	((CGContext *)CONTEXT)->_gs->focusView
#define XCANVAS		((CGContext *)CONTEXT)->_gs->xCanvas
#define ISFLIPPED	((CGContext *)CONTEXT)->_gs->isFlipped
#define CTX			((CGContextRef)CONTEXT)

typedef struct _NSView_t  { @defs(NSView); } _NSView;


static _GCMeta __GraphicsContextMeta = {0};
static _GCMeta *__gcMeta = &__GraphicsContextMeta;

static IMP __nextEventIMP = NULL;



@implementation NSGraphicsContext

+ (void) initialize
{
	TAG_MAP = NSCreateMapTable( NSIntMapKeyCallBacks,
								NSNonRetainedObjectMapValueCallBacks, 20);
	GS_ARRAY = [[NSMutableArray arrayWithCapacity:16] retain];
}

+ (id) alloc
{
	return NSAllocateObject([_NSGraphicsContext class]);
}

+ (void) setGraphicsState:(int)gState
{
	_GState *gs = _CGContextGetGState((CGContextRef)CONTEXT, gState);
											// make gState's context current
	CONTEXT = (NSGraphicsContext *)gs->context;
	((CGContext *)CONTEXT)->_gs = gs;
}

+ (id) currentContext					{ return CONTEXT; }
+ (void) setCurrentContext:(id)context	{ CONTEXT = context; }
+ (void) saveGraphicsState				{ [CONTEXT saveGraphicsState]; }
+ (void) restoreGraphicsState			{ [CONTEXT restoreGraphicsState]; }
- (void) saveGraphicsState		{ CGContextSaveGState((CGContextRef)self); }
- (void) restoreGraphicsState	{ CGContextRestoreGState((CGContextRef)self); }
- (void) flushGraphics					{ CGContextFlush((CGContextRef)self); }
- (void *) graphicsPort					{ return (CGContextRef)self; }
+ (BOOL) currentContextDrawingToScreen	{ return [CONTEXT isDrawingToScreen]; }
- (BOOL) isDrawingToScreen				{ return NO; }
- (BOOL) isFlipped						{ return NO; }

+ (NSGraphicsContext *) graphicsContextWithGraphicsPort:(void *)graphicsPort
												flipped:(BOOL)isFlipped
{
	CGContext *cx = (CGContext *)[NSGraphicsContext alloc];

	if (graphicsPort == NULL)
		graphicsPort = (CGContextRef)[NSApp context];

	memcpy(cx, ((CGContext *)graphicsPort), sizeof(CGContext));
	cx->_layer = NULL;			// app CTX layer points at FB
	cx->_bitmap = NULL;
	cx->_gState = _CGContextAllocGState(graphicsPort);
	cx->_gs = _CGContextGetGState((CGContextRef)cx, cx->_gState);
	cx->_gs->context = (NSGraphicsContext *)cx;
	cx->_gs->isFlipped = isFlipped;

	return [(NSGraphicsContext *)cx autorelease];
}

+ (NSGraphicsContext *) graphicsContextWithWindow:(NSWindow *)window
{
	NSGraphicsContext *cx = [window graphicsContext];

	cx = [NSGraphicsContext graphicsContextWithGraphicsPort:cx flipped:YES];
	((CGContext *)cx)->_f.isWindow = YES;
	((CGContext *)cx)->_window = window;

	return cx;
}

+ (NSGraphicsContext *) graphicsContextWithBitmapImageRep:(NSBitmapImageRep *)b
{
	NSGraphicsContext *cx;

	cx = [NSGraphicsContext graphicsContextWithGraphicsPort:NULL flipped:YES];
	((CGContext *)cx)->_f.isBitmap = YES;
	((CGContext *)cx)->_gs->imageRep = [b retain];
	((CGContext *)cx)->_gs->xCanvas.size = [b size];

	return cx;
}

- (id) init
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc addObserver: self
		selector: @selector(_appWillTerminate)
		name: NSApplicationWillTerminateNotification
		object: NSApp];

	CONTEXT = self;

	__gcMeta->_transients = [NSMutableArray new];
	__nextEventIMP = [CONTEXT methodForSelector: @selector(_nextEvent:)];

	return self;
}

- (void) dealloc
{
	if (CONTEXT == self)
		CONTEXT = [NSApp context];
	NO_WARN;
}

@end  /* NSGraphicsContext */


CGContextRef _CGContext(void)			{ return ((CGContextRef)CONTEXT); }

/* ****************************************************************************

	FB Context

** ***************************************************************************/

#ifdef FB_GRAPHICS  /* ******************************************* FBContext */

static void
_KB(CFSocketRef s, CFSocketCallBackType t, CFDataRef a, const void *d, void *cb)
{
	FBGetKeyEvent((CGContextRef)cb);
}

static void
_MS(CFSocketRef s, CFSocketCallBackType t, CFDataRef a, const void *d, void *cb)
{
	FBGetMouseEvent((CGContextRef)cb);
}


@implementation _NSGraphicsContext

- (id) init
{
	if ((self = [super init]))
		{
		_mg = __gcMeta;
		_mg->_rcx = _mg->_ctx = self;
		_fb.context = (CGContextRef)self;
		_fb._ly.dontFree = YES;
		_layer = &_fb;
		_CGContextInitDisplay((CGContextRef)self);
		[[NSCursor arrowCursor] push];
		}

	return self;
}

- (BOOL) isDrawingToScreen				{ return _f.isWindow; }
- (BOOL) isFlipped						{ return _gs->isFlipped; }
- (void) _appWillTerminate				{ FBConsoleClose((CGContextRef)self); }
- (void) _nextEvent:(id)sender			{ }

- (void) _listenForEvents:(id)queue
{
	id modes[] = { NSDefaultRunLoopMode, NSModalPanelRunLoopMode, 
						NSEventTrackingRunLoopMode };
	CFOptionFlags fl = kCFSocketReadCallBack;
	CFSocketContext sx = { 1, self, NULL, NULL, NULL };
	CFSocketRef cfs = CFSocketCreateWithNative(NULL, _mg->_console, fl, &_KB, &sx);
	CFRunLoopSourceRef rs;
	int i;

	if ((rs = CFSocketCreateRunLoopSource(NULL, cfs, 0)) == NULL)
		[NSException raise:NSGenericException format:@"CFSocket init error"];
	for (i = 0; i < 3; i++)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), rs, (CFStringRef)modes[i]);
    CFRelease(rs);

	cfs = CFSocketCreateWithNative(NULL, _mg->_mouse, fl, &_MS, &sx);
	if ((rs = CFSocketCreateRunLoopSource(NULL, cfs, 0)) == NULL)
		[NSException raise:NSGenericException format:@"CFSocket init error"];
	for (i = 0; i < 3; i++)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), rs, (CFStringRef)modes[i]);
    CFRelease(rs);
	__gcMeta->_appEventQueue = queue;
}

- (void) _initWindowContext:(NSRect)f
{
	int y = _display->_frame.size.height - (int)(NSMaxY(f) + 0);

	NSMapInsert (TAG_MAP, (void *)_gState, _window);

	[_window _setFrame:(NSRect){{NSMinX(f), y}, f.size} withHint:0];
}

- (void) _releaseWindowContext							// disables window CTX
{														// when window deallocs
	NSMapRemove(TAG_MAP, (void*)_gState);
	_CGContextRelease((CGContextRef)self);
}

@end  /* FBContext */

#else  /* ******************************************************** XRContext */

/* ****************************************************************************

	XR Context

** ***************************************************************************/

static void
_XE(CFSocketRef s, CFSocketCallBackType t, CFDataRef a, const void *d, void *cb)
{
	(*__nextEventIMP)((NSGraphicsContext *)cb, @selector(_nextEvent:), cb);
}


@implementation _NSGraphicsContext

- (id) init
{
	if ((self = [super init]))
		{
		_mg = __gcMeta;
		_mg->_rcx = _mg->_ctx = self;
		_CGContextInitDisplay(CTX);
		WIN_MAP = NSCreateMapTable( NSNonOwnedPointerMapKeyCallBacks,
									NSNonRetainedObjectMapValueCallBacks, 20);
		[[NSCursor arrowCursor] push];
		}

	return self;
}

- (Display *) xDisplay					{ return _display->xDisplay; }
- (Window) xAppRootWindow				{ return _display->xAppRootWindow; }
- (Window) xRootWindow					{ return _display->xRootWindow; }
- (BOOL) isDrawingToScreen				{ return _f.isWindow; }
- (BOOL) isFlipped						{ return _gs->isFlipped; }
- (void) _appWillTerminate				{ }

- (void) _nextEvent:(id)sender
{
	int count = XPending( _display->xDisplay );

	while (count-- > 0)
		{
		XEvent xe;

		XNextEvent (_display->xDisplay, &xe);
		XRProcessEvent ((CGContext *)self, &xe);
		}
}

- (void) _listenForEvents:(id)queue
{
	int xd = XConnectionNumber(_display->xDisplay);
	CFSocketContext sx = { 1, self, NULL, NULL, NULL };
	CFOptionFlags fl = kCFSocketReadCallBack;
	CFSocketRef cfs = CFSocketCreateWithNative( NULL, xd, fl, &_XE, &sx);
	CFRunLoopSourceRef rs;

	if ((rs = CFSocketCreateRunLoopSource(NULL, cfs, 0)) == NULL)
		[NSException raise:NSGenericException format:@"CFSocket init error"];
	CFRunLoopAddSource(CFRunLoopGetCurrent(), rs, kCFRunLoopCommonModes);
    CFRelease(rs);
	__gcMeta->_appEventQueue = queue;
}

- (void) _initWindowContext:(NSRect)f
{
	int y = _display->_frame.size.height - (int)(NSMaxY(f) + 0);	// X scr coords
	
	_CGContextInitWindow((CGContextRef)self, (NSRect){{NSMinX(f), y}, f.size});

	NSMapInsert (TAG_MAP, (void *)_gState, _window);
	NSMapInsert (WIN_MAP, (void *)xWindow, _window);	// NS win to X win map

	[_window _setFrame:(NSRect){{NSMinX(f), y}, f.size} withHint:0];
}

- (void) _releaseWindowContext							// disables window CTX
{														// when window deallocs
	NSMapRemove(WIN_MAP, (void*)xWindow);				// Remove from X to NS
	NSMapRemove(TAG_MAP, (void*)_gState);				// windows mapping
	_CGContextRelease((CGContextRef)self);
}

@end  /* XRContext */


NSWindow *
XRWindowWithXWindow(Window xWindow)
{
	return NSMapGet(WIN_MAP, (void*)xWindow);
}

#endif  /* ******************************************************* XRContext */

/* ****************************************************************************

	NSView  (AppKitBackend)

** ***************************************************************************/

@implementation NSView  (AppKitBackend)

- (void) allocateGState
{
	_gState = _CGContextAllocGState(CTX);
	_v.gStateAllocd = YES;
}

- (void) setUpGState		{ [_CGContextGetGState(CTX, _gState) init]; }
- (void) renewGState		{ }

- (void) releaseGState
{
	if (_gState && _v.gStateAllocd)
		_CGContextReleaseGState(CTX, _gState);
	_gState = 0;
	_v.gStateAllocd = NO;
}

@end


void _NSLockFocus(NSView *v, NSPoint origin, BOOL saveGState)
{
	_NSView *a = (_NSView *)v;

	if (saveGState)
		CGContextSaveGState(CTX);						// Save graphics state

	if (v == nil)
		NSLog (@"Focus on nil view *******");
	if (WINDOW != a->_window)
		{
		_GState *gs = _CGContextGetGState(CTX, a->_gState);

		CONTEXT = (NSGraphicsContext *) gs->context;
		((CGContext *)CONTEXT)->_gs = gs;
		}

	XCANVAS.origin = origin;							// set draw focus
	FOCUS_VIEW = v;
	ISFLIPPED = a->_v.flipped;
	if (a->_v.isRotatedOrScaledFromBase)
		CGContextSetCTM(CONTEXT, [a->_boundsMatrix transformStruct]);
	else
		{
		((CGContext *)CONTEXT)->_gs->_ctm = CGAffineTransformIdentity;
		((CGContext *)CONTEXT)->_gs->hasCTM = NO;
		}
 	CGContextSetBlendMode((CGContextRef)CONTEXT, kCGBlendModeNormal);

#ifdef FB_GRAPHICS
	NSPoint offset = [a->_window xConvertBaseToScreen: NSZeroPoint];
	((CGContext *)CONTEXT)->_fb._origin = offset;
#endif
}

/* ****************************************************************************

		AppEventQueue		Private array optimized as NSApp's events queue

** ***************************************************************************/

@interface _NSAppEventQueue : NSMutableArray
@end

@implementation _NSAppEventQueue

- (NSEvent *) eventMatchingMask:(unsigned int)mask dequeue:(BOOL)flag
{
	NSUInteger i;
														// [context nextEvent]
	(*__nextEventIMP)(CONTEXT, @selector(_nextEvent:), self);

	for (i = 0; i < _count; i++)						// return next event
		{												// in the queue which
		NSEvent *e = _contents[i];						// matches mask

		if ((mask == NSAnyEventMask) || mask & NSEventMaskFromType([e type]))
			{
			if (flag)
				{
				for (_count--; i < _count; i++)			// dequeue the event
					_contents[i] = _contents[i+1];
				[e autorelease];
				}

			return e;
		}	}

	return nil;											// no event in the
}                                                       // queue matches mask

@end  /* _NSAppEventQueue */
