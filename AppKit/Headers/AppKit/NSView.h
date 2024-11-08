/*
   NSView.h

   Drawing and event handling class.

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSView
#define _mGSTEP_H_NSView

#include <AppKit/NSWindow.h>
#include <AppKit/NSResponder.h>

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSData;
@class NSMutableSet;
@class NSPasteboard;
@class NSView;
@class NSClipView;
@class NSImage;
@class NSCursor;
@class NSAffineTransform;
@class CALayer;

typedef int NSTrackingRectTag;

typedef enum _NSBorderType {					// constants representing the
	NSNoBorder     = 0,							// four types of borders that
	NSLineBorder   = 1,							// can appear around an NSView
	NSBezelBorder  = 2,
	NSGrooveBorder = 3
} NSBorderType;

							// constants that determine how a view's dimensions
enum {						// are resized when its superview is resized
	NSViewNotSizable	= 0,		// view does not resize with its superview
	NSViewMinXMargin	= 1,		// left margin between views can stretch
	NSViewWidthSizable	= 2,		// view's width can stretch
	NSViewMaxXMargin	= 4,		// right margin between views can stretch
	NSViewMinYMargin	= 8,		// bottom margin between views can stretch
	NSViewHeightSizable	= 16,		// view's height can stretch
	NSViewMaxYMargin	= 32 		// top margin can stretch
};


@interface NSView : NSResponder  <NSCoding> 
{
	NSRect _frame;
	NSRect _bounds;
	NSRect _invalid;
	NSAffineTransform *_frameMatrix;
	NSAffineTransform *_boundsMatrix;
	
	NSView *_nextKeyView;
	NSView *_superview;
	NSMutableArray *_subviews;
	NSWindow *_window;
    NSInteger _gState;
    NSMutableSet *_dragTypes;
	
	CALayer *_layer;

    struct __ViewFlags {
		unsigned int isRotatedFromBase:1;
		unsigned int isRotatedOrScaledFromBase:1;
		unsigned int needsDisplay:1;
		unsigned int postFrameChange:1;
		unsigned int postBoundsChange:1;
		unsigned int autoSizeSubviews:1;
		unsigned int flipped:1;
		unsigned int clipped:1;
		unsigned int isClip:1;
		unsigned int hasSubviews:1;
		unsigned int autoresizingMask:6;
		unsigned int hasToolTip:1;
		unsigned int interfaceStyle:1;
		unsigned int inLiveResize:1;
		unsigned int hidden:1;
		unsigned int gStateAllocd:1;
		unsigned int wantsLayer:1;
		unsigned int reserved:10;
	} _v;
}

+ (NSView *) focusView;

- (id) initWithFrame:(NSRect)frameRect;

- (void) lockFocus;
- (void) unlockFocus;

- (void) addSubview:(NSView *)aView;						// NSView Hierarchy
- (void) addSubview:(NSView *)aView
		 positioned:(NSWindowOrderingMode)place
		 relativeTo:(NSView *)otherView;
- (void) replaceSubview:(NSView *)oldView with:(NSView *)newView;
- (void) sortSubviewsUsingFunction:(NSInteger (*)(id ,id ,void *))compare 
						   context:(void *)context;
- (NSMutableArray *) subviews;

- (NSView *) superview;
- (void) removeFromSuperview;
- (void) setSuperview:(NSView *)superview;
- (void) viewWillMoveToWindow:(NSWindow *)newWindow;
- (NSWindow *) window;

- (void) setHidden:(BOOL)flag;
- (void) viewDidHide;				// called when view or ancestor is hidden
- (BOOL) isHidden;
- (BOOL) isHiddenOrHasHiddenAncestor;
- (BOOL) isDescendantOf:(NSView *)aView;
- (NSView *) opaqueAncestor;
- (NSView *) ancestorSharedWithView:(NSView *)aView;

- (NSRect) bounds;											// Coordinates
- (NSRect) frame;
- (void) setFrame:(NSRect)frameRect;
- (void) setFrameOrigin:(NSPoint)newOrigin;
- (void) setFrameRotation:(float)angle;
- (void) setFrameSize:(NSSize)newSize;
- (void) rotateByAngle:(float)angle;
- (float) frameRotation;
- (float) boundsRotation;
- (BOOL) isRotatedFromBase;
- (BOOL) isRotatedOrScaledFromBase;
- (BOOL) isFlipped;
- (void) scaleUnitSquareToSize:(NSSize)newSize;
- (void) setBounds:(NSRect)aRect;
- (void) setBoundsOrigin:(NSPoint)newOrigin;
- (void) setBoundsRotation:(float)angle;
- (void) setBoundsSize:(NSSize)newSize;
- (void) translateOriginToPoint:(NSPoint)point;

- (NSRect) centerScanRect:(NSRect)r;						// Coord conversion
- (NSPoint) convertPoint:(NSPoint)p fromView:(NSView *)v;
- (NSPoint) convertPoint:(NSPoint)p toView:(NSView *)v;
- (NSRect) convertRect:(NSRect)r fromView:(NSView *)v;
- (NSRect) convertRect:(NSRect)r toView:(NSView *)v;
- (NSSize) convertSize:(NSSize)s fromView:(NSView *)v;
- (NSSize) convertSize:(NSSize)s toView:(NSView *)v;

- (void) setPostsFrameChangedNotifications:(BOOL)flag;		// Notify Ancestors
- (BOOL) postsFrameChangedNotifications;
- (void) setPostsBoundsChangedNotifications:(BOOL)flag;
- (BOOL) postsBoundsChangedNotifications;

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize;			// Resize Subviews
- (void) setAutoresizesSubviews:(BOOL)flag;
- (BOOL) autoresizesSubviews;
- (void) setAutoresizingMask:(unsigned int)mask;
- (unsigned int) autoresizingMask;
- (void) resizeWithOldSuperviewSize:(NSSize)oldSize;

- (void) display;											// Display view
- (void) displayRect:(NSRect)aRect;
- (void) displayRectIgnoringOpacity:(NSRect)aRect;
- (void) displayIfNeeded;
- (void) displayIfNeededInRect:(NSRect)aRect;
- (void) displayIfNeededInRectIgnoringOpacity:(NSRect)aRect;
- (void) displayIfNeededIgnoringOpacity;
- (void) drawRect:(NSRect)rect;
- (NSRect) visibleRect;
- (void) setNeedsDisplay:(BOOL)flag;
- (void) setNeedsDisplayInRect:(NSRect)invalidRect;
- (BOOL) needsDisplay;
- (BOOL) shouldDrawColor;
- (BOOL) isOpaque;
- (BOOL) canDraw;											

- (BOOL) autoscroll:(NSEvent *)event;						// Scrolling
- (BOOL) scrollRectToVisible:(NSRect)aRect;
- (void) reflectScrolledClipView:(NSClipView *)aClipView;
- (void) scrollClipView:(NSClipView *)aClipView toPoint:(NSPoint)aPoint;
- (void) scrollPoint:(NSPoint)aPoint;
- (void) scrollRect:(NSRect)aRect by:(NSSize)delta;
			// allow subclasses to constrain scroll, not called if scroll is
			// initiated by lower layer: scrollToPoint: or scrollRectToVisible:
- (NSRect) adjustScroll:(NSRect)proposed;

- (int) tag;												// Tag identity
- (id) viewWithTag:(int)aTag;

- (BOOL) acceptsFirstMouse:(NSEvent *)event;				// Allow click-thru
- (NSView *) hitTest:(NSPoint)aPoint;
- (BOOL) mouse:(NSPoint)aPoint inRect:(NSRect)aRect;
- (BOOL) performKeyEquivalent:(NSEvent *)event;
- (BOOL) shouldDelayWindowOrderingForEvent:(NSEvent *)anEvent;

- (void) discardCursorRects;								// Cursor rects
- (void) resetCursorRects;
- (void) addCursorRect:(NSRect)aRect cursor:(NSCursor *)anObject;
- (void) removeCursorRect:(NSRect)aRect cursor:(NSCursor *)anObject;

- (void) removeTrackingRect:(NSTrackingRectTag)tag;
- (NSTrackingRectTag) addTrackingRect:(NSRect)aRect
								owner:(id)anObject
								userData:(void *)data
								assumeInside:(BOOL)flag;

- (void) setToolTip:(NSString *)string;						// Tool tips
- (NSString*) toolTip;

- (void) viewWillStartLiveResize;
- (void) viewDidEndLiveResize;
- (BOOL) inLiveResize;

@end


@interface NSView (BackendMethods)

- (void) allocateGState;									// Graphics State
- (void) releaseGState;
- (void) renewGState;
- (void) setUpGState;
- (NSInteger) gState;

@end


@interface NSView (NSKeyboardUI)

- (void) setNextKeyView:(NSView *)next;
- (NSView *) nextKeyView;
- (NSView *) previousKeyView;
- (NSView *) nextValidKeyView;
- (NSView *) previousValidKeyView;

@end


@interface NSView (NSDrag)

- (BOOL) dragFile:(NSString *)filename						// Drag and Drop
		 fromRect:(NSRect)rect
		 slideBack:(BOOL)slideFlag
		 event:(NSEvent *)event;
- (void) dragImage:(NSImage *)anImage
				at:(NSPoint)viewLocation
				offset:(NSSize)initialOffset
				event:(NSEvent *)event
				pasteboard:(NSPasteboard *)pboard
				source:(id)sourceObject
				slideBack:(BOOL)slideFlag;
- (void) registerForDraggedTypes:(NSArray *)newTypes;
- (void) unregisterDraggedTypes;

@end


@interface NSView (NSPrinting)

- (void) print:(id)sender;
- (void) adjustPageHeightNew:(float *)newBottom				// Pagination
						 top:(float)oldTop
						 bottom:(float)oldBottom
						 limit:(float)bottomLimit;
- (void) adjustPageWidthNew:(float *)newRight
					   left:(float)oldLeft
					   right:(float)oldRight	 
					   limit:(float)rightLimit;
- (NSPoint) locationOfPrintRect:(NSRect)aRect;
- (NSRect) rectForPage:(int)page;
- (float) heightAdjustLimit;
- (float) widthAdjustLimit;
- (void) beginPage:(int)ordinalNum
			 label:(NSString *)aString
			 bBox:(NSRect)pageRect
			 fonts:(NSString *)fontNames;
- (void) drawPageBorderWithSize:(NSSize)borderSize;
- (void) drawSheetBorderWithSize:(NSSize)borderSize;
- (void) endPage;

@end


typedef enum _NSViewLayerContentsRedrawPolicy {
	NSViewLayerContentsRedrawNever             = 0,
	NSViewLayerContentsRedrawOnSetNeedsDisplay = 1,
	NSViewLayerContentsRedrawDuringViewResize  = 2,
	NSViewLayerContentsRedrawBeforeViewResize  = 3,
	NSViewLayerContentsRedrawCrossfade         = 4
} NSViewLayerContentsRedrawPolicy;

typedef enum _NSViewLayerContentsPlacement {
    NSViewLayerContentsPlacementScaleAxesIndependently    =  0,
    NSViewLayerContentsPlacementScaleProportionallyToFit  =  1,
    NSViewLayerContentsPlacementScaleProportionallyToFill =  2,
    NSViewLayerContentsPlacementCenter                    =  3,
    NSViewLayerContentsPlacementTop                       =  4,
    NSViewLayerContentsPlacementTopRight                  =  5,
    NSViewLayerContentsPlacementRight                     =  6,
    NSViewLayerContentsPlacementBottomRight               =  7,
    NSViewLayerContentsPlacementBottom                    =  8,
    NSViewLayerContentsPlacementBottomLeft                =  9,
    NSViewLayerContentsPlacementLeft                      = 10,
    NSViewLayerContentsPlacementTopLeft                   = 11
} NSViewLayerContentsPlacement;


@interface NSView (CALayer)						// FIX ME experimental

- (CALayer *) makeBackingLayer;

- (NSViewLayerContentsRedrawPolicy) layerContentsRedrawPolicy;
- (void) setLayerContentsRedrawPolicy:(NSViewLayerContentsRedrawPolicy)policy;

- (NSViewLayerContentsPlacement) layerContentsPlacement;
- (void) setLayerContentsPlacement:(NSViewLayerContentsPlacement)placement;

- (void) setWantsLayer:(BOOL)flag;
- (BOOL) wantsLayer;
- (BOOL) wantsUpdateLayer;						// YES to draw with -drawRect:
												// or NO for -updateLayer
- (void) setLayer:(CALayer *)layer;
- (CALayer *) layer;

- (void) updateLayer;

- (void) setCanDrawSubviewsIntoLayer:(BOOL)flag;
- (BOOL) canDrawSubviewsIntoLayer;

- (void) setAlphaValue:(CGFloat)alpha;
- (CGFloat) alphaValue;

@end


@interface NSView (PrivateMethods)							// mGSTEP extension

- (NSAffineTransform *) _matrixFromSubview:(NSView*)subview 
							   toSuperview:(NSView*)_superview;
@end

extern NSString *NSViewFrameDidChangeNotification;			// Notifications
extern NSString *NSViewBoundsDidChangeNotification;
extern NSString *NSViewFocusDidChangeNotification;

#endif /* _mGSTEP_H_NSView */
