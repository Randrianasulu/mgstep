/*
   NSApplication.m

   Application management

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSBundle.h>
#include <CoreFoundation/CFRunLoop.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSColorPanel.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSMenuItem.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSNibLoading.h>


#define NOTE(n_name)    NSApplication##n_name##Notification


struct _NSModalSession {
	int runState;
	int windowTag;
	BOOL visible;
	NSWindow *window;
	NSModalSession previous;
};

// Class variables
NSApplication *NSApp = nil;
const double NSAppKitVersionNumber = mGSTEP_VERSION;

extern NSString *NSAbortModalException;

/* ****************************************************************************

		AppEventQueue		Private array optimized as NSApp's events queue

** ***************************************************************************/

@interface _NSAppEventQueue : NSMutableArray

- (NSEvent *) eventMatchingMask:(unsigned int)mask dequeue:(BOOL)flag;

@end

/* ****************************************************************************

		NSApplication

** ***************************************************************************/

@implementation NSApplication

+ (NSApplication *) sharedApplication
{
	if (NSApp == nil)
		{
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		Class c = [[NSBundle mainBundle] principalClass];

		if (c == Nil || ![c isKindOfClass:[self class]])
			[[self alloc] init];
		[[c alloc] init];

		[pool release];
		}

	return NSApp;
}

- (id) init
{
	if (NSApp == nil && (NSApp = self = [super init]))
		{
		CFRunLoopRef rl = CFRunLoopGetCurrent();

		_windowList = [NSMutableArray new];				// allocate window list
		_app.windowsNeedUpdate = YES;
	
		[self setNextResponder:nil];					// NSApp is the end of
														// the responder chain
		CFRunLoopAddCommonMode( rl, (CFStringRef) NSModalPanelRunLoopMode);
		CFRunLoopAddCommonMode( rl, (CFStringRef) NSEventTrackingRunLoopMode);

		_eventQueue = [[_NSAppEventQueue alloc] initWithCapacity:9];
		[(_context = [NSGraphicsContext new]) _listenForEvents: _eventQueue];
		}

	return self;
}

- (void) finishLaunching
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSDictionary *d = [[NSBundle mainBundle] infoDictionary];
	NSString *mainNib = [d objectForKey:@"NSMainNibFile"];
	NSString *appIcon = [d objectForKey:@"NSIcon"];
													// post launch will finish
	[NSNotificationCenter post: NOTE(WillFinishLaunching) object: self];

	if ((mainNib) && ![mainNib isEqual:@""])
		if (![NSBundle loadNibNamed:mainNib owner:NSApp])
			NSLog (@"Cannot load main model file '%@'", mainNib);

	if (appIcon)
		[NSApp setApplicationIconImage:[NSImage imageNamed:appIcon]];

	[NSNotificationCenter post: NOTE(DidFinishLaunching) object: self];
	[self activateIgnoringOtherApps:NO];

	if (!_keyWindow && _mainWindow)				// some controls (textfield)
		[_mainWindow makeKeyWindow];			// alter behavior if not in key

	[pool release];
}

- (void) dealloc
{
	DBLog(@"dealloc NSApplication\n");
													// Let ourselves know we 
	_app.isDeallocating = YES;						// are within dealloc
	
	[_listener release];
	[_windowList release];
	[_eventQueue release];

	while (_session != 0)							// clean up any nested modal
		{											// session structures
		NSModalSession tmp = _session;
	
		_session = tmp->previous;
		free(tmp);
		}

	[super dealloc];
}

- (void) run										// Run the main event loop
{
	[self finishLaunching];
	_app.isRunning = YES;

	do  {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		NSEvent *e = [self nextEventMatchingMask:NSAnyEventMask
						   untilDate:nil
						   inMode:NSDefaultRunLoopMode
						   dequeue:YES];
		if (e != nil)
			[self sendEvent: e];

		if (_app.windowsNeedUpdate)					// send an update message
			[self updateWindows];					// to all visible windows

		[pool release];
		}
	while (_app.isRunning);
}

