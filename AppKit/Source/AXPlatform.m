/*
   AXPlatform.m

   AppKit private backend (fb/x11) implementations.

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    February 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>

#include <AppKit/NSDragging.h>
#include <AppKit/AppKit.h>


#define CONTEXT				((CGContext *)_context)
#define XSCREENHEIGHT		CONTEXT->_display->_frame.size.height

// Class variables
static BOOL __slideBack = NO;
static BOOL __ignoreModifierKeys = NO;
static unsigned int __modifierFlags = 0;
static NSCell *__dragCell = nil;
static NSCell *__appCell = nil;
static NSCell *__tileCell = nil;

static NSWindow *__destWindow;
static NSPoint __dragWindowOrigin;
static NSPoint __dndLocation;
static NSPasteboard *__dndPasteboard;
static NSDragOperation __dragSourceMask;
static id __dndSource = nil;
static int __dndSessionTag = 0;


/* ****************************************************************************

		Private View classes

** ***************************************************************************/

@interface _NSTitleView   : NSView							@end
@interface _NSAppIconView : _NSTitleView					@end
@interface _NSDragView    : _NSTitleView  <NSDraggingInfo>	@end

/* ****************************************************************************

		Private Window classes

** ***************************************************************************/

@interface _NSAppIconWindow : NSWindow
@end

@interface _NSDragWindow : NSWindow
{
	int _x, _y;
	BOOL _dndaware;

#ifndef FB_GRAPHICS
	Window _lastMouseWindow;
	Window _mouseWindow;
#endif
}

- (void) setImage:(NSImage *)anImage;

@end

static _NSDragView *__dragView = nil;					// shared dragging view
static _NSDragWindow *__dragWindow = nil;				// shared drag window

/* ****************************************************************************

		_NSTitleView  (Private view class that can move it's window)

** ***************************************************************************/

@implementation _NSTitleView

- (BOOL) acceptsFirstMouse:(NSEvent *)event					{ return YES; }

- (void) mouseDown:(NSEvent*)event
{
	NSPoint p, point, lastPoint;
	NSRect dragWin;
	NSDate *df;
	int noMotion = 0;								// allows a forced update
	NSEventType t;
	id moveCursor = nil;
	BOOL keyEvent = NO;

	if ([event clickCount] > 1)						// mouse s/b debounced
		return;

	lastPoint = [[event window] convertBaseToScreen:[event locationInWindow]];
	dragWin = [_window frame];
	point = lastPoint;								// set periodic events rate
													// to achieve max of ~30fps
	[NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.03];

	for (df = [NSDate distantFuture]; ; noMotion++)
		{											// user is dragging window
		event = [NSApp nextEventMatchingMask: NSAnyEventMask
								   untilDate: df
									  inMode: NSEventTrackingRunLoopMode
									 dequeue: YES];

		if ((t = [event type]) != NSPeriodic || (noMotion == 3))
			{
			if (t != NSPeriodic)
				__modifierFlags = [event modifierFlags];

			if (t == NSLeftMouseDragged)
				{
				if (!moveCursor)
					{
					if ((moveCursor = [NSCursor moveCursor]))
						{
						[[NSCursor currentCursor] push];
						[moveCursor set];
						}
					else
						moveCursor = self;			// one shot test
					}
				point = [event locationInWindow];
				}
			else
				{
				if (t == NSLeftMouseUp)
					break;

				if ((t >= NSKeyDown) && (t <= NSFlagsChanged))
					keyEvent = YES;
													// if 3x periods have gone
				if (noMotion == 3)					// by w/o movement
					point = [_window mouseLocationOutsideOfEventStream];
				else
					continue;
				}

			point.y += dragWin.origin.y;
			point.x += dragWin.origin.x;
			noMotion = 0;							// reset at each position
			}
		else										// update the position of
			{										// drag window if necessary 
			if (point.x != lastPoint.x || point.y != lastPoint.y) 
				{
				dragWin.origin.x += (point.x - lastPoint.x);
				dragWin.origin.y += (point.y - lastPoint.y);
				p = (NSPoint){dragWin.origin.x, NSMaxY(dragWin)};
				[_window setFrameTopLeftPoint:p];
				lastPoint = point;
				}
			else if (keyEvent)
				{
				keyEvent = NO;
				[_window setFrameTopLeftPoint:p];
		}	}	}

	[NSEvent stopPeriodicEvents];
	if (moveCursor && moveCursor != self)
		[NSCursor pop];
	[self mouseUp:event];
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:event];
}													// CTRL key generates mouse
													// down ??? so flush events
