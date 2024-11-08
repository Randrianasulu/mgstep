/*
   _CGWindowFB.m

   FrameBuffer window category

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSApplication.h>


#ifdef FB_GRAPHICS

#define CTX				((CGContext *)_context)
#define SCREEN			CTX->_display
#define GS_SIZE			CTX->_gs->xCanvas.size
#define TRANSIENTS		CTX->_mg->_transients
#define FB_WIN         	CTX->_fb
#define SCREEN_HEIGHT	((CGDisplay *)CTX->_display)->_vinfo.yres

#define NOTE(n_name)	NSWindow##n_name##Notification

typedef struct _NSWindow_t { @defs(NSWindow); } _NSWindow;


static void
list_print(NSWindow *n)
{
	if (n == nil)
		printf("Window list is empty\n");
	while (n != nil)
		{
		printf("Window list: %p %p\n", n, ((_NSWindow *)n)->_below);
		n = ((_NSWindow *)n)->_below;
		}
}

/* ****************************************************************************

	FB Window

** ***************************************************************************/

@implementation NSWindow  (FBWindow)

- (void) _initWindowBackend
{
	_w.deferred = NO;
	[_context _initWindowContext:_frame];
}

- (void) _miniaturize							{ [self _orderOut: NO]; }
- (void) _setTitle								{ }
- (void) _becomeOwnerOfTransients				{ }
- (void) _setFrameTopLeftPoint:(NSPoint)p		{ NSLog(@"_setFrame..FIX ME"); }

- (void) _becomeTransient
{
	if (([NSApp mainWindow]))
		[TRANSIENTS addObject: self];
	else
		NSLog(@"unable to become transient, no main window");
}

- (NSPoint) xConvertBaseToScreen:(NSPoint)basePoint
{
	NSPoint screenPoint;

	screenPoint.x = _frame.origin.x + basePoint.x;
	screenPoint.y = SCREEN_HEIGHT - NSMaxY(_frame) + basePoint.y;

	return screenPoint;
}
													// return default drawing
- (CGLayer *) _canvas								// canvas. (backing store
{													// if window has one) 
	if (_w.backingType != NSBackingStoreNonretained)
		{
		_CGContextSetWindowCanvas( CTX, self);

		return _CGContextWindowBackingLayer((CGContextRef)CTX, _frame.size);
		}

	return &FB_WIN;
}

- (void) _setFrame:(NSRect)rect withHint:(int)hint
{
	NSPoint offset;

	NSLog(@"_setFrame: ((%f, %f), (%f, %f))",
				NSMinX(rect), NSMinY(rect), NSWidth(rect), NSHeight(rect));

	if (NSMinY(rect) < 0)		// FIX ME happens when window > screen size
		NSMinY(rect) = 0;
	_frame.origin = (NSPoint){NSMinX(rect), (float)SCREEN_HEIGHT - NSMaxY(rect)};

	if (!NSEqualSizes(_frame.size, rect.size)) 
		{											 
		NSLog(@"*** _setFrame:  old: ((%f, %f), new: (%f, %f))",
			  NSWidth(_frame), NSHeight(_frame), NSWidth(rect), NSHeight(rect));

		_frame.size = rect.size;
		GS_SIZE = rect.size;

		CTX->_layer = [self _canvas];

		if (_contentView) 							// Inform content view		
			{										// of the frame change
			[_contentView setFrame:(NSRect){{0,0},_frame.size}];
			[_contentView setNeedsDisplayInRect:(NSRect){{0,0},_frame.size}];
			}
 													// post notification
		[NSNotificationCenter post: NOTE(DidResize) object:self];

		if(_w.visible)
			{
			NSView *focusView;

			[self resetCursorRects];

			if ((focusView = [NSView focusView]) && [focusView window] == self)
				{
				[focusView unlockFocus];			// size change invalidated
				[focusView lockFocus];				// focus coords, re-lock
				}
			if (_w.backingType != NSBackingStoreNonretained)
				[self display];						// if no backing store			
		}	}										// redisplay window

	offset = [self xConvertBaseToScreen: NSZeroPoint];
	FB_WIN._origin = offset;

	if (!CTX->_layer && (CTX->_layer = [self _canvas]) && _contentView)
		[_contentView setNeedsDisplayInRect:(NSRect){{0,0},_frame.size}];

	if (_frameSaveName)
		[self saveFrameUsingName: _frameSaveName];
}

