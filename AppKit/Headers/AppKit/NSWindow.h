/*
   NSWindow.h

   Window class

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSWindow
#define _mGSTEP_H_NSWindow

#include <AppKit/NSGraphics.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSResponder.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSNotification;
@class NSDate;
@class NSDocument;
@class NSColor;
@class NSEvent;
@class NSGraphicsContext;
@class NSImage;
@class NSPasteboard;
@class NSScreen;
@class NSText;
@class NSView;


enum {
	NSNormalWindowLevel	  = 0,
	NSFloatingWindowLevel = 3,
	NSDockWindowLevel	  = 5,
	NSSubmenuWindowLevel  = 10,
	NSStatusWindowLevel   = 15,
	NSMainMenuWindowLevel = 20
};

enum {
	NSBorderlessWindowMask     = 0,
	NSTitledWindowMask         = 1,
	NSClosableWindowMask       = 2,
	NSMiniaturizableWindowMask = 4,
	NSResizableWindowMask      = 8,
	NSTexturedBackgroundWindowMask     = 1 << 8,
	NSUnifiedTitleAndToolbarWindowMask = 1 << 12,
	NSFullScreenWindowMask             = 1 << 14,
	_NSCommonWindowMask        = 15						// OR of first four
};

typedef enum {											// Backing Store Types:
	NSBackingStoreRetained    = 0,						// draw to window w/buf
	NSBackingStoreNonretained = 1,						// draw to window
	NSBackingStoreBuffered    = 2						// draw to buffer *use*
} NSBackingStoreType;

typedef enum {											// Window ordering
	NSWindowAbove,
	NSWindowBelow,
	NSWindowOut
} NSWindowOrderingMode;



@interface NSWindow : NSResponder  <NSCoding>
{
	NSRect _frame;
	NSSize _minSize;
	NSSize _maxSize;
	NSSize _aspectRatio;
	NSSize _resizeIncrements;
	id _contentView;
	id _firstResponder;
	id _initialFirstResponder;
	id _delegate;
	id _fieldEditor;
	id _undoManager;
	NSColor *_backgroundColor;
	NSString *_representedFilename;
    NSString *_frameSaveName;
	NSString *_windowTitle;
	NSString *_miniWindowTitle;
	NSImage *_miniWindowImage;
    NSView *_lastLeftHit;
    NSView *_lastRightHit;
    NSView *_lastKeyDown;
	NSMutableArray *_trackRects;
	NSMutableArray *_cursorRects;
	NSWindowDepth _depthLimit;

	unsigned int _styleMask;
	int _level;
	NSScreen *_screen;
	NSGraphicsContext *_context;
	NSInteger _windowNumber;

#ifdef FB_GRAPHICS
	NSWindow *_below;						// next window in FB screen list
#else
	NSRect _exposeRect;						// X expose event support
#endif

    struct __WindowFlags {
		unsigned int isOneShot:1;
		unsigned int needsDisplay:1;
		unsigned int needsFlush:1;
		unsigned int autodisplay:1;
		unsigned int optimizeDrawing:1;		// preserve overlap views Z-order
		unsigned int dynamicDepthLimit:1;
		unsigned int cursorRectsEnabled:1;
		unsigned int cursorRectsValid:1;
		unsigned int visible:1;
		unsigned int isKey:1;
		unsigned int isMain:1;
		unsigned int isEdited:1;
		unsigned int releasedWhenClosed:1;
		unsigned int miniaturized:1;
		unsigned int disableFlushWindow:1;
		unsigned int menuExclude:1;
		unsigned int hidesOnDeactivate:1;
		unsigned int acceptsMouseMoved:1;
		unsigned int appIcon:1;
		NSBackingStoreType backingType:2;
		unsigned int deferred:1;
		unsigned int canNotify:1;
		unsigned int tossFirstEvent:1;
		unsigned int becomesKeyOnlyIfNeeded:1;
		unsigned int worksWhenModal:1;		// recv events when another is modal
		unsigned int isPanel:1;
		unsigned int showingModalFrame:1;
		unsigned int reserved:4;
	} _w;
}

+ (NSRect) contentRectForFrameRect:(NSRect)r styleMask:(NSUInteger)aStyle;
+ (NSRect) frameRectForContentRect:(NSRect)r styleMask:(NSUInteger)aStyle;
+ (NSRect) minFrameWidthWithTitle:(NSString *)t styleMask:(NSUInteger)aStyle;

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)flag
				 screen:(NSScreen*)aScreen;

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)flag;

- (id) contentView;											// Content view
- (void) setContentView:(NSView *)aView;

- (unsigned int) styleMask;
- (NSColor *) backgroundColor;								// Window graphics
- (NSString *) representedFilename;
- (void) setBackgroundColor:(NSColor *)color;
- (void) setRepresentedFilename:(NSString *)aString;
- (void) setTitleWithRepresentedFilename:(NSString *)aString;
- (void) setTitle:(NSString *)aString;
- (NSString *) title;

- (void) setBackingType:(NSBackingStoreType)type;
- (NSBackingStoreType) backingType;							// Device attribs
- (NSInteger) windowNumber;
- (NSInteger) gState;

- (NSGraphicsContext *) graphicsContext;

- (NSImage *) miniwindowImage;								// Mini window
- (NSString *) miniwindowTitle;
- (void) setMiniwindowImage:(NSImage *)image;
- (void) setMiniwindowTitle:(NSString *)title;

- (void) endEditingFor:(id)anObject;						// Field editor
- (NSText *) fieldEditor:(BOOL)createFlag forObject:(id)anObject;

- (void) orderFrontRegardless;
- (void) orderFront:(id)sender;
- (void) orderOut:(id)sender;

- (void) becomeKeyWindow;
- (void) becomeMainWindow;									// status / order
- (BOOL) canBecomeKeyWindow;
- (BOOL) canBecomeMainWindow;
- (BOOL) hidesOnDeactivate;
- (BOOL) isKeyWindow;
- (BOOL) isMainWindow;
- (BOOL) isMiniaturized;
- (BOOL) isVisible;
- (BOOL) inLiveResize;
- (void) makeKeyAndOrderFront:(id)sender;
- (void) makeKeyWindow;
- (void) makeMainWindow;
- (void) resignKeyWindow;
- (void) resignMainWindow;
- (void) setHidesOnDeactivate:(BOOL)flag;
- (void) orderWindow:(NSWindowOrderingMode)place relativeTo:(int)otherWin;
- (void) setLevel:(int)newLevel;
- (int) level;

- (void) center;											// Window frame
- (NSPoint) cascadeTopLeftFromPoint:(NSPoint)topLeftPoint;
- (NSRect) frameRectForContentRect:(NSRect)cRect;
- (NSRect) constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen;
- (NSRect) frame;
- (NSSize) minSize;
- (NSSize) maxSize;
- (NSSize) resizeIncrements;
- (void) setMinSize:(NSSize)aSize;
- (void) setMaxSize:(NSSize)aSize;
- (void) setContentSize:(NSSize)aSize;
- (void) setResizeIncrements:(NSSize)aSize;
- (void) setFrame:(NSRect)frameRect display:(BOOL)flag;
- (void) setFrameTopLeftPoint:(NSPoint)aPoint;
- (void) setFrameOrigin:(NSPoint)aPoint;

- (NSSize) aspectRatio;
- (void) setAspectRatio:(NSSize)aSize;

- (NSPoint) convertBaseToScreen:(NSPoint)aPoint;			// Convert coords
- (NSPoint) convertScreenToBase:(NSPoint)aPoint;			// OSX deprecated
- (NSPoint) mouseLocationOutsideOfEventStream;

//- (NSRect) convertRectToBacking:(NSRect)r;				// pixel integral
//- (NSRect) convertRectFromBacking:(NSRect)r;
//- (NSRect) convertRectToScreen:(NSRect)r;
//- (NSRect) convertRectFromScreen:(NSRect)r;

- (void) update;
- (void) display;											// Display
- (void) displayIfNeeded;
- (BOOL) viewsNeedDisplay;
- (BOOL) isAutodisplay;
- (void) setAutodisplay:(BOOL)flag;
- (void) setViewsNeedDisplay:(BOOL)flag;
- (void) useOptimizedDrawing:(BOOL)flag;

- (void) enableFlushWindow;
- (void) disableFlushWindow;
- (BOOL) isFlushWindowDisabled;
- (void) flushWindowIfNeeded;
- (void) flushWindow;

+ (NSWindowDepth) defaultDepthLimit;						// Color depths
- (NSWindowDepth) depthLimit;
- (BOOL) canStoreColor;
- (BOOL) hasDynamicDepthLimit;
- (NSScreen *) deepestScreen;
- (NSScreen *) screen;
- (void) setDepthLimit:(NSWindowDepth)limit;
- (void) setDynamicDepthLimit:(BOOL)flag;

- (BOOL) areCursorRectsEnabled;								// Cursor
- (void) disableCursorRects;
- (void) enableCursorRects;
- (void) discardCursorRects;
- (void) invalidateCursorRectsForView:(NSView *)aView;
- (void) resetCursorRects;

- (void) close;												// Event handling
- (void) performClose:(id)sender;
- (void) setReleasedWhenClosed:(BOOL)flag;
- (BOOL) isReleasedWhenClosed;
- (BOOL) isOneShot;
- (void) setOneShot:(BOOL)flag;
- (void) setDocumentEdited:(BOOL)flag;
- (BOOL) isDocumentEdited;
- (int) resizeFlags;										// modifierflags of
															// last mouse down
- (void) performMiniaturize:(id)sender;
- (void) deminiaturize:(id)sender;
- (void) miniaturize:(id)sender;

- (void) setAcceptsMouseMovedEvents:(BOOL)flag;
- (BOOL) acceptsMouseMovedEvents;							// Event processing
- (BOOL) makeFirstResponder:(NSResponder *)aResponder;
- (NSResponder *) firstResponder;
- (NSEvent *) currentEvent;
- (NSEvent *) nextEventMatchingMask:(unsigned int)mask;
- (NSEvent *) nextEventMatchingMask:(unsigned int)mask
						  untilDate:(NSDate *)expiration
						  inMode:(NSString *)mode
						  dequeue:(BOOL)deqFlag;
- (void) keyDown:(NSEvent *)event;
- (void) sendEvent:(NSEvent *)event;
- (void) postEvent:(NSEvent *)event atStart:(BOOL)flag;
- (void) discardEventsMatchingMask:(unsigned int)mask beforeEvent:(NSEvent *)e;
- (BOOL) tryToPerform:(SEL)anAction with:(id)anObject;
- (BOOL) worksWhenModal;

- (BOOL) isExcludedFromWindowsMenu;							// Windows menu
- (void) setExcludedFromWindowsMenu:(BOOL)flag;

- (id) validRequestorForSendType:(NSString *)sendType		// Services
					  returnType:(NSString *)returnType;

+ (void) removeFrameUsingName:(NSString *)name;
- (NSString *) frameAutosaveName;							// Save frame
- (NSString *) stringWithSavedFrame;
- (void) saveFrameUsingName:(NSString *)name;
- (void) setFrameFromString:(NSString *)string;
- (BOOL) setFrameAutosaveName:(NSString *)name;
- (BOOL) setFrameUsingName:(NSString *)name;

- (id) delegate;
- (void) setDelegate:anObject;

- (void) cacheImageInRect:(NSRect)aRect;
- (void) restoreCachedImage;
- (void) discardCachedImage;

@end


@interface NSObject  (NSWindowDelegate)						// Implemented by a
															// window delegate
- (BOOL) windowShouldClose:(id)sender;
- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize;
- (id) windowWillReturnUndoManager:(NSWindow *)sender;
- (id) windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client;

@end


@interface NSObject  (NSWindowNotifications)

- (void) windowDidBecomeKey:(NSNotification *)n;
- (void) windowDidBecomeMain:(NSNotification *)n;
- (void) windowDidChangeScreen:(NSNotification *)n;
- (void) windowDidDeminiaturize:(NSNotification *)n;
- (void) windowDidExpose:(NSNotification *)n;
- (void) windowDidMiniaturize:(NSNotification *)n;
- (void) windowDidMove:(NSNotification *)n;
- (void) windowDidResignKey:(NSNotification *)n;
- (void) windowDidResignMain:(NSNotification *)n;
- (void) windowDidResize:(NSNotification *)n;
- (void) windowDidUpdate:(NSNotification *)n;
- (void) windowWillClose:(NSNotification *)n;
- (void) windowWillMiniaturize:(NSNotification *)n;
- (void) windowWillMove:(NSNotification *)n;

@end


@interface NSWindow  (KeyViewLoop)

- (NSView *) initialFirstResponder;
- (void) setInitialFirstResponder:(NSView *)aView;
- (void) selectKeyViewFollowingView:(NSView *)aView;
- (void) selectKeyViewPrecedingView:(NSView *)aView;
- (void) selectNextKeyView:(id)sender;
- (void) selectPreviousKeyView:(id)sender;

@end


@interface NSWindow  (DragAndDrop)

- (void) dragImage:(NSImage *)anImage						// Drag and Drop
				at:(NSPoint)baseLocation 
				offset:(NSSize)initialOffset
				event:(NSEvent *)event
				pasteboard:(NSPasteboard *)pboard
				source:sourceObject
				slideBack:(BOOL)slideFlag;
- (void) registerForDraggedTypes:(NSArray *)newTypes;
- (void) unregisterDraggedTypes;

@end


@interface NSWindow  (WindowBackend)

- (void) _initWindowBackend;

- (void) _setTitle;

- (void) _orderFront;
- (void) _orderOut:(BOOL)fullRemoval;
- (void) orderBack:(id)sender;

- (void) _becomeTransient;
- (void) _becomeOwnerOfTransients;

- (void) _miniaturize;
- (void) _enableNotifications:(BOOL)enabled;
- (void) _needsFlush;

- (void) _setFrame:(NSRect)rect withHint:(int)hint;
- (void) _setFrameTopLeftPoint:(NSPoint)p;

- (NSPoint) xConvertBaseToScreen:(NSPoint)basePoint;
- (NSPoint) xConvertScreenToBase:(NSPoint)screenPoint;

- (NSDictionary *) deviceDescription;
- (void) print:(id)sender;

@end

extern NSString *NSWindowDidBecomeKeyNotification;			// Notifications
extern NSString *NSWindowDidBecomeMainNotification;
extern NSString *NSWindowDidChangeScreenNotification;
extern NSString *NSWindowDidDeminiaturizeNotification;
extern NSString *NSWindowDidExposeNotification;
extern NSString *NSWindowDidMiniaturizeNotification;
extern NSString *NSWindowDidMoveNotification;
extern NSString *NSWindowDidResignKeyNotification;
extern NSString *NSWindowDidResignMainNotification;
extern NSString *NSWindowDidResizeNotification;
extern NSString *NSWindowDidUpdateNotification;
extern NSString *NSWindowWillCloseNotification;
extern NSString *NSWindowWillMiniaturizeNotification;
extern NSString *NSWindowWillMoveNotification;


/* ****************************************************************************

	NSWindowController objects manage a window, usually loaded from a NIB/mib
	

** ***************************************************************************/

@interface NSWindowController : NSResponder  <NSCoding>
{
    NSWindow *_window;
    NSDocument *_document;

    struct __wcFlags {
		unsigned int shouldCloseDocument:1;
		unsigned int nibIsLoaded:1;
		unsigned int reserved:6;
    } _wc;
}

- (id) initWithWindowNibName:(NSString *)windowNibName owner:(id)owner;
- (id) initWithWindowNibName:(NSString *)windowNibName;

- (id) initWithWindow:(NSWindow *)window;

- (void) setWindow:(NSWindow *)window;
- (NSWindow *) window;

- (id) document;
- (void) setDocument:(NSDocument *)document;
- (void) setDocumentEdited:(BOOL)flag;

- (id) showWindow:(id)sender;

- (void) close;
- (void) setShouldCloseDocument:(BOOL)flag;
- (BOOL) shouldCloseDocument;
- (BOOL) isWindowLoaded;

//- (void) windowWillLoad;
//- (void) windowDidLoad;

@end

#endif /* _mGSTEP_H_NSWindow */