@end /* _NSTitleView */

/* ****************************************************************************

	_NSAppIconView

** ***************************************************************************/

@implementation _NSAppIconView

- (void) drawRect:(NSRect)rect
{												
	[__tileCell drawWithFrame:rect inView:self];
	[__appCell drawWithFrame:rect inView:self];
}

- (void) mouseDown:(NSEvent*)event
{
	if ([event clickCount] < 2)
		{
		[super mouseDown:event];
		return;
		}

	[NSApp unhide: self];
	[self display];
	if (![NSApp keyWindow])							// special case where app
		{											// has no windows
		[[self window] becomeKeyWindow];
		[[self window] resignKeyWindow];
		}
}

@end /* _NSAppIconView */


#ifdef FB_GRAPHICS  /* ************************************************** FB */

/* ****************************************************************************

	FB_GRAPHICS

** ***************************************************************************/

@implementation _NSAppIconWindow

- (id) init
{
	_NSAppIconView *v;

	_w.appIcon = YES;
	__appCell = [NSCell alloc];
	__tileCell = [NSCell alloc];
	[__appCell initImageCell:[NSImage imageNamed:@"blankCursor"]];
	[__tileCell initImageCell:[NSImage imageNamed:@"dockTile"]];
	[__appCell setBordered:NO];
	[__tileCell setBordered:NO];
	v = [[_NSAppIconView alloc] initWithFrame:(NSRect){{0,0},{64,64}}];
	_contentView = v;

	return [self initWithContentRect:(NSRect){{0,0},{64,64}}
				 styleMask:NSBorderlessWindowMask
				 backing:NSBackingStoreRetained
				 defer:YES
				 screen:nil];
}

- (void) setFrameTopLeftPoint:(NSPoint)xOrigin		{ }

@end  /* _NSAppIconWindow */


@implementation _NSDragWindow

- (void) setImage:(NSImage *)anImage				{ }
- (void) xProcessExposedRectangles					{ [self display]; }

- (void) setFrameTopLeftPoint:(NSPoint)xOrigin
{
	_frame.origin = (NSPoint){xOrigin.x, (xOrigin.y - NSHeight(_frame))};
	xOrigin.y = XSCREENHEIGHT - xOrigin.y;

	NSLog (@"drag ((%d, %d)", (int)xOrigin.x, (int)xOrigin.y);

	_x = xOrigin.x;					
	_y = xOrigin.y;					
}

- (void) _orderOutDragWindowAlarm:(id)sender
{
	NSLog(@"** Order out drag window alarm triggered **");
	[__dragWindow orderOut:nil];
}

- (void) mouseUp:(NSEvent *)event
{
///	if(_dndaware && _mouseWindow != (Window) None)		// drop onto DND aware
		[NSTimer scheduledTimerWithTimeInterval: 3.0
				 target: self
				 selector: @selector(_orderOutDragWindowAlarm:)
				 userInfo: nil
				 repeats: NO];
///	else												// drop onto a non DND
		if (__slideBack)
			[__dragView slideDraggedImageTo: __dragWindowOrigin];
		[__dragWindow orderOut:nil];
///		[pb declareTypes:nil owner:nil];
}

@end /* _NSDragWindow */