- (int) runModalForWindow:(NSWindow*)aWindow
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	static NSModalSession s = 0;
	static int r;									// Run a modal event loop

	if (!_app.isActive)
		[NSApp activateIgnoringOtherApps:NO];

	NS_DURING
		{
		s = [self beginModalSessionForWindow:aWindow];
		while ((r = [self runModalSession: s]) == NSRunContinuesResponse)
			{
			NSDate *d = (_app.isHidden) ? [NSDate distantFuture]
					  : [NSDate dateWithTimeIntervalSinceNow:.03];

			[self nextEventMatchingMask:NSAnyEventMask
				  untilDate: d
				  inMode:NSModalPanelRunLoopMode
				  dequeue:NO];

			[pool release];
			pool = [NSAutoreleasePool new];
			}

		[self endModalSession: s];
		}
	NS_HANDLER
		{
		if (s)
			[self endModalSession: s];

		if ([[localException name] isEqual: NSAbortModalException] == NO)
			[localException raise];
		r = NSRunAbortedResponse;
		}
	NS_ENDHANDLER

	[pool release];

	return r;
}

- (int) runModalSession:(NSModalSession)as
{
	NSEvent *e;

	if (as != _session)
		[NSException raise: NSInvalidArgumentException
					 format: @"runModalSession: with wrong session"];

	if (!_app.isHidden)
		[as->window displayIfNeeded];
	if (_app.isActive)
		[as->window makeKeyAndOrderFront: self];

	while ((e = [_eventQueue eventMatchingMask:NSAnyEventMask dequeue:YES])
			&& (as->runState == NSRunContinuesResponse))
		{
		NSEventType t = [e type];
		NSWindow *w = [e window];

		if (!_app.isActive && t == NSAppKitDefined && (w != _appIconWindow))
			[self activateIgnoringOtherApps:NO];
		else if (_app.isHidden && t == NSAppKitDefined)
			[self unhide:self];

		if (w == as->window)
			{
			if (as->runState == NSRunContinuesResponse)
				{
				if ([self windowWithWindowNumber: as->windowTag] == nil)
					[self stopModal];		// if window closed end session
				else
					[as->window sendEvent: e];
				}
			}
		else if (t == NSLeftMouseDown || (t == NSRightMouseDown))
			NSBeep();
		}

	if (!_app.isHidden)
		if (_app.windowsNeedUpdate && (as->runState == NSRunContinuesResponse))
			{
			[as->window displayIfNeeded];
			[as->window flushWindowIfNeeded];
			[self updateWindows];					// update visible windows
			if (_app.isActive)
				[as->window makeKeyAndOrderFront: self];
			}

	NSAssert(_session == as, @"Session was changed while running");

	return as->runState;
}

- (NSWindow *) modalWindow
{
	return (_session) ? _session->window : nil;
}

- (void) abortModal
{
	if (_session == 0)
		[NSException raise: NSAbortModalException
					 format:@"abortModal called while not in a modal session"];

	[NSException raise: NSAbortModalException format: @"abortModal"];
}

- (void) stop:(id)sender	
{
	if (_session)
		[self stopModal];
	else
		_app.isRunning = NO;
}

- (void) stopModal			
{ 
	[self stopModalWithCode: NSRunStoppedResponse]; 
}

- (void) stopModalWithCode:(int)returnCode
{
	if (_session == 0)
		[NSException raise: NSInvalidArgumentException
					 format:@"stopModalWithCode: when not in a modal session"];

	if (returnCode == NSRunContinuesResponse)
		[NSException raise: NSInvalidArgumentException
					 format: @"stopModalWithCode: NSRunContinuesResponse ?"];
   
	_session->runState = returnCode;
}

- (NSModalSession) beginModalSessionForWindow:(NSWindow*)aWindow
{
	NSModalSession s;

	s = (NSModalSession) calloc(1, sizeof(struct _NSModalSession));
	s->runState = NSRunContinuesResponse;
	s->window = aWindow; 
	s->windowTag = [aWindow windowNumber];
	s->previous = _session;
	_session = s;

	return s;
}

