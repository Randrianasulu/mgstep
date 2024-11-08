/*
   NSApplication.h

   Application management class

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSApplication
#define _mGSTEP_H_NSApplication

#include <AppKit/NSResponder.h>

@class NSArray;
@class NSMutableArray;
@class NSString;
@class NSException;
@class NSNotification;
@class NSDate;
@class NSEvent;
@class NSPasteboard;
@class NSMenu;
@class NSMenuItem;
@class NSImage;
@class NSWindow;
@class NSGraphicsContext;
@class NSPanel;


typedef struct _NSModalSession *NSModalSession;

enum {				// runModalFor:, runModalSession:  return values < 10.9
	NSRunStoppedResponse   = -1000,
	NSRunAbortedResponse   = -1001,
	NSRunContinuesResponse = -1002,
};

typedef enum {		// runModalFor:, runModalSession:  return values
	NSModalResponseStop     = -1000,
	NSModalResponseAbort    = -1001,
	NSModalResponseContinue = -1002,
} NSModalResponse;

typedef enum {		// -applicationShouldTerminate:  return values
	NSTerminateCancel,
	NSTerminateNow,
	NSTerminateLater
} NSApplicationTerminateReply;



@interface NSApplication : NSResponder  <NSCoding>
{
	NSEvent *_currentEvent;
	NSMutableArray *_windowList;
	NSModalSession _session;
	id _keyWindow;
	id _mainWindow;
	id _delegate;
	id _listener;
	NSMenu *_mainMenu;
	NSMenu *_windowsMenu;
	NSMenu *_copyOfMainMenu;
	NSMenuItem *_windowsMenuItem;
	NSImage *_appIcon;
	NSWindow *_appIconWindow;

	NSGraphicsContext *_context;
	id _eventQueue;

    struct __appFlags {
		unsigned int isRunning:1;
        unsigned int isActive:1;
        unsigned int isHidden:1;
		unsigned int windowsNeedUpdate:1;
		unsigned int isDeallocating:1;
		unsigned int isTerminating:1;
		unsigned int wantsToActivate:1;
		unsigned int reserved:25;
    } _app;
}

+ (NSApplication *) sharedApplication;

- (void) finishLaunching;

- (void) activateIgnoringOtherApps:(BOOL)flag;				// activate app
- (void) deactivate;
- (BOOL) isActive;

- (void) run;												// run app loop
- (void) sendEvent:(NSEvent *)event;
- (void) stop:(id)sender;
- (BOOL) isRunning;

- (int) runModalForWindow:(NSWindow *)window;				// modal loop
- (int) runModalSession:(NSModalSession)aSession;
- (NSModalSession) beginModalSessionForWindow:(NSWindow *)window;
- (void) endModalSession:(NSModalSession)aSession;
- (void) abortModal;
- (void) stopModal;
- (void) stopModalWithCode:(int)returnCode;
- (NSWindow *) modalWindow;

- (NSEvent *) currentEvent;									// events
- (NSEvent *) nextEventMatchingMask:(unsigned int)mask
						  untilDate:(NSDate *)expiration
							 inMode:(NSString *)mode
							dequeue:(BOOL)flag;
- (void) postEvent:(NSEvent *)e atStart:(BOOL)flag;
- (void) discardEventsMatchingMask:(unsigned int)mask beforeEvent:(NSEvent *)e;

- (id) targetForAction:(SEL)aSelector;						// target / action
- (BOOL) sendAction:(SEL)aSelector to:aTarget from:(id)sender;
- (BOOL) tryToPerform:(SEL)aSelector with:(id)anObject;

- (NSImage *) applicationIconImage;

- (void) hide:(id)sender;									// hide windows
- (BOOL) isHidden;
- (void) unhide:(id)sender;
- (void) unhideWithoutActivation;

- (NSWindow *) keyWindow;									// manage windows
- (NSWindow *) mainWindow;
- (NSWindow *) windowWithWindowNumber:(int)windowNumber;
- (NSWindow *) makeWindowsPerform:(SEL)aSelector inOrder:(BOOL)flag;

- (void) miniaturizeAll:(id)sender;
- (void) preventWindowOrdering;
- (void) setWindowsNeedUpdate:(BOOL)flag;
- (void) arrangeInFront:(id)sender;
- (void) updateWindows;
- (NSArray *) windows;

- (void) orderFrontColorPanel:(id)sender;					// Show std Panels
- (void) orderFrontHelpPanel:(id)sender;

- (NSMenu *) mainMenu;										// Menus
- (NSMenu *) windowsMenu;
- (NSMenu *) servicesMenu;

- (void) setMainMenu:(NSMenu *)aMenu;
- (void) setWindowsMenu:(NSMenu *)aMenu;

- (void) addWindowsItem:(NSWindow *)aWindow					// Windows menu
				  title:(NSString *)aString
				  filename:(BOOL)isFilename;
- (void) changeWindowsItem:(NSWindow *)aWindow
					 title:(NSString *)aString
					 filename:(BOOL)isFilename;
- (void) removeWindowsItem:(NSWindow *)aWindow;
- (void) updateWindowsItem:(NSWindow *)aWindow;

- (NSGraphicsContext *) context;							// Display context

- (void) reportException:(NSException *)anException;		// Report exception

- (void) terminate:(id)sender;								// Terminate app
- (void) replyToApplicationShouldTerminate:(BOOL)shouldTerminate;

- (id) delegate;
- (void) setDelegate:(id)anObject;

@end


@interface NSApplication (ApplicationBackend)

- (void) setApplicationIconImage:(NSImage *)anImage;		// App Icon
- (NSWindow *) appIcon;										// NeXTSTEP method

@end


@protocol NSApplicationDelegate  <NSObject>					// Implemented by
															// the delegate
- (BOOL) application:(id)sender openFileWithoutUI:(NSString *)filename;
- (BOOL) application:(NSApplication *)app openFile:(NSString *)filename;
- (BOOL) application:(NSApplication *)app openTempFile:(NSString *)filename;
- (BOOL) applicationOpenUntitledFile:(NSApplication *)app;
- (BOOL) applicationShouldTerminate:(id)sender;
- (BOOL) application:(NSApplication *)app printFile:(NSString *)filename;

@end


@interface NSApplication (AppKitServices)					// Services

- (id) servicesProvider;
- (void) setServicesProvider:(id)anObject;
- (void) setServicesMenu:(NSMenu *)aMenu;
- (void) registerServicesMenuSendTypes:(NSArray *)st returnTypes:(NSArray *)rt;
- (id) validRequestorForSendType:(NSString *)sendType
					  returnType:(NSString *)returnType;
@end


@interface NSObject (NSServicesRequests)					// Pasteboard

- (BOOL) readSelectionFromPasteboard:(NSPasteboard *)pboard;
- (BOOL) writeSelectionToPasteboard:(NSPasteboard *)pboard
                              types:(NSArray *)types;
@end


@interface NSObject (NSApplicationNotifications)			// Implemented by
															// NSApp delegate
- (void) applicationDidBecomeActive:(NSNotification *)aNotification;
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void) applicationDidHide:(NSNotification *)aNotification;
- (void) applicationDidResignActive:(NSNotification *)aNotification;
- (void) applicationDidUnhide:(NSNotification *)aNotification;
- (void) applicationDidUpdate:(NSNotification *)aNotification;
- (void) applicationWillBecomeActive:(NSNotification *)aNotification;
- (void) applicationWillFinishLaunching:(NSNotification *)aNotification;
- (void) applicationWillHide:(NSNotification *)aNotification;
- (void) applicationWillResignActive:(NSNotification *)aNotification;
- (void) applicationWillUnhide:(NSNotification *)aNotification;
- (void) applicationWillUpdate:(NSNotification *)aNotification;
- (void) applicationWillTerminate:(NSNotification *)notification;

@end


@interface NSApplication (NSStandardAboutPanel)

- (void) orderFrontStandardAboutPanel:(id)sender;

@end


extern NSString *NSApplicationDidBecomeActiveNotification;
extern NSString *NSApplicationDidFinishLaunchingNotification;
extern NSString *NSApplicationDidHideNotification;
extern NSString *NSApplicationDidResignActiveNotification;
extern NSString *NSApplicationDidUnhideNotification;
extern NSString *NSApplicationDidUpdateNotification;
extern NSString *NSApplicationWillBecomeActiveNotification;
extern NSString *NSApplicationWillFinishLaunchingNotification;
extern NSString *NSApplicationWillTerminateNotification;
extern NSString *NSApplicationWillHideNotification;
extern NSString *NSApplicationWillResignActiveNotification;
extern NSString *NSApplicationWillUnhideNotification;
extern NSString *NSApplicationWillUpdateNotification;
extern NSString *NSApplicationWillTerminateNotification;

extern NSString *NSModalPanelRunLoopMode;
extern NSString *NSEventTrackingRunLoopMode;

extern NSString *NSApplicationIcon;


extern NSApplication *NSApp;								// NSApp global

extern const double NSAppKitVersionNumber;

#ifndef APPKIT_VERSION
  #define _STRINGIFY(x)       @#x
  #define _APPKIT_VER_STR(x)  _STRINGIFY(\040mGSTEP x )
  #define  APPKIT_VERSION     _APPKIT_VER_STR( mGSTEP_VERSION )
#endif

//
// Services
//
int  NSSetShowsServicesMenuItem(NSString *item, BOOL showService);
BOOL NSShowsServicesMenuItem(NSString *item);
BOOL NSPerformService(NSString *item, NSPasteboard *pboard);
void NSUpdateDynamicServices(void);
void NSRegisterServicesProvider(id provider, NSString *name);
void NSUnregisterServicesProvider(NSString *name);


extern int NSApplicationMain(int argc, const char *argv[]);

extern NSEvent * _NSAppKitEvent(void);

#endif /* _mGSTEP_H_NSApplication */
