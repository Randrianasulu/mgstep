/*
   NSWindow.m

   Window class

   Copyright (C) 1998-2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUndoManager.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSProcessInfo.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSWindow.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSView.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSDragging.h>
#include <AppKit/NSDocument.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSNibLoading.h>


#define CTX				((CGContext *)_context)
#define GS_SIZE			CTX->_gs->xCanvas.size
#define YOFFSET			CTX->_yOffset
#define SCREEN_HEIGHT	CTX->_display->_frame.size.height
#define FLUSH_ME		CTX->_flushRect

#define NOTE(n_name)	NSWindow##n_name##Notification


// Class variables
static id __responderClass = nil;
static NSMutableDictionary *__frameNames = nil;
static BOOL __cursorHidden = NO;



static NSRect
_NSWindowFrameRect(NSRect r, NSSize max, unsigned style, BOOL contentRect)
{
	if (max.width < 1 || max.height < 1)
		max = [[NSScreen mainScreen] frame].size;

	if (contentRect)						// content rect from frame
		{
		NSHeight(r) -= 26;
		NSWidth(r) -= 2;
		}									// frame rect from content
	else if (style && NSMaxY(r) + 26 >= max.height)
		NSHeight(r) -= 26;	// some sort of titlebar, FIX ME with fullscreen

	if (NSMaxX(r) > max.width)
		{
		NSMinX(r) = 0;
		if (NSMaxX(r) > max.width)
			NSWidth(r) = max.width;
		}

	if (NSMaxY(r) > max.height)
		{
		NSMinY(r) = 0;
		if (NSMaxY(r) > max.height)
			NSHeight(r) = max.height;
		}

	return r;
}


@implementation NSWindow

+ (void) initialize
{
	DBLog(@"NSWindow class initialize\n");
	if (self == [NSWindow class])
		__responderClass = [NSResponder class];
}

+ (NSWindowDepth) defaultDepthLimit
{
	return [[NSScreen mainScreen] depth];
}

+ (NSRect) contentRectForFrameRect:(NSRect)r styleMask:(NSUInteger)aStyle
{
	return _NSWindowFrameRect(r, (NSSize){0,0}, aStyle, YES);
}

+ (NSRect) frameRectForContentRect:(NSRect)r styleMask:(NSUInteger)aStyle
{
	return _NSWindowFrameRect(r, (NSSize){0,0}, aStyle, NO);
}

- (NSRect) frameRectForContentRect:(NSRect)r
{
	return _NSWindowFrameRect(r, _maxSize, _styleMask, NO);
}

+ (NSRect) minFrameWidthWithTitle:(NSString *)t styleMask:(NSUInteger)aStyle
{
	NSFont *f = [NSFont fontWithName:@"Sans-Bold" size:12];

	return (NSRect){0, 0, [f widthOfString:t] + 4, 1};
}

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)deferCreate
				 screen:(NSScreen *)aScreen
{
	_backgroundColor = [[NSColor lightGrayColor] retain];
	_miniWindowTitle = _windowTitle = _representedFilename = @"Window";
	_level = NSNormalWindowLevel;
	_w.needsDisplay = YES;
	_w.autodisplay = YES;
	_w.releasedWhenClosed = YES;
	_w.acceptsMouseMoved = YES;
	_w.cursorRectsEnabled = YES;
	_w.backingType = bufferingType;

	_minSize = (NSSize){20,10};
	if (contentRect.size.width <= 0 || contentRect.size.height <= 0)
		contentRect.size = _minSize;				// X doesn't like 0 size

	_screen = (aScreen) ? aScreen : [NSScreen mainScreen];
	_maxSize = [_screen frame].size;
													// Size the attributes
	_frame = [self frameRectForContentRect:contentRect];
	_context = [[NSGraphicsContext graphicsContextWithWindow: self] retain];
	_windowNumber = CTX->_gState;
	GS_SIZE = _frame.size;

	[self setNextResponder:NSApp];					// NSApp is next responder
	[self setContentView: _contentView];

	if ((_styleMask = aStyle) == NSBorderlessWindowMask)
		{
		_w.menuExclude = YES;
		_w.releasedWhenClosed = NO;
		}

	if ((_w.deferred = deferCreate) == NO)
		[self _initWindowBackend];

	return self;
}

- (id) init
{
	return [self initWithContentRect:(NSRect){50,50,50,50}
				 styleMask:NSTitledWindowMask
				 backing:NSBackingStoreBuffered
				 defer:NO
				 screen:nil];
}

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)flag
{
	return [self initWithContentRect:contentRect 
				 styleMask:aStyle
				 backing:bufferingType 
				 defer:flag 
				 screen:nil];
}

- (void) dealloc
{
	if ((self == [NSApp keyWindow]))
		NSLog(@"WARNING: **** NSApp key window is stale ****");
	[_context _releaseWindowContext],	_context = nil;
	[_contentView release], 			_contentView = nil;	// free view heirarchy
	[_undoManager release], 			_undoManager = nil;
	[_fieldEditor release],				_fieldEditor = nil;
	[_backgroundColor release];
	[_representedFilename release];
	[_miniWindowTitle release];
	[_miniWindowImage release];
	[_windowTitle release];
	[_frameSaveName release];

	[super dealloc];
}

- (void) awakeFromNib
{
	if (!_w.visible && !_w.miniaturized)			// needed by NIB loading
		{											// FIX ME !_w.deferred
		NSRect rect = _frame;

		_frame.origin.x += 1.0;						// force temp inequality
		[self setFrame:rect display:YES];
		}
}

- (void) setTitle:(NSString*)aString				// extended by XR category
{
	ASSIGN(_windowTitle, aString);
	[self setMiniwindowTitle: aString];
													// add to NSApp's windows
	if (!_w.menuExclude && [self canBecomeMainWindow])
		[NSApp addWindowsItem:self title:_windowTitle filename:NO];
	
	[self _setTitle];
}

- (NSString *) title						{ return _windowTitle; }
- (NSString *) miniwindowTitle				{ return _miniWindowTitle; }
- (NSString *) representedFilename			{ return _representedFilename; }
- (NSImage *) miniwindowImage				{ return _miniWindowImage; }
- (NSInteger) windowNumber					{ return _windowNumber; }

- (NSInteger) gState								// views call this when
{													// moved to a window
	if (_w.deferred)
		[self _initWindowBackend];

	return _windowNumber;
}

- (unsigned int) styleMask					{ return _styleMask; }
- (void)setBackingType:(NSBackingStoreType)t{ _w.backingType = t; }
- (NSBackingStoreType) backingType			{ return _w.backingType; }
- (NSColor *) backgroundColor				{ return _backgroundColor; }
- (void) setBackgroundColor:(NSColor*)color	{ ASSIGN(_backgroundColor,color); }
- (void) setMiniwindowImage:(NSImage*)image	{ ASSIGN(_miniWindowImage,image); }
- (void) setOneShot:(BOOL)flag				{ _w.isOneShot = flag; }
- (BOOL) isOneShot							{ return _w.isOneShot; }
- (BOOL) worksWhenModal						{ return NO; }		// for panels
- (BOOL) isMiniaturized						{ return _w.miniaturized; }
- (BOOL) isVisible							{ return _w.visible; }
- (BOOL) inLiveResize						{ return _w.showingModalFrame; }
- (BOOL) isKeyWindow						{ return _w.isKey; }
- (BOOL) isMainWindow						{ return _w.isMain; }
- (BOOL) hidesOnDeactivate					{ return _w.hidesOnDeactivate; }
- (void) setHidesOnDeactivate:(BOOL)flag	{ _w.hidesOnDeactivate = flag; }
- (id) contentView							{ return _contentView; }

- (void) setContentView:(NSView *)aView				
{
	if (_contentView && _contentView != aView)
		[_contentView removeFromSuperview];

	if (aView == nil)								// create content if needed
		_contentView = [[NSView alloc] initWithFrame:(NSRect){0,0,_frame.size}];
	else if (_contentView != aView)
		{
		_contentView = [aView retain];
		[_contentView setNeedsDisplayInRect:(NSRect){0,0,_frame.size}];
		}

	[_contentView viewWillMoveToWindow: self];
	[_contentView setNextResponder:self];			// window is next responder
}

- (void) setRepresentedFilename:(NSString *)aString
{
	ASSIGN(_representedFilename, aString);
}

- (void) setMiniwindowTitle:(NSString *)title
{
	ASSIGN(_miniWindowTitle, title);
//	if (_w.miniaturized == NO);						// FIX ME redisplay miniWin
}

- (void) setTitleWithRepresentedFilename:(NSString*)aString
{
	BOOL wasExcluded = _w.menuExclude;

	[self setRepresentedFilename: aString];
	_w.menuExclude = YES;
	[self setTitle: [aString lastPathComponent]];

	if (!(_w.menuExclude = wasExcluded) && [self canBecomeMainWindow])
		[NSApp addWindowsItem:self title:_windowTitle filename:YES];
}

- (void) endEditingFor:(id)anObject					// field editor
{
	if (_fieldEditor && (_fieldEditor == _firstResponder))
		if (![_fieldEditor resignFirstResponder])	// if not force resignation
			{
			NSLog(@" NSWindow endEditingFor: field editor did not resign");
			[NSNotificationCenter post:NSTextDidEndEditingNotification
								  object:_fieldEditor];
			[(_firstResponder = self) becomeFirstResponder];
			}
}

- (NSText *) fieldEditor:(BOOL)createFlag forObject:(id)obj
{
	SEL s = @selector(windowWillReturnFieldEditor:toObject:);
	NSText *d;										// ask delegate if it can
													// provide a field editor
	if (_delegate && [_delegate respondsToSelector:s])
		if ((d = [_delegate windowWillReturnFieldEditor:self toObject:obj]))
			return d;

	if (!_fieldEditor && createFlag)				// each window has a global
		{											// text field editor, if it
		_fieldEditor = [[NSText new] retain];		// doesn't exist create it
		[_fieldEditor setFieldEditor:YES]; 			// if create flag is set
		}

	return _fieldEditor;
}

- (void) _enableNotifications:(BOOL)enabled
{
	NSNotificationCenter *n = [NSNotificationCenter defaultCenter];

#define _OBSERVE_(notif_name) [n addObserver:NSApp \
								 selector:@selector(window##notif_name:) \
								 name:NSWindow##notif_name##Notification \
								 object:self]

#define _IGNORE_(notif_name) [n removeObserver:NSApp \
								name:NSWindow##notif_name##Notification \
								object:self]
	if ((_w.canNotify = enabled))
		{
		_OBSERVE_(WillClose);
		_OBSERVE_(DidResignMain);
		_OBSERVE_(DidBecomeKey);
		_OBSERVE_(DidBecomeMain);

		[(NSMutableArray *)[NSApp windows] addObject: self];
		}
	else
		{
		_IGNORE_(WillClose);
		_IGNORE_(DidResignMain);
		_IGNORE_(DidBecomeKey);
		_IGNORE_(DidBecomeMain);

		[(NSMutableArray *)[NSApp windows] removeObject: self];
		}							// cycle event loop when new window becomes
									// visible (e.g. Viewer displays image)
	if (enabled)					// only needed for DO doc open
		[NSApp postEvent:_NSAppKitEvent() atStart:NO];
}

- (void) becomeMainWindow
{
	if (_w.isMain)
		return;

	if (!_w.canNotify)
		[self _enableNotifications:YES];
	_w.isMain = YES;
	[NSNotificationCenter post:NSWindowDidBecomeMainNotification object: self];
}

- (BOOL) canBecomeKeyWindow					
{ 
	return (_styleMask & (NSTitledWindowMask|NSResizableWindowMask)); 
}

- (BOOL) canBecomeMainWindow					
{ 
	if ((_styleMask & (NSTitledWindowMask|NSResizableWindowMask)))
		if (!_w.isPanel)
			return YES;

	return NO;
}

- (int) level								{ return _level; }
- (void) setLevel:(int)newLevel				{ _level = newLevel; }
- (void) orderFrontRegardless				{ [self orderFront:self]; }

- (void) orderFront:(id)sender
{
	BOOL wasVisible = _w.visible;

	if (_w.deferred)
		[self _initWindowBackend];

	[self _orderFront];								// place window on screen

	if (!wasVisible && [self canBecomeKeyWindow])
		{
		if (!_w.canNotify)
			[self _enableNotifications:YES];

		if (!_firstResponder && _initialFirstResponder)
			[self selectNextKeyView:self];
		}
}

- (void) orderOut:(id)sender
{
	BOOL fullRemoval = NO;

	if ((_w.isKey) || (_w.isMain) || [self canBecomeKeyWindow])
		{
		fullRemoval = ![NSApp isHidden];			// temp or perm removal ?

		if (_w.isMain)
			[self resignMainWindow];
		if (_w.isKey)
			[self resignKeyWindow];

		if (_w.canNotify && fullRemoval)
			[self _enableNotifications:NO];
		}

	[self _orderOut: fullRemoval];
	_w.visible = NO;								// window is not visible
}

- (void) orderWindow:(NSWindowOrderingMode)place relativeTo:(int)otherWin
{
}

- (void) makeKeyAndOrderFront:(id)sender
{
	BOOL wasVisible = _w.visible;

	if (_w.miniaturized)
		[self deminiaturize:sender];
	else if (!_w.visible)
		[self orderFront:sender];					// window must be visible
													// to makeKey
	if (!_w.isKey)
		{
		[self makeKeyWindow];						// Make self the key window
		[self makeMainWindow];

		if (wasVisible)
			[self orderFront:sender];
		}
}

- (void) becomeKeyWindow
{
	if (_w.isKey)
		return;

	if (!_w.canNotify)
		[self _enableNotifications:YES];
	_w.isKey = YES;

NSLog(@"becomeKeyWin '%@' %#lx", _windowTitle, (unsigned long)_windowTitle);

	if (!_w.isMain && ![self canBecomeMainWindow])	// FIX ME ...&& !transient
		[self _becomeTransient];
	else
		[self _becomeOwnerOfTransients];

	if (!_w.cursorRectsValid)
		[self resetCursorRects];

	[_firstResponder becomeFirstResponder];
	[NSNotificationCenter post: NOTE(DidBecomeKey) object: self];
}

- (void) makeKeyWindow
{													// Can we become the key
	if ((_w.isKey) || ![self canBecomeKeyWindow]) 	// window?
		return;										
													// ask current key window
	[[NSApp keyWindow] resignKeyWindow];			// to resign status
	[self becomeKeyWindow];
}													 
	
- (void) makeMainWindow
{													// Can we become main win
	if ((_w.isMain) || ![self canBecomeMainWindow])
		return;
													// ask current main window
	[[NSApp mainWindow] resignMainWindow];			// to resign status
	[self becomeMainWindow];
}													

- (void) resignKeyWindow
{
	if (_w.isKey)
		{
		_w.isKey = NO;
		[_firstResponder resignFirstResponder];
		[NSCursor pop];									// empty cursor stack
		[NSNotificationCenter post:NOTE(DidResignKey) object:self];
		}
}

- (void) resignMainWindow
{
	if (_w.isMain)
		{
		_w.isMain = NO;
		[NSNotificationCenter post:NOTE(DidResignMain) object:self];
		}
}

- (void) performMiniaturize:(id)sender
{
	NSLog(@"XRWindow performMiniaturize\n");
	[self miniaturize:self];
}

- (void) miniaturize:(id)sender
{
	if (!_w.miniaturized && _w.visible)
		{
		[NSNotificationCenter post: NOTE(WillMiniaturize) object:self];
		[self _miniaturize];
		_w.miniaturized = YES;
		[NSNotificationCenter post: NOTE(DidMiniaturize) object:self];
		}
}

- (void) deminiaturize:(id)sender
{
	if (_w.miniaturized)
		{
		[self orderFront:self];
		_w.miniaturized = NO;						// Notify window's delegate
		[NSNotificationCenter post: NOTE(DidDeminiaturize) object:self];
		}
}

- (void) setFrame:(NSRect)r display:(BOOL)flag
{
	if (!_w.deferred && !NSEqualRects(_frame, r))
		{
		float y = SCREEN_HEIGHT - (NSMaxY(r) + YOFFSET);

		[self _setFrame:(NSRect){{NSMinX(r), y}, r.size} withHint:1];
		}

	_frame = r;
	if (flag)
		[self display];
}

- (void) setFrameOrigin:(NSPoint)p
{
	[self setFrame:(NSRect){p, _frame.size} display:NO];
}

- (void) setContentSize:(NSSize)cs
{
	[self setFrame: [self frameRectForContentRect:(NSRect){_frame.origin, cs}]
		   display: _w.visible];
}

- (void) setFrameTopLeftPoint:(NSPoint)p
{
	[self setFrameOrigin: (NSPoint){p.x, (p.y - NSHeight(_frame))}];
}

- (NSPoint) cascadeTopLeftFromPoint:(NSPoint)topLeftPoint
{
	NSRect f = _frame;

	if (!NSEqualPoints(topLeftPoint, NSZeroPoint))
		f.origin = (NSPoint){topLeftPoint.x, topLeftPoint.y - NSHeight(_frame)};

	topLeftPoint = [self constrainFrameRect:f toScreen:_screen].origin;
	if (!NSEqualPoints(topLeftPoint, _frame.origin))
		[self setFrameOrigin: topLeftPoint];
	topLeftPoint.y += NSHeight(_frame);

	return (NSPoint){topLeftPoint.x + 25, topLeftPoint.y - 25};
}

- (void) center											// center the window
{														// within it's screen
	NSSize scr = [_screen frame].size;

	[self setFrameOrigin: (NSPoint){(scr.width - _frame.size.width) / 2,
									(scr.height - _frame.size.height) / 2}];
}

- (NSRect) constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	NSSize scr = [_screen frame].size;

	if (NSMinX(frameRect) < .0)
		NSMinX(frameRect) = .0;
	else if (NSMaxX(frameRect) >= scr.width)
		NSMinX(frameRect) = MAX(scr.width - NSWidth(frameRect), .0);

	if (NSMinY(frameRect) < .0)
		NSMinY(frameRect) = .0;
	else if (NSMaxY(frameRect) >= scr.height)
		NSMinY(frameRect) = MAX(scr.height - NSHeight(frameRect), .0);

	return frameRect;
}

- (NSRect) frame								{ return _frame; }
- (NSSize) minSize								{ return _minSize; }
- (NSSize) maxSize								{ return _maxSize; }
- (NSSize) resizeIncrements						{ return _resizeIncrements; }
- (NSSize) aspectRatio							{ return _aspectRatio; }
- (void) setMinSize:(NSSize)aSize				{ _minSize = aSize; }
- (void) setMaxSize:(NSSize)aSize				{ _maxSize = aSize; }
- (void) setResizeIncrements:(NSSize)aSize		{ _resizeIncrements = aSize; }
- (void) setAspectRatio:(NSSize)aSize			{ _aspectRatio = aSize; }

- (NSPoint) convertBaseToScreen:(NSPoint)base
{
	return (NSPoint){ base.x + NSMinX(_frame), base.y + NSMinY(_frame) };
}

- (NSPoint) convertScreenToBase:(NSPoint)screen
{
	return (NSPoint){ screen.x - NSMinX(_frame), screen.y - NSMinY(_frame) };
}

- (NSPoint) xConvertBaseToScreen:(NSPoint)base		// flipped device space
{
	NSPoint screen = (NSPoint){ _frame.origin.x + base.x,
								SCREEN_HEIGHT - (_frame.origin.y + base.y)};
	return screen;
}

- (NSPoint) xConvertScreenToBase:(NSPoint)screen
{
	NSPoint base = (NSPoint){ screen.x - _frame.origin.x,
							  SCREEN_HEIGHT - screen.y - _frame.origin.y };
	return base;
}

- (NSPoint) mouseLocationOutsideOfEventStream		
{													
	return [self xConvertScreenToBase: [NSEvent mouseLocation]];
}													

- (void) display
{
	if (_w.deferred)
		[self _initWindowBackend];
	[self disableFlushWindow];						// disable display flush
	[_contentView display];							// draw view hierarchy
	[self enableFlushWindow];						// reenable flush
	[self flushWindowIfNeeded];
	_w.needsDisplay = NO;
}

- (void) displayIfNeeded
{
	if (_w.deferred)
		[self _initWindowBackend];
	if (_w.needsDisplay)
		[_contentView displayIfNeeded];
	_w.needsDisplay = NO;
}

- (void) update
{
	if (_w.autodisplay && _w.needsDisplay)
		{											// autodisplay enabled and
		[self displayIfNeeded];						// window needs display
		[self flushWindowIfNeeded];
    	}

	[NSNotificationCenter post:NSWindowDidUpdateNotification object:self];
}

- (void) flushWindow
{
	if (_w.backingType == NSBackingStoreNonretained)
		return;

	if (_w.disableFlushWindow || !_w.visible)
		_w.needsFlush = YES;						// can't flush now, mark it
	else
		{
		if (!NSEqualRects(FLUSH_ME, NSZeroRect))
			CGContextFlush((CGContextRef)_context);
		_w.needsFlush = NO;
		}
}

- (void) flushWindowIfNeeded
{
	if (!_w.disableFlushWindow && _w.needsFlush)
		[self flushWindow];
}

- (void) setDocumentEdited:(BOOL)flag				// mark doc as edited
{
	_w.isEdited = flag;
	[NSApp updateWindowsItem: self];
}

- (BOOL) isDocumentEdited					{ return _w.isEdited; }
- (void) _needsFlush						{ _w.needsFlush = YES; }
- (void) disableFlushWindow					{ _w.disableFlushWindow = YES; }
- (void) enableFlushWindow					{ _w.disableFlushWindow = NO; }
- (BOOL) isFlushWindowDisabled				{ return _w.disableFlushWindow; }
- (BOOL) isAutodisplay						{ return _w.autodisplay; }
- (void) setAutodisplay:(BOOL)flag			{ _w.autodisplay = flag; }
- (void) setViewsNeedDisplay:(BOOL)flag		{ _w.needsDisplay = flag; }
- (BOOL) viewsNeedDisplay					{ return _w.needsDisplay; }
- (void) useOptimizedDrawing:(BOOL)flag		{ _w.optimizeDrawing = flag; }
- (BOOL) canStoreColor						{ return (_depthLimit > 1); }
- (NSWindowDepth) depthLimit				{ return _depthLimit; }
- (BOOL) hasDynamicDepthLimit				{ return _w.dynamicDepthLimit; }
- (NSScreen *) screen						{ return _screen; }
- (NSScreen *) deepestScreen				{ return [NSScreen deepestScreen];}
- (void) setDepthLimit:(NSWindowDepth)limit	{ _depthLimit = limit; }
- (void) setDynamicDepthLimit:(BOOL)flag	{ _w.dynamicDepthLimit = flag; }
- (void) setReleasedWhenClosed:(BOOL)flag	{ _w.releasedWhenClosed = flag; }
- (BOOL) acceptsMouseMovedEvents			{ return _w.acceptsMouseMoved; }
- (BOOL) isExcludedFromWindowsMenu			{ return _w.menuExclude; }
- (void) setAcceptsMouseMovedEvents:(BOOL)f	{ _w.acceptsMouseMoved = f;}
- (void) setExcludedFromWindowsMenu:(BOOL)f { _w.menuExclude = f; }
- (NSEvent *) currentEvent					{ return [NSApp currentEvent]; }
- (NSGraphicsContext *) graphicsContext		{ return _context; }
- (id) delegate								{ return _delegate; }

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;

	if (_delegate == anObject)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSWindow##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(DidBecomeKey);
		IGNORE_(DidBecomeMain);
		IGNORE_(DidChangeScreen);
		IGNORE_(DidDeminiaturize);
		IGNORE_(DidExpose);
		IGNORE_(DidMiniaturize);
		IGNORE_(DidMove);
		IGNORE_(DidResignKey);
		IGNORE_(DidResignMain);
		IGNORE_(DidResize);
		IGNORE_(DidUpdate);
		IGNORE_(WillClose);
		IGNORE_(WillMiniaturize);
		}

	if (!(_delegate = anObject))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(window##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(window##notif_name:) \
		   name:NSWindow##notif_name##Notification \
		   object:self]

	OBSERVE_(DidBecomeKey);
	OBSERVE_(DidBecomeMain);
	OBSERVE_(DidChangeScreen);
	OBSERVE_(DidDeminiaturize);
	OBSERVE_(DidExpose);
	OBSERVE_(DidMiniaturize);
	OBSERVE_(DidMove);
	OBSERVE_(DidResignKey);
	OBSERVE_(DidResignMain);
	OBSERVE_(DidResize);
	OBSERVE_(DidUpdate);
	OBSERVE_(WillClose);
	OBSERVE_(WillMiniaturize);
	OBSERVE_(WillMove);
}

- (void) discardCursorRects
{
	[_cursorRects removeAllObjects];
}

- (void) invalidateCursorRectsForView:(NSView *)aView
{
	if(aView)
		{
		if(_w.isKey)
			{
			[aView discardCursorRects];
			[aView resetCursorRects];
			}
		else
			_w.cursorRectsValid = NO;
		}
}

- (void) resetCursorRects
{
	[self discardCursorRects];
	[_contentView resetCursorRects];
	_w.cursorRectsValid = YES;
}

- (void) disableCursorRects					{ _w.cursorRectsEnabled = NO; }
- (void) enableCursorRects					{ _w.cursorRectsEnabled = YES; }
- (BOOL) areCursorRectsEnabled				{ return _w.cursorRectsEnabled; }
- (BOOL) isReleasedWhenClosed				{ return _w.releasedWhenClosed; }

- (void) close
{													// Notify window's delegate
	[NSNotificationCenter post: NSWindowWillCloseNotification object: self];
	[self orderOut:self];
	[NSApp removeWindowsItem: self];

	if (_frameSaveName)
		[self saveFrameUsingName: _frameSaveName];

	if (![NSApp mainMenu] && _w.releasedWhenClosed)
		[NSApp terminate:self];						// quit if app has no menu

	if (_w.releasedWhenClosed)						// default YES for windows
		[self autorelease];							// and NO for panels
}

- (void) performClose:(id)sender
{
	if (!(_styleMask & NSClosableWindowMask))
		{											// must have a close button
		NSBeep();									// in order to be closed
		return;
		}

	if ([_delegate respondsToSelector:@selector(windowShouldClose:)])
		{											// if delegate responds to
    	if(![_delegate windowShouldClose:self])		// windowShouldClose query
			{										// it to see if it's ok to
			NSBeep();								// close the window
			return;
		}	}
	else
		{
		if ([self respondsToSelector:@selector(windowShouldClose:)])
			{										// else if self responds to
			if(![self windowShouldClose:self])		// windowShouldClose query
				{									// self to see if it's ok
				NSBeep();							// to close self
				return;
		}	}	}

	[self close];									// ok to close self
}

- (void) keyDown:(NSEvent *)event
{
	unsigned short keyCode = [event keyCode];

	if (keyCode == 0x0)						// Mod key
		return;
	if (keyCode == 0x09)					// Tab
		[self selectNextKeyView:self];
	else									// FIX ME should provide default
		NSBeep();							// handling per NSResponder docs
}

- (int) resizeFlags							{ return 0; }
- (NSResponder *) firstResponder			{ return _firstResponder; }
- (BOOL) acceptsFirstResponder				{ return YES; }

- (BOOL) makeFirstResponder:(NSResponder *)aResponder
{
	if (_firstResponder == aResponder)				// if responder is already
		return YES;									// first responder return Y

	if (![aResponder isKindOfClass: __responderClass])
		return NO;									// not a responder return N

	if (![aResponder acceptsFirstResponder])
		return NO;									// does not accept status

	if (_firstResponder)
		{
		NSResponder *f = _firstResponder;			// recursion safe invoke

		_firstResponder = nil;
		if (![f resignFirstResponder])				// the first responder must
			{										// agree to resign
			_firstResponder = f;

			return NO;
		}	}

	if (__cursorHidden)
		[NSCursor unhide],	__cursorHidden = NO;

	if (_firstResponder == aResponder)				// in case the above op set
		return YES;									// a new first responder

	if ([(_firstResponder = aResponder) becomeFirstResponder])
		return YES;									// Notify responder of it's
													// new status, make window
	_firstResponder = self;							// first if it refuses

	return NO;
}

- (NSEvent *) nextEventMatchingMask:(unsigned int)mask
{
	return [NSApp nextEventMatchingMask:mask
				  untilDate:nil
				  inMode:NSEventTrackingRunLoopMode
				  dequeue:YES];
}

- (NSEvent *) nextEventMatchingMask:(unsigned int)mask
						  untilDate:(NSDate *)expiration
						  inMode:(NSString *)mode
						  dequeue:(BOOL)deqFlag
{
	return [NSApp nextEventMatchingMask:mask
				  untilDate:expiration
				  inMode:mode
				  dequeue:deqFlag];
}

- (void) discardEventsMatchingMask:(unsigned int)mask beforeEvent:(NSEvent *)e
{
	[NSApp discardEventsMatchingMask:mask beforeEvent:e];
}

- (void) postEvent:(NSEvent *)event atStart:(BOOL)flag
{
	[NSApp postEvent:event atStart:flag];
}

- (void) sendEvent:(NSEvent *)event
{
	if (!_w.visible)
		{
		NSLog(@"WARNING: **** invisible window recieved event %@", event);
		return;
		}

	if (!_w.cursorRectsValid)
		[self resetCursorRects];

	switch ([event type])
    	{
		case NSAppKitDefined:
			[_firstResponder becomeFirstResponder];
			if (!_w.isKey)
				[self makeKeyAndOrderFront:self];
			break;

		case NSLeftMouseDown:								// Left mouse down
			_lastLeftHit = [_contentView hitTest:[event locationInWindow]];
			if (_lastLeftHit != _firstResponder		// make hit V first
					&& ![self makeFirstResponder:_lastLeftHit]
					&& _firstResponder != self		// win first if V not accept
					&& [_lastLeftHit acceptsFirstResponder])
				break;								// do nada if resign refused
			if (_w.isKey && !_w.tossFirstEvent)
				[_lastLeftHit mouseDown:event];
			else
				{
				[self makeKeyAndOrderFront:self];
				if ([_lastLeftHit acceptsFirstMouse:event])
					[_lastLeftHit mouseDown:event];
				_w.tossFirstEvent = NO;
				}
			break;

		case NSLeftMouseUp:									// Left mouse up
			[_lastLeftHit mouseUp:event];
			break;

		case NSOtherMouseDown:								// Other mouse down
			_lastRightHit = [_contentView hitTest:[event locationInWindow]];
			[_lastRightHit otherMouseDown:event];
			break;

		case NSOtherMouseUp:								// Other mouse up
			[_lastRightHit otherMouseUp:event];
			break;

		case NSRightMouseDown:								// Right mouse down
			_lastRightHit = [_contentView hitTest:[event locationInWindow]];
			[_lastRightHit rightMouseDown:event];
			break;

		case NSRightMouseUp:								// Right mouse up
			[_lastRightHit rightMouseUp:event];
			break;

		case NSMouseMoved:									// Mouse moved
			if (__cursorHidden)
				[NSCursor unhide], __cursorHidden = NO;
			if(_w.acceptsMouseMoved)
				{
				NSView *v = [_contentView hitTest:[event locationInWindow]];

				[v mouseMoved:event];				// hit view passes event up
				}									// responder chain to self
			else									// if we accept mouse moved
				if(_w.cursorRectsEnabled)
					[self mouseMoved:event];
			break;

		case NSKeyDown:
			if (([event modifierFlags] & NSAlternateKeyMask))
				[self performKeyEquivalent:event];
			else
				{									// save first responder so
				_lastKeyDown = _firstResponder;		// that key up goes to it
													// and not a possible new
				if (!__cursorHidden					// first responder
					&& [_firstResponder respondsToSelector:@selector(isEditable)]
					&& [_firstResponder isEditable]
					&& ((__cursorHidden = [NSCursor isHiddenUntilMouseMoves])))
						[NSCursor hide];

				[_firstResponder keyDown:event];
				}
			break;

		case NSKeyUp:
			[_lastKeyDown keyUp:event];				// send KeyUp to object
			_lastKeyDown = nil;						// that got the KeyDown
			break;

		case NSFlagsChanged:
		    [_firstResponder flagsChanged:event];
			break;

		case NSScrollWheel:
		    [[_contentView hitTest:[event locationInWindow]]scrollWheel:event];
			break;

		case NSCursorUpdate:
			if ([event trackingNumber])						// mouse entered
				[(id)[event userData] push];				// push the cursor
			else
				[NSCursor pop];								// mouse exited
															// pop the cursor
		default:
			break;
		}
}

- (BOOL) performKeyEquivalent:(NSEvent*)event
{
	return [[NSApp mainMenu] performKeyEquivalent:event];
}

- (BOOL) tryToPerform:(SEL)anAction with:(id)anObject
{
	return ([super tryToPerform:anAction with:anObject]);
}

- (void) registerForDraggedTypes:(NSArray *)newTypes		// Drag and Drop
{
	[_contentView registerForDraggedTypes:newTypes];
}

- (void) unregisterDraggedTypes
{
	[_contentView unregisterDraggedTypes];
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
	if (_delegate)
		if ([_delegate respondsToSelector:@selector(concludeDragOperation:)])
			[_delegate concludeDragOperation:sender];
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	if(_delegate && [_delegate respondsToSelector:@selector(draggingEntered:)])
		return [_delegate draggingEntered:sender];

	return NSDragOperationNone;
}

- (void) draggingExited:(id <NSDraggingInfo>)sender
{
	if (_delegate && [_delegate respondsToSelector:@selector(draggingExited:)])
		[_delegate draggingExited:sender];
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	if(_delegate && [_delegate respondsToSelector:@selector(draggingUpdated:)])
		return [_delegate draggingUpdated:sender];

	return NSDragOperationNone;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	if(_delegate)
		if ([_delegate respondsToSelector:@selector(performDragOperation:)])
			return [_delegate performDragOperation:sender];

	return NO;
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	if(_delegate)
		if ([_delegate respondsToSelector:@selector(prepareForDragOperation:)])
			return [_delegate prepareForDragOperation:sender];

	return NO;
}

- (id) validRequestorForSendType:(NSString *)sendType		// Services menu
					  returnType:(NSString *)returnType
{
	id result = nil;

	if (_delegate && [_delegate respondsToSelector: _cmd])
		result = [_delegate validRequestorForSendType: sendType
							returnType: returnType];

	if (result == nil)
		result = [NSApp validRequestorForSendType: sendType 
						returnType: returnType];
	return result;
}

+ (void) removeFrameUsingName:(NSString *)name			// Save / restore frame	
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"NSWindow Frame %@",name];

	[defaults removeObjectForKey:key];
	[defaults synchronize];
	[__frameNames removeObjectForKey:name];
}

- (BOOL) setFrameAutosaveName:(NSString *)name
{
	if (!__frameNames)
		__frameNames = [NSMutableDictionary new];

	if ([__frameNames objectForKey:name])
		return NO;

	ASSIGN(_frameSaveName, name);
	[__frameNames setObject:self forKey:name];

	return YES;
}

- (NSString *) frameAutosaveName			{ return _frameSaveName; }

- (void) saveFrameUsingName:(NSString *)name
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"NSWindow Frame %@",name];
		
	DBLog(@"saveFrameUsingName %@\n",[NSValue valueWithRect:_frame]);

	[defaults setObject:[NSValue valueWithRect:_frame] forKey:key];
	[defaults synchronize];
}

- (BOOL) setFrameUsingName:(NSString *)name
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"NSWindow Frame %@",name];
	NSString *value = [defaults stringForKey:key];

	if(!value)
		return NO;

	DBLog(@"setFrameUsingName %@\n", value);
	[self setFrameFromString: value];

	return YES;
}

- (void) setFrameFromString:(NSString *)string
{
	NSRect r = NSRectFromString(string);

	NSWidth(r) = MIN(MAX(r.size.width, _minSize.width), _maxSize.width);
	NSHeight(r) = MIN(MAX(r.size.height, _minSize.height), _maxSize.height);

	if ([_delegate respondsToSelector:@selector(windowWillResize:toSize:)])
		r.size = [_delegate windowWillResize:self toSize:r.size];

	[self setFrame:r display:NO];
}

- (NSString *) stringWithSavedFrame
{
	return NSStringFromRect(_frame);;
}

- (NSUndoManager *) undoManager
{
	NSUndoManager *u;								// ask delegate if it can
													// provide an undo manager
	if ([_delegate respondsToSelector: @selector(windowWillReturnUndoManager:)])
		if ((u = [_delegate windowWillReturnUndoManager: self]))
			return u;

	if (!_undoManager)
		_undoManager = [[NSUndoManager alloc] init];

	return _undoManager;
}

- (BOOL) validateMenuItem:(NSMenuItem *)aCell
{
	NSUndoManager *u;
    SEL s = [aCell action];

	if (sel_eq (@selector(undo:), s) && (u = [_firstResponder undoManager]))
		if ([u canUndo])	// override in views to set custom titles
    		return YES;		// e.g. [aCell setTitle: [u undoMenuItemTitle]]

	if (sel_eq (@selector(redo:), s) && (u = [_firstResponder undoManager]))
		if ([u canRedo])
    		return YES;

	if (sel_eq (@selector(makeKeyAndOrderFront:), s))
		return YES;

    return NO;
}

- (void) undo:(id)sender
{
	NSUndoManager *u = [_firstResponder undoManager];

	if (![u isUndoing])
		[u undo];
	
	[NSApp postEvent:_NSAppKitEvent() atStart:NO];
}

- (void) redo:(id)sender
{
	NSUndoManager *u = [_firstResponder undoManager];

	if (![u isRedoing])
		[u redo];

	[NSApp postEvent:_NSAppKitEvent() atStart:NO];
}

- (NSView *) initialFirstResponder			{ return _initialFirstResponder; }

- (void) setInitialFirstResponder:(NSView *)aView
{
	_initialFirstResponder = aView;
}

- (void) selectNextKeyView:(id)sender
{
	id next;

	if (_firstResponder && _firstResponder != self)
		next = [_firstResponder nextValidKeyView];
	else
		if ((next = _initialFirstResponder) && ![next acceptsFirstResponder])
			next = [_initialFirstResponder nextValidKeyView];

	if (next && [self makeFirstResponder:next])
		{
		if ([next respondsToSelector:@selector(selectText:)])
			[(NSTextField *)next selectText:self];
		}
	else
		NSBeep();
}

- (void) selectPreviousKeyView:(id)sender
{
	id prev;

	if (_firstResponder && _firstResponder != self)
		prev = [_firstResponder previousValidKeyView];
	else
		if ((prev = _initialFirstResponder) && ![prev acceptsFirstResponder])
			prev = [_initialFirstResponder previousValidKeyView];

	if (prev && [self makeFirstResponder:prev])
		{
		if ([prev respondsToSelector:@selector(selectText:)])
			[(NSTextField *)prev selectText:self];
		}
	else
		NSBeep();
}

- (void) selectKeyViewFollowingView:(NSView *)v
{
	if ((v = [v nextValidKeyView]) && [self makeFirstResponder:v])
		if ([v respondsToSelector:@selector(selectText:)])
			[(NSTextField *)v selectText:self];
}

- (void) selectKeyViewPrecedingView:(NSView *)v
{
	if ((v = [v previousValidKeyView]) && [self makeFirstResponder:v])
		if ([v respondsToSelector:@selector(selectText:)])
			[(NSTextField *)v selectText:self];
}

- (void) cacheImageInRect:(NSRect)srcRect
{
	if (CTX->_layer && (!CTX->_layer->_ly.dontFree || CTX->_layer->_prev))
		[self discardCachedImage];			// not back stor

	if (NSWidth(srcRect) <= 0 && NSHeight(srcRect) <= 0)
		NSLog (@"NSWindow failed to cache zero rect!");
	else
		{
		CGLayerRef ly;

		NSLog(@" cached image");
		[_contentView lockFocus];	// copy out with 0 offset in src rect
		[NSGraphicsContext saveGraphicsState];

		ly = CGLayerCreateWithContext((CGContextRef)CTX, srcRect.size, NULL);
		CGContext *lcx = (CGContext *)CGLayerGetContext((CGLayer *)ly);
		[NSGraphicsContext setGraphicsState: lcx->_gState];		// set dest

		if (CTX->_layer)					// nest layer
			CTX->_layer->_prev = ly;		// FB uses _layer ivar as ptr to fb
		else								// FIX ME nest s/b at top not bottom
			CTX->_layer = (CGLayer *)ly;

		NSCopyBits(_windowNumber, srcRect, NSZeroPoint);
		[NSGraphicsContext restoreGraphicsState];
		[_contentView unlockFocus];
		}
}

- (void) restoreCachedImage
{
	if (CTX->_layer)
		{
		BOOL didLock = NO;
		CGLayerRef ly;

		if ([NSView focusView] != _contentView)
			{	
			[_contentView lockFocus];
			didLock = YES;
			}

		ly = (CTX->_layer->_prev) ? CTX->_layer->_prev : CTX->_layer;
		CGContextDrawLayerAtPoint((CGContextRef)CTX, NSZeroPoint, ly);

		if (didLock)
			[_contentView unlockFocus];
		}
}

- (void) discardCachedImage
{
	CGLayerRef ly = CTX->_layer->_prev;

	if (CTX->_layer->_prev)					// un-nest layer
		CTX->_layer->_prev = NULL;
	CGLayerRelease(ly);
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeRect:_frame];
	[aCoder encodeObject:_contentView];
	[aCoder encodeObject:_initialFirstResponder];
//  [aCoder encodeObjectReference: _delegate withName:NULL];
	[aCoder encodeObject:_backgroundColor];
	[aCoder encodeObject:_representedFilename];
	[aCoder encodeObject:_miniWindowTitle];
	[aCoder encodeObject:_windowTitle];
	[aCoder encodeSize:_minSize];
	[aCoder encodeSize:_maxSize];
	[aCoder encodeObject:_miniWindowImage];
	[aCoder encodeValueOfObjCType:@encode(int) at: &_level];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_w];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_frame = [aDecoder decodeRect];
	_contentView = [aDecoder decodeObject];
	_initialFirstResponder = [aDecoder decodeObject];
//  [aDecoder decodeObjectAt: &_delegate withName:NULL];
	_backgroundColor = [aDecoder decodeObject];
	_representedFilename = [aDecoder decodeObject];
	_miniWindowTitle = [aDecoder decodeObject];
	_windowTitle = [aDecoder decodeObject];
	_minSize = [aDecoder decodeSize];
	_maxSize = [aDecoder decodeSize];
	_miniWindowImage = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(int) at: &_level];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_w];

	return self;
}

@end  /* NSWindow */