- (void) endModalSession:(NSModalSession)aSession
{
	NSModalSession tmp = _session;

	if (aSession == 0)
		[NSException raise: NSInvalidArgumentException
					 format: @"null pointer passed to endModalSession:"];

	if (aSession->window == _keyWindow)
		{
		if (_mainWindow != _keyWindow)
			[_mainWindow makeKeyAndOrderFront: self];
		else
			_keyWindow = nil;
		}

	while (tmp && tmp != aSession)					// Remove this session from
		tmp = tmp->previous;						// linked list of sessions

	if (tmp == 0)
		[NSException raise: NSInvalidArgumentException
					 format: @"unknown session passed to endModalSession:"];

	while (_session != aSession)
		{
		tmp = _session;
		_session = tmp->previous;
		free(tmp);
		}

	_session = _session->previous;
	free(aSession);

	[self postEvent:_NSAppKitEvent() atStart:NO];
}
															
- (void) windowWillClose:(NSNotification *)aNotification 
{
	NSWindow *k = _keyWindow;
	NSWindow *w;
	NSWindow *o = [aNotification object];
	unsigned long i = [_windowList count];

	NSLog(@"NSApp windowWillClose");

	if (o == _keyWindow)
		_keyWindow = nil;
	if (o == _mainWindow)
		_mainWindow = nil;

	while (i--)
		if ((w = [_windowList objectAtIndex: i]) && (w == o))
			[_windowList removeObjectAtIndex: i];

	if (o != k)							// find a replacement
		NSLog(@"NSApp windowWillClose NOTE_OBJ is not KEY Win ********* %#x", k);

	if (k == o)							// find a replacement
		{
		if (_mainWindow && [_mainWindow canBecomeKeyWindow])
			[_mainWindow becomeKeyWindow];
		else
			{
			i = [_windowList count];
	
			while(i--)
				if ((w = [_windowList objectAtIndex: i])
						&& [w canBecomeKeyWindow] && [w isVisible])
					{
					[w orderFront:self];
					[w becomeKeyWindow];
					[w makeMainWindow];
					break;
		}	}		}
}

- (void) windowDidResignMain:(NSNotification *)aNotification
{
	if (!_app.isHidden && [aNotification object] == _mainWindow)
		_mainWindow = nil;
}

- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
	_keyWindow = [aNotification object];
	NSLog(@"NSApp windowDidBecomeKey '%@' %#x", [_keyWindow title], _keyWindow);
}

- (void) windowDidBecomeMain:(NSNotification *)aNotification
{
	_mainWindow = [aNotification object];
}

- (void) sendEvent:(NSEvent *)event					// pass event to its window
{
	switch ([event type])
		{
		case NSPeriodic:							// trap periodic events
			break;

		case NSKeyUp:
			DBLog(@"send key up event\n");
			[[event window] sendEvent:event];
			if(_mainMenu && [_mainMenu autoenablesItems])
				[_mainMenu update];
			break;

		case NSAppKitDefined:
			NSLog(@"NSApp NSAppKitDefined\n");		// NOTE falls thru
			if (!_app.isActive)
				_app.wantsToActivate = YES;
			if ([event subtype] != -3903 )			// 0xf0c1
				break;								// not synth'd focus-in

		case NSLeftMouseDown:
			[_mainMenu _closeAttachedMenu: event];
			if (!_app.isActive && ([event window] != _appIconWindow))
				[NSApp activateIgnoringOtherApps:NO];
			[[event window] sendEvent:event];

			if (_mainMenu && _app.isActive && [_mainMenu autoenablesItems])
				[_mainMenu update];
			break;

		case NSRightMouseDown:							// Right mouse down
			if ([event window])
				[[event window] sendEvent:event];
			else
				[self rightMouseDown: event];
			break;

		default:
			if (_app.isActive && [event window] == _keyWindow)
				[_keyWindow sendEvent:event];			// send to key window
			else
				[[event window] sendEvent:event];		// usually motion when
			break;										// app is not active
		}
}