#else  /* XR_GRAPHICS  ************************************************** XR */

/* ****************************************************************************

	XR_GRAPHICS

** ***************************************************************************/

#include <X11/Xatom.h>
#include "xdnd.h"


#define CTX_HAS_LUZ_WM  	CONTEXT->_display->_sf.hasLuzWM
#define XAPPROOTWIN			CONTEXT->_display->xAppRootWindow
#define XWINDOW				CONTEXT->xWindow

#define CTX					((CGContext *)cx)
#define XDISPLAY			CTX->_display->xDisplay
#define XROOTWIN			CTX->_display->xRootWindow
#define XDND				((DndClass *)CTX->_mg->_dnd)


static Atom __xdnd_source_action = 0;
static NSView *__dndWindowContentView = nil;
static NSView *__dndLastView = nil;


@implementation NSWindow  (xdnd)

- (void) xSetXDNDAware					{ XRSetXDNDAware(CONTEXT, XWINDOW); }

@end


@implementation _NSAppIconWindow

- (id) init
{
	CGContextRef cx = NULL;
	_NSAppIconView *v;
	NSProcessInfo *p = [NSProcessInfo processInfo];
	NSArray *args = [p arguments];
	NSString *n = [p processName];
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	int i, c = [args count];
	char *argv[c];
	XWMHints hints = {0};
	XClassHint h;

	if (![[NSScreen mainScreen] xHasLuzWindowManager])
		return _NSLogError(@"AppIcon not supported");	// FIX ME deferred win dealloc

	_w.appIcon = YES;
	__appCell = [NSCell alloc];
	__tileCell = [NSCell alloc];
	[__tileCell initImageCell:[NSImage imageNamed:@"dockTile"]];
	[__appCell setBordered:NO];
	[__tileCell setBordered:NO];
	v = [[_NSAppIconView alloc] initWithFrame:(NSRect){{0,0},{64,64}}];
	_contentView = [v retain];

	[self initWithContentRect:(NSRect){{0,0},{64,64}}
		  styleMask:NSBorderlessWindowMask
		  backing:NSBackingStoreRetained	
		  defer:NO
		  screen:nil];

	cx = (CGContextRef)_context;
	hints.flags = WindowGroupHint | IconWindowHint | StateHint;
	hints.icon_window = XWINDOW;
	hints.initial_state = WithdrawnState;
	hints.window_group = (CTX_HAS_LUZ_WM) ? XAPPROOTWIN : XWINDOW;

	if (CTX_HAS_LUZ_WM)
		XSetWMHints(XDISPLAY, XAPPROOTWIN, &hints);
	else
		XSetWMHints(XDISPLAY, XWINDOW, &hints);
													// set class hints so WM
	h.res_class = "XRAppIconWindow";				// creates an app icon
	h.res_name = (char*)[n cString];
	XSetClassHint(XDISPLAY, XWINDOW, &h);

	if (CTX_HAS_LUZ_WM)
		{
		h.res_class = "XRAppRootWindow";
		XSetClassHint(XDISPLAY, XAPPROOTWIN, &h);
		}

	argv[0] = (char*)[[bundlePath stringByAppendingPathComponent:n] cString];
	for(i = 1; i < c; i++)
		argv[i] = (char*)[[args objectAtIndex:i] cString];

	if (CTX_HAS_LUZ_WM)							// set launch args for WM
		{
		XSetCommand(XDISPLAY, XAPPROOTWIN, argv, c);
		XMapWindow(XDISPLAY, XAPPROOTWIN);
		}
	else
		XSetCommand(XDISPLAY, XWINDOW, argv, c);

	return self;
}

@end  /* _NSAppIconWindow */


@implementation _NSDragWindow				

