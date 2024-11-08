/*
   NSSplitView.h

   Allows multiple views to share a region in a window

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:  Robert Vasvari <vrobi@ddrummer.com>
   Date: Jul 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSplitView
#define _mGSTEP_H_NSSplitView

#import <AppKit/NSView.h>

@class NSImage;
@class NSColor;
@class NSNotification;

typedef enum _NSSplitViewDividerStyle {
	NSSplitViewDividerStyleThick = 1,
	NSSplitViewDividerStyleThin,
	NSSplitViewDividerStylePaneSplitter
} NSSplitViewDividerStyle;


@interface NSSplitView : NSView
{
	id _delegate;
	int _dividerThickness;
	BOOL _isVertical;
	NSColor *_dividerColor;
	NSSplitViewDividerStyle _dividerStyle;
}

- (id) delegate;
- (void) setDelegate:(id)anObject;
- (void) adjustSubviews;
- (void) drawDividerInRect:(NSRect)aRect;

- (void) setVertical:(BOOL)flag;	// Vert splitview has a vert split bar
- (BOOL) isVertical;

- (void) setDividerStyle:(NSSplitViewDividerStyle)style;
- (NSSplitViewDividerStyle) dividerStyle;

- (NSColor *) dividerColor;
- (void) seDividerColor:(NSColor *)aColor;

- (CGFloat) dividerThickness;

@end


@interface NSObject  (NSSplitViewDelegate)

- (void) splitView:(NSSplitView *)sender 
		 resizeSubviewsWithOldSize:(NSSize)oldSize;
- (void) splitView:(NSSplitView *)sender 
		 constrainMinCoordinate:(float *)min 
		 maxCoordinate:(float *)max 
		 ofSubviewAt:(int)offset;
- (void) splitViewWillResizeSubviews:(NSNotification *)notification;
- (void) splitViewDidResizeSubviews:(NSNotification *)notification;

@end

extern NSString *NSSplitViewDidResizeSubviewsNotification;	  // Notifications
extern NSString *NSSplitViewWillResizeSubviewsNotification;

#endif /* _mGSTEP_H_NSSplitView */