- (void) rightMouseDown:(NSEvent *)event
{
	[_mainMenu _closeAttachedMenu: event];
	if (_mainMenu && !_copyOfMainMenu)					// Right mouse down
		_copyOfMainMenu = [_mainMenu copy];				// displays main menu
														// under the cursor
	if (_copyOfMainMenu)
		{
		NSPoint ml;
		NSView *v = [_copyOfMainMenu menuCells];
		NSWindow *w = [v window];
		NSSize menuSize = [w frame].size;

		ml = [[event window] convertBaseToScreen:[event locationInWindow]];
		ml.y -= (menuSize.height - 9);
		ml.x = ml.x - (menuSize.width/2);
		[w setFrameOrigin: ml];

		[w displayIfNeeded];

		[v rightMouseDown:event];
		[_mainMenu update];
		}
}

- (void) discardEventsMatchingMask:(unsigned int)mask
					   beforeEvent:(NSEvent *)lastEvent
{
	int i, loop, count;
	NSEvent *e = nil;

	if (mask == NSAnyEventMask && _currentEvent == lastEvent)
		{
		[_eventQueue removeAllObjects];
		return;
		}

	count = [_eventQueue count];
	for (i = 0, loop = 0; ((e != lastEvent) && (loop < count)); loop++)
		{											
		e = [_eventQueue objectAtIndex:i];				// remove event from
														// the queue if it 
		if ((mask & NSEventMaskFromType([e type]))) 	// matches the mask
			[_eventQueue removeObjectAtIndex:i];
		else											// inc queue cntr only
			i++;										// if not a match else
		}												// we will run off the
}														// end of the queue

- (NSEvent*) nextEventMatchingMask:(unsigned int)mask
						 untilDate:(NSDate *)expiration
						 inMode:(NSString *)mode
						 dequeue:(BOOL)f
{
	while (!(_currentEvent = [_eventQueue eventMatchingMask:mask dequeue:f]))
		{
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		NSDate *limitDate;

		if (!expiration)
			{
			if (_app.isActive || _app.wantsToActivate)
				{
				_app.wantsToActivate = NO;
				expiration = [NSDate dateWithTimeIntervalSinceNow:.2];
				}
			else
				expiration = [NSDate distantFuture];
			}
		else if ([expiration timeIntervalSinceNow] < 0)
       		break;							// returns nil current event

		if (!(limitDate = [rl limitDateForMode:mode]))
			limitDate = expiration;
		if ((_currentEvent = [_eventQueue eventMatchingMask:mask dequeue:f]))
       		break;

		limitDate = [[expiration earlierDate:limitDate] retain];
		[rl runMode:mode beforeDate:limitDate];
    	[limitDate release];				// limitDate is retained so that it
		}									// won't get released accidentally
											// by runMode:beforeDate: if timer
	return _currentEvent;					// with this fire date is released
}

- (void) postEvent:(NSEvent *)event atStart:(BOOL)flag
{
	if (!flag)
		[_eventQueue addObject: event];
	else
		[_eventQueue insertObject:event atIndex:0];
}
														// Send action messages
- (BOOL) sendAction:(SEL)aSelector to:(id)aTarget from:(id)sender
{														// If target responds 
	if ([aTarget respondsToSelector:aSelector])			// to the selector then
		{												// have it perform it
		[aTarget performSelector:aSelector withObject:sender];

		return YES;
		}												// FIX ME 

	return NO;											// Otherwise traverse 
}												

- (id) targetForAction:(SEL)aSelector
{
	if (_keyWindow != nil)
		{
		id responder = [_keyWindow firstResponder];

		while (responder)
			{
			if ([responder respondsToSelector: aSelector])
				return responder;

			responder = [responder nextResponder];
			}

		if ([_keyWindow respondsToSelector: aSelector])
			return _keyWindow;

		responder = [_keyWindow delegate];
		if (responder != nil && [responder respondsToSelector: aSelector])
			return responder;

		if (_session)
			return _keyWindow;						// validate menu when modal
		}

	if (_keyWindow != _mainWindow && _mainWindow != nil)
		{
		id responder = [_mainWindow firstResponder];

		while (responder)
			{
			if ([responder respondsToSelector: aSelector])
				return responder;

			responder = [responder nextResponder];
			}

		if ([_mainWindow respondsToSelector: aSelector])
			return _mainWindow;

		responder = [_mainWindow delegate];
		if (responder != nil && [responder respondsToSelector: aSelector])
			return responder;
		}

	if ([self respondsToSelector: aSelector])
		return self;

	if (_delegate != nil && [_delegate respondsToSelector: aSelector])
		return _delegate;

//	if(_docController && [_docController respondsToSelector: aSelector])
//		return _docController;

	return nil;
}