- (void) setImage:(NSImage *)anImage
{
	CGContextRef cx = (CGContextRef)_context;
	id r = [anImage bestRepresentationForDevice:nil];
	Pixmap mask = [(NSBitmapImageRep*)r xPixmapMask];

	XShapeCombineMask(XDISPLAY, XWINDOW, ShapeBounding, 0, 0, mask, ShapeSet);
	_dndaware = NO;
	_lastMouseWindow = None;
	if (mask != None)
		XFreePixmap (XDISPLAY, mask);
}

- (void) setFrameTopLeftPoint:(NSPoint)xOrigin 
{
	CGContextRef cx = (CGContextRef)_context;
	_frame.origin = (NSPoint){xOrigin.x, (xOrigin.y - NSHeight(_frame))};
	xOrigin.y = XSCREENHEIGHT - xOrigin.y;

	DBLog (@"drag ((%d, %d)", (int)xOrigin.x, (int)xOrigin.y);
	XMoveWindow (XDISPLAY, XWINDOW, (int)xOrigin.x,(int)xOrigin.y);

	_x = xOrigin.x;					
	_y = xOrigin.y;					
	_mouseWindow = XRFindWindow(cx, XROOTWIN, XROOTWIN, _x+49,_y+32);

	if (_mouseWindow != _lastMouseWindow && _dndaware)	// if in new window
		{												// send leave to old
		xdnd_send_leave(XDND, _lastMouseWindow, XWINDOW);
		_lastMouseWindow = None;
		_dndaware = NO;
		}

	if (_mouseWindow != XROOTWIN && _mouseWindow != XWINDOW)
		{												// test if dnd aware
		if((_dndaware = XRIsWindowXDNDAware(CONTEXT, _mouseWindow)))
			{
			Atom typelist[3] = { XDND->types[0], XA_STRING, 0 };
			NSDragOperation o = [__dragView draggingSourceOperationMask];

			DBLog(@"Target window is XDND aware\n");

			if(_lastMouseWindow == None)
				xdnd_send_enter(XDND, _mouseWindow, XWINDOW, typelist);

			xdnd_send_position(XDND, _mouseWindow, XWINDOW, 
								XRActionForDragOperation(o),
								_x+49, _y+24, CurrentTime);
			_lastMouseWindow = _mouseWindow;
			}
		else
			DBLog(@"Target window is **NOT** XDND aware\n");
		}
	else
		if(_mouseWindow == XROOTWIN)
			DBLog(@"_NSDragWindow: mouseWindow == rootWindow\n");
		else
			DBLog(@"_NSDragWindow: mouseWindow == XWINDOW\n");
}

- (void) _orderOutDragWindowAlarm:(id)sender
{
	if (_mouseWindow == (Window)None && [__dragWindow isVisible])
		{
		NSLog(@"** Order out drag window alarm triggered **");
		[__dragWindow orderOut:nil];
		}
}

- (void) mouseUp:(NSEvent *)event
{
	CGContextRef cx = (CGContextRef)_context;

	if (_dndaware && _mouseWindow != (Window) None)		// drop onto XDND aware
		{												// window
		xdnd_set_selection_owner (XDND, XWINDOW, XDND->XdndSelection);
		xdnd_send_drop (XDND, _lastMouseWindow, XWINDOW, CurrentTime);
		_mouseWindow = (Window)None;
		[NSTimer scheduledTimerWithTimeInterval: 3.0
				 target: self
				 selector: @selector(_orderOutDragWindowAlarm:)
				 userInfo: nil
				 repeats: NO];
		}
	else												// drop onto a non XDND
		{												// aware window
		if ((_mouseWindow = XRFindWindow(cx, XROOTWIN, XROOTWIN, _x+49, _y+32)))
			{
			NSFileManager *fm = [NSFileManager defaultManager];
			BOOL altKeyDown = [event modifierFlags] & NSAlternateKeyMask;
			NSPasteboard *p = [NSPasteboard pasteboardWithName:NSDragPboard];
			NSDictionary *d = [p propertyListForType:NSFilenamesPboardType];
			NSMutableString *s = [d objectForKey:@"SourcePath"];
			BOOL is_dir = NO;
			BOOL exists = [fm fileExistsAtPath:s isDirectory:&is_dir];
														// if ALT key was held
			if ((exists) && (is_dir) && altKeyDown)		// down user wants to
				{										// change to dir
				s = [[s mutableCopy] autorelease];
				[s insertString:@"cd " atIndex:0];
				[s appendString:@"\n"];					// send path string to
				}										// X window under the
														// cursor 
			if (!XRSendString(CONTEXT, _mouseWindow, [s cString]))
				NSLog(@"_NSDragWindow: error sending string to X window\n");
			else
				__slideBack = (_mouseWindow != XROOTWIN) ? NO : __slideBack;

			if (__slideBack)
				[__dragView slideDraggedImageTo: __dragWindowOrigin];

			[__dragWindow orderOut:nil];
			[p declareTypes:nil owner:nil];
		}	}
}