/* ****************************************************************************

	NSWindowController

** ***************************************************************************/

@implementation NSWindowController

- (id) initWithWindowNibName:(NSString *)windowNibName owner:(id)owner
{
	if (!(_wc.nibIsLoaded = [NSBundle loadNibNamed:windowNibName owner:owner]))
		return _NSInitError(self, @"Failed to open %@", windowNibName);

	return self;
}

- (id) initWithWindowNibName:(NSString *)windowNibName
{
	return [self initWithWindowNibName:windowNibName owner:self];
}

- (id) initWithWindow:(NSWindow *)window
{
	[self setWindow: window];

	return self;
}

- (NSWindow *) window						{ return _window; }
- (void) setWindow:(NSWindow *)window		{ ASSIGN(_window, window); }
- (id) document								{ return _document; }
- (void) setDocument:(NSDocument *)document { ASSIGN(_document, document); }
- (void) setDocumentEdited:(BOOL)f			{ [_window setDocumentEdited: f]; }
- (void) setShouldCloseDocument:(BOOL)flag	{ _wc.shouldCloseDocument = flag; }
- (BOOL) shouldCloseDocument				{ return _wc.shouldCloseDocument; }
- (BOOL) isWindowLoaded						{ return _wc.nibIsLoaded; }

- (void) close				// close doc if controller belongs to doc and is
{							// last controller or shouldCloseDocument is YES
	[_window close];		// window auto-releases itself
	if (_wc.shouldCloseDocument)
		[_document release], _document = nil;
	[self release];
}
									// Show controller's window (if any).  Make
- (id) showWindow:(id)sender		// it key and order it front unless it is
{									// a panel that becomes key only if needed.
	BOOL isPanel = [_window isKindOfClass:[NSPanel class]];

	if (isPanel && [(NSPanel *)_window becomesKeyOnlyIfNeeded])
		{}
	else
		[_window makeKeyAndOrderFront: sender];

	[_window orderFront: sender];
	[_window displayIfNeeded];

	return self;
}

- (void) encodeWithCoder:(NSCoder *)e		{ [super encodeWithCoder:e]; }
- (id) initWithCoder:(NSCoder *)d			{ return [super initWithCoder:d]; }

@end  /* NSWindowController */