- (BOOL) tryToPerform:(SEL)aSelector with:(id)anObject
{
	if ([super tryToPerform: aSelector with: anObject] == YES)
		return YES;

	if (_delegate != nil && [_delegate respondsToSelector: aSelector])
		{
		[_delegate performSelector: aSelector withObject: anObject];

		return YES;
		}

	return NO;
}

- (NSGraphicsContext *) context					{ return _context; }
- (NSImage *) applicationIconImage				{ return _appIcon; }
- (NSWindow*) appIcon							{ return _appIconWindow; }
- (NSWindow*) keyWindow							{ return _keyWindow; }
- (NSWindow*) mainWindow						{ return _mainWindow; }
- (NSArray *) windows							{ return _windowList; }
- (NSEvent *) currentEvent						{ return _currentEvent; }
- (BOOL) isRunning								{ return _app.isRunning; }
- (BOOL) isActive								{ return _app.isActive; }
- (BOOL) isHidden								{ return _app.isHidden; }

- (void) activateIgnoringOtherApps:(BOOL)flag
{
	if (!_app.isActive || flag)				// menu's should listen for notice
		{									// to open when app becomes active
		[NSNotificationCenter post: NOTE(WillBecomeActive) object: self];

NSLog(@"NSApp activateIgnoringOtherApps");
		[_mainMenu display];				// unhide app's menu's
		if(flag)
			{
			if(_mainWindow)
				[_mainWindow becomeMainWindow];
			if(_keyWindow)
				[_keyWindow becomeKeyWindow];
			}

		_app.isActive = YES;
		[NSNotificationCenter post: NOTE(DidBecomeActive) object: self];
		}
}

- (void) deactivate
{
	if (_app.isActive && !_app.wantsToActivate && !_app.isTerminating)
		{
		_app.isActive = NO;
		[NSNotificationCenter post:NOTE(WillResignActive) object:self];
NSLog(@"NSApp deactivate");
		[_keyWindow resignKeyWindow];
		[_mainMenu close];
		[self discardEventsMatchingMask:NSAnyEventMask beforeEvent:_currentEvent];
		[NSNotificationCenter post:NOTE(DidResignActive) object:self];
		}
}

- (void) hide:(id)sender
{
	if (!_app.isHidden)
		{
		NSEnumerator *e = [_windowList reverseObjectEnumerator];
		NSWindow *w;
													// notify that we will hide
		[NSNotificationCenter post:NOTE(WillHide) object:self];

		[self deactivate];
													// Tell the windows to hide
		while ((w = [e nextObject]) && w != _appIconWindow)
			[w orderOut:sender];

		_app.isHidden = YES;						// notify that we did hide
		[NSNotificationCenter post:NOTE(DidHide) object:self];
		}
}

- (void) unhide:(id)sender
{
	[self unhideWithoutActivation];
	[self activateIgnoringOtherApps: YES];
}

- (void) unhideWithoutActivation
{
	[NSNotificationCenter post:NOTE(WillUnhide) object:self];
	[self arrangeInFront: self];
	_app.isHidden = NO;
	[NSNotificationCenter post:NOTE(DidUnhide) object:self];
}

- (void) arrangeInFront:(id)sender			// Arrange Windows menu listed
{											// windows in front of all others
	NSEnumerator *e = [[_windowsMenu itemArray] objectEnumerator];
	Class windowClass = [NSWindow class];
	id w, item;

	while ((item = [e nextObject]))
		if ((w = [item target]) && w != _keyWindow && w != _mainWindow
				&& [w isKindOfClass: windowClass])
			[w orderFront: sender];

	if (_mainWindow && (_keyWindow != _mainWindow))
		[_mainWindow orderFront: sender];
	if (_keyWindow)
		[_keyWindow orderFront: sender];
}