- (void) xProcessExposedRectangles		{ [self display]; }
- (void) _menuWindow					{ }

@end /* _NSDragWindow */


void
XRProcessXDND(CGContextRef cx, XEvent *xEvent)
{
	Display *dpy = CTX->_display->xDisplay;

	if (xEvent->xclient.message_type == XDND->XdndEnter)
		{ 
		DBLog(@" recieved XdndEnter");

		__destWindow = XRWindowWithXWindow(xEvent->xclient.window);
		__dndWindowContentView = [__destWindow contentView];
		}
	else if (xEvent->xclient.message_type == XDND->XdndPosition)
		{
		unsigned int ret;
		NSView *dndView;

		DBLog(@" recieved XdndPosition");

		__xdnd_source_action = XDND_POSITION_ACTION(xEvent);
		__dndLocation.x = (float)XDND_POSITION_ROOT_X(xEvent); 
		__dndLocation.y = (float)XDND_POSITION_ROOT_Y(xEvent); 
		__dndLocation = [__destWindow xConvertScreenToBase: __dndLocation];
		dndView = [__dndWindowContentView hitTest: __dndLocation];
		if (dndView != __dndLastView)						// entered new view
			{
			if (__dndLastView)								// send exit update
				[__dndLastView draggingExited: __dragView];		

			__dndSessionTag++;							// send enter
			ret = [dndView draggingEntered: __dragView];
			__dndLastView = dndView;
			}
		else											// send pos update
			ret = [dndView draggingUpdated: __dragView];
														// ret status to source
		xdnd_send_status(XDND, xEvent->xclient.data.l[0], 
						 xEvent->xany.window, 0, 0, 1, 1,
						 XRActionForDragOperation(ret));
		}
	else if (xEvent->xclient.message_type == XDND->XdndFinished)
		{
		DBLog(@" recieved XdndFinished \n");		// recieved by source
		if (__slideBack && xEvent->xclient.data.l[1] == 1)
			[__dragView slideDraggedImageTo: __dragWindowOrigin];

		[__dragWindow orderOut:nil];
		[[NSPasteboard pasteboardWithName:NSDragPboard] declareTypes:nil
														owner:nil];
		}
	else if (xEvent->xclient.message_type == XDND->XdndStatus)
		{
		DBLog(@" recieved XdndStatus \n");
														// check status and 
		XRProcessXDNDStatus(dpy, xEvent);				// update cursor ...etc
		}
	else if (xEvent->xclient.message_type == XDND->XdndLeave)
		{
		DBLog(@" recieved XdndLeave");

		if (__dndLastView)									// send exit update
			[__dndLastView draggingExited: __dragView];		
		__dndLastView = nil;
		}
	else if (xEvent->xclient.message_type == XDND->XdndDrop)
		{
		DBLog(@" recieved XdndDrop");
		if ([__dndLastView prepareForDragOperation: __dragView])
			{
			if (__slideBack && xEvent->xclient.data.l[1] == 1)
				[__dragView slideDraggedImageTo: __dragWindowOrigin];
			[__dragWindow orderOut:nil];

			if ([__dndLastView performDragOperation: __dragView])
				{
				xdnd_send_finished(XDND, xEvent->xclient.data.l[0], 
									xEvent->xany.window, 0);
				[__dndLastView concludeDragOperation: __dragView];
				__dndSource = nil;
				return;
			}	}

		xdnd_send_finished(XDND, xEvent->xclient.data.l[0], 
							xEvent->xany.window, 1);
		__dndSource = nil;
		}
}