- (BOOL) _exposedRectangle:(NSRect)rect				// background restore
{
	if (_w.backingType != NSBackingStoreNonretained && _w.visible)
		{											// window has backing store
		PSgsave();
///		CTX->_gs->fill.color = _backgroundColor;
		FBFlushRect(CTX, rect, rect.origin);
		PSgrestore();								// Restore graphics state

		return YES;
		}											// no backing store 

	[_contentView displayRectIgnoringOpacity:rect];

	return NO;
}

- (void) _restoreBackground					// FIX ME a quick hack
{
	NSWindow *w = SCREEN->_visibleWindowList;
	BOOL background_restored = NO;

	for (; w; w = w->_below)
		{
		if (NSContainsRect(w->_frame, _frame))
			{
			NSPoint o = (NSPoint){NSMinX(_frame) - NSMinX(w->_frame),
								  NSMinY(_frame) - NSMinY(w->_frame)};

			o.y = NSHeight(w->_frame) - (o.y + NSHeight(_frame));
			[w _exposedRectangle: (NSRect){o,_frame.size}];
			background_restored = YES;
			break;
			}
		else
			{
			NSRect intersect = NSIntersectionRect(_frame, w->_frame);

			if (NSWidth(intersect) && NSHeight(intersect))
				{
				NSRect rect = (NSRect){0,0,w->_frame.size};

				background_restored = YES;
				[w _exposedRectangle: rect];
				}
			}
		}

	if (!background_restored)
		{
		NSRect rect = _frame;
		
		rect.origin.y = SCREEN_HEIGHT - NSMaxY(_frame);
		FBEraseScreen((CGContextRef)[NSApp context], rect);
		}
}

- (void) _orderOut:(BOOL)fullRemoval
{
	NSWindow **c = &SCREEN->_visibleWindowList;

printf("FBOrderOut %d  %p\n", [self windowNumber], self);
list_print(SCREEN->_visibleWindowList);

	if (SCREEN->_visibleWindowList == self)		// remove self at top
		{
		if (_below != nil)
			*c = _below;
		else
			*c = nil;
		}
	else
		for (; *c != NULL; c = &(*c)->_below)
			if ((*c)->_below == self)
				{
				(*c)->_below = _below;
				break;
				}

	_below = nil;

printf("FBOrderOut end\n");
list_print(SCREEN->_visibleWindowList);

	[self _restoreBackground];
}

- (void) _orderFront
{
	NSWindow **c = &SCREEN->_visibleWindowList;

	_w.visible = YES;

printf("FBOrderFront %d  %p\n", [self windowNumber], self);
list_print(SCREEN->_visibleWindowList);

	if (SCREEN->_visibleWindowList == nil)
		SCREEN->_visibleWindowList = self;
	if (SCREEN->_visibleWindowList == self)
		return;
															// restack windows
	for (; *c != NULL; c = &(*c)->_below)					// remove
		if ((*c)->_below == self)
			{
			(*c)->_below = _below;
			break;
			}

	_below = SCREEN->_visibleWindowList;
	SCREEN->_visibleWindowList = self;

printf("FBOrderFront end\n");
list_print(SCREEN->_visibleWindowList);

	_CGContextRectNeedsFlush((CGContextRef)CTX, (CGRect){0,0,_frame.size});
	_w.needsFlush = YES;
	[self flushWindow];
}

- (void) _orderBack
{
	NSWindow **c = &SCREEN->_visibleWindowList;

printf("FBLower %d  %p\n", [self windowNumber], self);
list_print(SCREEN->_visibleWindowList);

	if (SCREEN->_visibleWindowList == self)
		if (_below != nil)									// remove at head
			*c = _below;
															// remove elsewhere
	for (; *c != NULL; c = &_below)
		if ((*c)->_below == self)
			(*c)->_below = _below;

	*c = self;												// add at tail
	_below = nil;

printf("FBLower end\n");
list_print(SCREEN->_visibleWindowList);

	[self _restoreBackground];
}

- (void) orderBack:(id)sender
{
	if (_w.visible)							
		[self _orderBack];
}

@end  /* NSWindow  (FBWindow) */

#endif