- (NSWindow *) makeWindowsPerform:(SEL)aSelector inOrder:(BOOL)flag
{
	NSWindow *w;
	NSEnumerator *e = (flag) ? [_windowList objectEnumerator]
							 : [_windowList reverseObjectEnumerator];
	// FIX ME: YES flag indicates by Z-order ignoring minimized windows
	while ((w = [e nextObject]))
		if (![w respondsToSelector:@selector(_menuWindow)])	  // ignore menus
			if ([w performSelector: aSelector] != nil)
				return w;

	return nil;
}

- (NSWindow *) windowWithWindowNumber:(int)tag
{
	return NSMapGet( ((CGContext *)_context)->_mg->_winToTag, INT2PTR(tag) );
}

- (void) miniaturizeAll:(id)sender
{
	NSEnumerator *e = [_windowList objectEnumerator];
	NSWindow *w;

	while ((w = [e nextObject]))
		[w miniaturize:sender];
}

- (void) preventWindowOrdering
{
}

- (void) setWindowsNeedUpdate:(BOOL)flag
{
	_app.windowsNeedUpdate = flag;
}

- (void) updateWindows								// send an update message
{													// to all visible windows
	int i, count = [_windowList count];
	NSWindow *w;
													// an update is imminent
	[NSNotificationCenter post: NOTE(WillUpdate) object: self];

	for (i = 0; i < count; i++)
		if ([(w = [_windowList objectAtIndex:i]) isVisible])
    		[w update];
  													// notify update did occur
	[NSNotificationCenter post:NSApplicationDidUpdateNotification object:self];
}

- (void) orderFrontColorPanel:(id)sender			// Standard Panels
{
	[[NSColorPanel sharedColorPanel] display];
	[[NSColorPanel sharedColorPanel] orderFront: sender];
}

- (void) orderFrontStandardAboutPanel:(id)sender
{
	if (![NSBundle loadNibNamed:@"AboutPanel.nib" owner:sender])
		NSLog(@"Failed to open About Panel");
}

- (void) orderFrontHelpPanel:(id)sender
{
}

- (void) setMainMenu:(NSMenu *)aMenu
{
	NSArray *mi = [aMenu itemArray];
	int i, j = [mi count];

	ASSIGN(_mainMenu, aMenu);
	[_mainMenu setHorizontal: YES];
	if ([[_mainMenu title] isEqualToString: @"MainMenu"])
		{
		NSString *appName = [[NSProcessInfo processInfo] processName];
		NSMenuItem *m = [_mainMenu itemWithTitle: @"Info"];
		NSMenuItem *t = [_mainMenu itemWithTitle: @"MainMenu"];

		[m setTitle: appName];
		[_mainMenu setTitle: appName];
		[_mainMenu removeItem: t];
		}
													// search menu for an item
	_windowsMenu = nil;								// titled 'Windows', this
	for (i = 0; i < j; ++i)							// is the default menucell
		{											// for the Windows submenu
		NSMenuItem *item = [mi objectAtIndex:i];
		NSMenu *wm;

		if ([[item stringValue] compare:@"Windows"] == NSOrderedSame)
			{
			_windowsMenuItem = item;				// Found it!
			if((wm = [_windowsMenuItem target]))
				_windowsMenu = wm;		

			break;
		}	}
}

- (void) setAppleMenu:(NSMenu *)aMenu	{ ASSIGN(_mainMenu, aMenu); }
- (NSMenu *) mainMenu					{ return _mainMenu; }
- (NSMenu *) windowsMenu				{ return _windowsMenu; }
- (NSMenu *) servicesMenu				{ return [_listener servicesMenu]; }

- (void) addWindowsItem:(NSWindow *)aWindow		// Windows submenu
				  title:(NSString *)aString
				  filename:(BOOL)isFilename
{
	[self changeWindowsItem:aWindow title:aString filename:isFilename];

	if(!_mainWindow)							// if the window is being added
		{										// to the app's window menu it
		_mainWindow = aWindow;					// can become main so ask it to
		[aWindow becomeMainWindow];				// be main if no other win is.
		}
}