#endif  /* XR_GRAPHICS **************************************************** */

/* ****************************************************************************

	_NSDragView

** ***************************************************************************/

@implementation _NSDragView

- (void) drawRect:(NSRect)rect
{
	[__dragCell drawWithFrame:rect inView:self];
}
													// NSDraggingInfo protocol
- (NSWindow *) draggingDestinationWindow		{ return __destWindow; }
- (NSPoint) draggingLocation					{ return __dndLocation; }
- (NSPasteboard *) draggingPasteboard			{ return __dndPasteboard; }
- (int) draggingSequenceNumber					{ return __dndSessionTag; }
- (id) draggingSource							{ return __dndSource; }
- (NSImage *) draggedImage						{ return [__dragCell image]; }
- (NSPoint) draggedImageLocation				{ return __dndLocation; }

- (void) slideDraggedImageTo:(NSPoint)scrnPoint
{
	NSDate *df = [NSDate distantFuture];
	NSRect r = [__dragWindow frame];
	int screenheight = [[NSScreen mainScreen] frame].size.height;
	int steps = 15;
	int xi = (int)MAX(scrnPoint.x - NSMinX(r), NSMinX(r) - scrnPoint.x) / steps;
	int yi = (int)MAX(scrnPoint.y - NSMinY(r), NSMinY(r) - scrnPoint.y) / steps;

	[NSEvent startPeriodicEventsAfterDelay:0.0 withPeriod:0.03];

	while (NSMinX(r) != scrnPoint.x && steps)
		{
		NSPoint xp;
		NSEvent *e = [NSApp nextEventMatchingMask:NSAnyEventMask
							untilDate:df
							inMode:NSEventTrackingRunLoopMode
							dequeue:YES];

		if ([e type] == NSPeriodic)
			{
			if (MAX(scrnPoint.x - NSMinX(r), NSMinX(r) - scrnPoint.x) <= xi)
				NSMinX(r) = scrnPoint.x;
			else
				NSMinX(r) += (scrnPoint.x > NSMinX(r)) ? xi : -(xi);

			if (MAX(scrnPoint.y - NSMinY(r), NSMinY(r) - scrnPoint.y) <= yi)
				NSMinY(r) = scrnPoint.y;
			else
				NSMinY(r) += (scrnPoint.y > NSMinY(r)) ? yi : -(yi);

			xp = (NSPoint){r.origin.x, screenheight - NSMaxY(r)};
	
			DBLog (@"drag ((%d, %d)", (int)xp.x, (int)xp.y);
			[__dragWindow _setFrameTopLeftPoint: xp];
			steps--;
		}	}

	[NSEvent stopPeriodicEvents];
}

- (NSDragOperation) draggingSourceOperationMask
{
	NSDragOperation o = __dragSourceMask;

	if (__dndSource)							// source object is local
		{
		if (!__ignoreModifierKeys)
			{
			if (__modifierFlags & NSAlternateKeyMask)
				o &= NSDragOperationCopy;
			else if (__modifierFlags & NSControlKeyMask)
				o &= NSDragOperationLink;
			else if (__modifierFlags & NSShiftKeyMask)
				o &= NSDragOperationGeneric;
		}	}
#ifndef FB_GRAPHICS
	else										// source is in another app
		o = XRDragOperationForAction(__xdnd_source_action);
#endif
	return o;
}

