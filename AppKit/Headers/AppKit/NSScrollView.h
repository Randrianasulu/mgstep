/*
   NSScrollView.h

   View which scrolls another via a clip view.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: July 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSScrollView
#define _mGSTEP_H_NSScrollView

#include <AppKit/NSView.h>
#include <AppKit/NSScroller.h>

@class NSClipView;
@class NSRulerView;
@class NSColor;
@class NSCursor;

typedef enum _NSScrollElasticity {
	NSScrollElasticityAutomatic = 0,
	NSScrollElasticityNone,
	NSScrollElasticityAllowed
} NSScrollElasticity;


@interface NSScrollView : NSView
{
	NSClipView *_contentView;
	NSClipView *_headerClipView;
	NSScroller *_horizScroller;
	NSScroller *_vertScroller;
	float _lineScroll;
	float _pageScroll;
	NSRulerView *_horizRuler;
	NSRulerView *_vertRuler;

    struct __scrollViewFlags {
		NSBorderType       borderType:2;
		NSScrollElasticity hElasticity:2;
		NSScrollElasticity vElasticity:2;
		unsigned int hasHorizScroller:1;
		unsigned int hasVertScroller:1;
		unsigned int hasHorizRuler:1;
		unsigned int hasVertRuler:1;
		unsigned int scrollsDynamically:1;
		unsigned int rulersVisible:1;
		unsigned int knobMoved:1;
		unsigned int vertHeader:1;
		unsigned int leftSideScroller:1;
		unsigned int autohidesScrollers:1;
		unsigned int reserved:16;
	} _sv;
}

+ (NSSize) contentSizeForFrameSize:(NSSize)frameSize		// Layout
			 hasHorizontalScroller:(BOOL)hFlag
			 hasVerticalScroller:(BOOL)vFlag
			 borderType:(NSBorderType)borderType;
+ (NSSize) frameSizeForContentSize:(NSSize)contentSize
			 hasHorizontalScroller:(BOOL)hFlag
			 hasVerticalScroller:(BOOL)vFlag
			 borderType:(NSBorderType)borderType;

- (NSSize) contentSize;
- (NSRect) documentVisibleRect;
- (void) tile;

- (void) setBackgroundColor:(NSColor*)aColor;				// graphic attribs
- (NSColor*) backgroundColor;
- (BOOL) drawsBackground;
- (void) setDrawsBackground:(BOOL)flag;
- (void) setBorderType:(NSBorderType)borderType;
- (NSBorderType) borderType;

- (NSView*) contentView;
- (void) setContentView:(NSClipView*)aView;					// scrolled views
- (void) setDocumentView:(NSView*)aView;
- (id) documentView;
- (void) setDocumentCursor:(NSCursor*)aCursor;
- (NSCursor*) documentCursor;

- (void) setHorizontalScroller:(NSScroller*)aScroller;		// scrollers
- (void) setVerticalScroller:(NSScroller*)aScroller;
- (NSScroller*) horizontalScroller;
- (NSScroller*) verticalScroller;

- (void) setHasHorizontalScroller:(BOOL)flag;
- (void) setHasVerticalScroller:(BOOL)flag;
- (BOOL) hasHorizontalScroller;
- (BOOL) hasVerticalScroller;

- (void) flashScrollers;

- (void) setKnobStyle:(NSScrollerKnobStyle)newKnobStyle;
- (void) setScrollerStyle:(NSScrollerStyle)newScrollerStyle;
- (NSScrollerStyle) scrollerStyle;
- (NSScrollerKnobStyle) knobStyle;

- (void) setVerticalScrollElasticity:(NSScrollElasticity)elasticity;
- (void) setHorizontalScrollElasticity:(NSScrollElasticity)elasticity;
- (NSScrollElasticity) horizontalScrollElasticity;
- (NSScrollElasticity) verticalScrollElasticity;

+ (void) setRulerViewClass:(Class)aClass;					// Rulers
+ (Class) rulerViewClass;

- (BOOL) rulersVisible;
- (BOOL) hasVerticalRuler;
- (BOOL) hasHorizontalRuler;
- (void) setRulersVisible:(BOOL)flag;
- (void) setHasVerticalRuler:(BOOL)flag;
- (void) setHasHorizontalRuler:(BOOL)flag;

- (void) setHorizontalRulerView:(NSRulerView*)aRulerView;
- (void) setVerticalRulerView:(NSRulerView*)aRulerView;
- (NSRulerView*) horizontalRulerView;
- (NSRulerView*) verticalRulerView;

- (BOOL) scrollsDynamically;
- (void) setScrollsDynamically:(BOOL)flag;
- (void) setLineScroll:(float)aFloat;						// scrolling
- (void) setPageScroll:(float)aFloat;
- (float) lineScroll;
- (float) pageScroll;

- (void) scrollWheel:(NSEvent *)event;

- (void) reflectScrolledClipView:(NSClipView*)aClipView;	// scroller updates

- (void) setAutohidesScrollers:(BOOL)flag;
- (BOOL) autohidesScrollers;

@end


@interface NSScrollView (NotImplemented)

- (void) setHorizontalLineScroll:(CGFloat)amount;
- (void) setHorizontalPageScroll:(CGFloat)amount;
- (void) setVerticalLineScroll:(CGFloat)amount;
- (void) setVerticalPageScroll:(CGFloat)amount;
- (CGFloat) horizontalLineScroll;
- (CGFloat) horizontalPageScroll;
- (CGFloat) verticalLineScroll;
- (CGFloat) verticalPageScroll;

@end

#endif /* _mGSTEP_H_NSScrollView */