- (void) changeWindowsItem:(NSWindow *)aWindow
					 title:(NSString *)aString
					 filename:(BOOL)isFilename
{
	id foundItem = nil;
	id item = nil;
	int i = 0;

	if (![aWindow isKindOfClass: [NSWindow class]])
		[NSException raise:NSInvalidArgumentException format:@"Not a window"];

	if ([aWindow isKindOfClass: [NSMenu class]])	// Don't add menus to the	
		return;										// app's windows list
	if (!_windowsMenuItem || !aString || [aString isEqualToString: @""])
		return;										// Must have a title and
													// windows menu item
	if (_windowsMenu)
		{
		NSEnumerator *e = [[_windowsMenu itemArray] objectEnumerator];
		BOOL foundInsertionIndex = NO;

		while((item = [e nextObject]))
			{
			if (!foundInsertionIndex)
				{
				if (!SEL_EQ([item action], @selector(makeKeyAndOrderFront:)))
					i = MAX(i,1);
				else if ([[item title] compare:aString] == NSOrderedDescending)
					foundInsertionIndex = YES;
				else
					i++;
				}

			if (!foundItem && [item target] == aWindow)
				{
				foundItem = item;
				i = (i > 0) ? i-- : 0;
		}	}	}
	else
		{
		_windowsMenu = [[NSMenu alloc] initWithTitle:[_windowsMenuItem title]];
		[self setWindowsMenu: _windowsMenu];
		}

	if (foundItem)
		{
		NSMutableArray *m;

		if ([[foundItem title] isEqualToString: aString])
			return;

//		if (isFilename)
//			aString = [aWindow representedFilename];
		[(item = foundItem) setTitle: aString];
		[_windowsMenu removeItem: [item retain]];
		m = (NSMutableArray*)[_windowsMenu itemArray];
		[m insertObject:[item autorelease] atIndex:i];
		}
	else
		{
		item = [_windowsMenu insertItemWithTitle: aString
							 action: @selector(makeKeyAndOrderFront:)
							 keyEquivalent: @""
							 atIndex: i];
		[item setTarget: aWindow];
		[item setImagePosition: NSImageLeft];
		}

	if ([aWindow isDocumentEdited])
		{
		[item setImage: [NSImage imageNamed: @"menuCloseBroken"]];
		[item setAlternateImage: [NSImage imageNamed: @"menuCloseBrokenH"]];
		}
	else
		{
		[item setImage: [NSImage imageNamed: @"menuClose"]];
		[item setAlternateImage: [NSImage imageNamed: @"menuCloseH"]];
		}
	[_windowsMenu sizeToFit];
	[_windowsMenu update];
	[_copyOfMainMenu autorelease];						// right mouse down
	_copyOfMainMenu = nil;								// menu must be rebuilt
}

- (void) removeWindowsItem:(NSWindow*)aWindow
{
	if (!_app.isDeallocating)
		{
		NSEnumerator *e = [[_windowsMenu itemArray] objectEnumerator];
		id item;

		while((item = [e nextObject]))
			if ([item target] == aWindow)
				{
				[_windowsMenu removeItem: item]; 
				[_windowsMenu sizeToFit];
				[_windowsMenu update];
				[_copyOfMainMenu autorelease];			// right mouse down
				_copyOfMainMenu = nil;					// menu must be rebuilt
				break;
		}		}
}

- (void) setWindowsMenu:(NSMenu *)aMenu
{
	if (_windowsMenuItem && aMenu && _windowsMenu != aMenu)
		{
		NSEnumerator *e = [[_windowsMenu itemArray] objectEnumerator];
		Class windowClass = [NSWindow class];
		id w, item;

		_windowsMenu = aMenu;
		while ((item = [e nextObject]))
			if ([(w = [item target]) isKindOfClass: windowClass])
				[self changeWindowsItem: w
					  title: [w title]
					  filename: ([w representedFilename] != nil)];
		
		[_mainMenu setSubmenu:aMenu forItem:_windowsMenuItem];
		[_windowsMenu sizeToFit];
		[_windowsMenu update];
		[_copyOfMainMenu autorelease];					// right mouse down
		_copyOfMainMenu = nil;							// menu must be rebuilt
		}
}