@end /* _NSDragView */

/* ****************************************************************************

		NSView (DnD)

** ***************************************************************************/

@implementation NSView (DnD)

- (void) dragImage:(NSImage *)anImage					// initiate a dragging
				at:(NSPoint)location					// session
				offset:(NSSize)initialOffset
				event:(NSEvent *)event
				pasteboard:(NSPasteboard *)pboard
				source:(id)sourceObject
				slideBack:(BOOL)slideFlag
{
	NSPoint windowFrameOrigin = [_window frame].origin;
	NSPoint dragWindowOrigin;							// translate source loc
								 						// to window's coords
	location = [[_window contentView] convertPoint:location fromView:self];

	dragWindowOrigin.x = windowFrameOrigin.x + location.x;
	dragWindowOrigin.y = windowFrameOrigin.y + location.y;
	dragWindowOrigin.y += initialOffset.height;			// convert to screen
	dragWindowOrigin.x += initialOffset.width; 			// coords and add the
														// offset
	[__dragCell setImage:anImage];
	[__dragView lockFocus];
	NSEraseRect((NSRect){{0,0},{48,48}});
	[__dragCell drawWithFrame:(NSRect){{0,0},{48,48}} inView:__dragView];
	[__dragView unlockFocus];
	[__dragWindow setImage:anImage];

	[__dragWindow setFrameOrigin:dragWindowOrigin];
	[__dragWindow orderFront:nil];

	__dndSource = sourceObject;
	__dragSourceMask = [__dndSource draggingSourceOperationMaskForLocal:YES];

#ifndef FB_GRAPHICS
	if([__dragWindow xGrabMouse] != GrabSuccess)
		{
		NSLog(@"Grab Mouse failed\n");
		return;
		}
	__xdnd_source_action = XRActionForDragOperation(__dragSourceMask);
#endif

	if([__dndSource respondsToSelector: @selector(ignoreModifierKeysWhileDragging)])
		__ignoreModifierKeys = [__dndSource ignoreModifierKeysWhileDragging];

	__dragWindowOrigin = dragWindowOrigin;
	__slideBack = slideFlag;
	__dndPasteboard = pboard;
	[__dragView mouseDown:event];

#ifndef FB_GRAPHICS
	[__dragWindow xReleaseMouse];
#endif
}

- (void) unregisterDraggedTypes					{ /* FIX ME */ }

- (void) registerForDraggedTypes:(NSArray *)newTypes
{
	if (!__dragView && (__dragView = [_NSDragView alloc]))
		{												// create shared drag
		NSRect rect = (NSRect){{0,0},{48,48}};			// view/win if needed
		NSImage *c = [NSImage imageNamed:@"blankCursor"];

		__dragCell = [[NSCell alloc] initImageCell:c];
		[__dragCell setBordered:NO];
		__dragWindow = [[_NSDragWindow alloc] initWithContentRect:rect
											  styleMask:NSBorderlessWindowMask
											  backing:NSBackingStoreBuffered
											  defer:YES
											  screen:nil];
		__dragView = [__dragView initWithFrame:rect];
		[[__dragWindow contentView] addSubview:__dragView];
		}

#ifndef FB_GRAPHICS
	[_window xSetXDNDAware];
#endif
	if(!_dragTypes)
		_dragTypes = [NSMutableSet new];

	[_dragTypes addObjectsFromArray:newTypes];
}

@end /* NSView (DnD) */


@implementation NSApplication  (AppIconView)

- (void) setApplicationIconImage:(NSImage *)anImage
{														// Set the app's icon
	ASSIGN(_appIcon, anImage);

	if (!_appIconWindow && _appIcon)
		_appIconWindow = [_NSAppIconWindow new];
	[[_appIcon copy] setName: NSApplicationIcon];
	[__appCell setImage:anImage];
	[_appIconWindow orderFront:nil];
	[_appIconWindow display];
}

@end