- (void) updateWindowsItem:(NSWindow *)aWindow
{
	NSEnumerator *e = [[_windowsMenu itemArray] objectEnumerator];
	id item;

	while((item = [e nextObject]))
		if ([item target] == aWindow)
			{
			NSImage	*newImage;
			BOOL isDocumentEdited;
	
			if ((isDocumentEdited = [aWindow isDocumentEdited]))
				newImage = [NSImage imageNamed: @"menuCloseBroken"];
			else
				newImage = [NSImage imageNamed: @"menuClose"];

			if (newImage != [item image])
				{
				[item setImage: newImage];
				if (isDocumentEdited)
					newImage = [NSImage imageNamed: @"menuCloseBrokenH"];
				else
					newImage = [NSImage imageNamed: @"menuCloseH"];
				[item setAlternateImage: newImage];
				[item setEnabled: NO];		// hack triggers validation FIX ME
				[_windowsMenu update];
				[_copyOfMainMenu autorelease];			// right mouse down
				_copyOfMainMenu = nil;					// menu must be rebuilt
				}
			break;
			}
}

- (void) reportException:(NSException *)anException
{															// Report exception
	if (anException)
		NSLog(@"reported exception - %@", anException);
}

- (void) terminate:(id)sender								// App termination
{
	if (!_app.isTerminating)
	  {
	  if ([_delegate respondsToSelector:@selector(applicationShouldTerminate:)])
			{
			NSUInteger t = [_delegate applicationShouldTerminate:self];

			if (t != NSTerminateNow)
				{
				_app.isTerminating = (t == NSTerminateCancel) ? 0 : 1;
				return;		// NSTerminateLater requires call to replyToApp...
			}	}			// when app determines if it will terminate

	  _app.isTerminating = 1;
	  }
	else if (sender != self)
	  return;

	[NSNotificationCenter post: NOTE(WillTerminate) object: self];
	exit(0);
}

- (void) replyToApplicationShouldTerminate:(BOOL)shouldTerminate
{
	if (_app.isTerminating && shouldTerminate)
		[self terminate:self];
	else
		_app.isTerminating = 0;
}

- (id) delegate							{ return _delegate; }

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;

	if (_delegate == anObject)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSApplication##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(DidBecomeActive);
		IGNORE_(DidFinishLaunching);
		IGNORE_(DidHide);
		IGNORE_(DidResignActive);
		IGNORE_(DidUnhide);
		IGNORE_(DidUpdate);
		IGNORE_(WillBecomeActive);
		IGNORE_(WillFinishLaunching);
		IGNORE_(WillHide);
		IGNORE_(WillResignActive);
		IGNORE_(WillUnhide);
		IGNORE_(WillUpdate);
		IGNORE_(WillTerminate);
		}

	if (!(_delegate = anObject))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(application##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(application##notif_name:) \
		   name:NSApplication##notif_name##Notification \
		   object:self]

	OBSERVE_(DidBecomeActive);
	OBSERVE_(DidFinishLaunching);
	OBSERVE_(DidHide);
	OBSERVE_(DidResignActive);
	OBSERVE_(DidUnhide);
	OBSERVE_(DidUpdate);
	OBSERVE_(WillBecomeActive);
	OBSERVE_(WillFinishLaunching);
	OBSERVE_(WillHide);
	OBSERVE_(WillResignActive);
	OBSERVE_(WillUnhide);
	OBSERVE_(WillUpdate);
	OBSERVE_(WillTerminate);
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeObject: _windowList];
	[aCoder encodeConditionalObject:_keyWindow];
	[aCoder encodeConditionalObject:_mainWindow];
	[aCoder encodeConditionalObject:_delegate];
	[aCoder encodeObject:_mainMenu];
	[aCoder encodeConditionalObject:_windowsMenu];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_windowList = [aDecoder decodeObject];
	_keyWindow = [aDecoder decodeObject];
	_mainWindow = [aDecoder decodeObject];
	_delegate = [aDecoder decodeObject];
	_mainMenu = [aDecoder decodeObject];
	_windowsMenu = [aDecoder decodeObject];

	return self;
}

@end /* NSApplication */
