/*
   NSTabView.h

   Tabbed view

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:	Michael Hanni <mhanni@sprintmail.com>
   Date:	June 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTabView
#define _mGSTEP_H_NSTabView
 
#include <AppKit/NSView.h>

@class NSColor;
@class NSImage;
@class NSFont;
@class NSTabViewItem;


typedef enum {
	NSTopTabsBezelBorder, 
	NSBottomTabsBezelBorder, 
	NSNoTabsBezelBorder,
	NSNoTabsLineBorder,
	NSNoTabsNoBorder
} NSTabViewType;


@interface NSTabView : NSView  <NSCoding>
{
	NSMutableArray *_tabViewItems;
	NSFont *_font;
	NSTabViewType _tabViewType;
	NSTabViewItem *_selectedTabViewItem;
	BOOL _drawsBackground;
	BOOL _allowTruncatedLabels;
	id _delegate;
}

- (void) addTabViewItem:(NSTabViewItem *)tabViewItem;
- (void) insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(NSInteger)ix;
- (void) removeTabViewItem:(NSTabViewItem *)tabViewItem;
- (NSInteger) indexOfTabViewItem:(NSTabViewItem *)tabViewItem;
- (NSInteger) indexOfTabViewItemWithIdentifier:(id)identifier;
- (NSInteger) numberOfTabViewItems;

- (NSTabViewItem *) selectedTabViewItem;
- (NSTabViewItem *) tabViewItemAtIndex:(NSInteger)index;
- (NSArray *) tabViewItems;

- (void) selectFirstTabViewItem:(id)sender;
- (void) selectLastTabViewItem:(id)sender;
- (void) selectNextTabViewItem:(id)sender;
- (void) selectPreviousTabViewItem:(id)sender;
- (void) selectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void) selectTabViewItemWithIdentifier:(id)identifier;
- (void) takeSelectedTabViewItemFromSender:(id)sender;
- (void) selectTabViewItemAtIndex:(NSInteger)index;

- (void) setFont:(NSFont *)font;
- (NSFont *) font;

- (void) setTabViewType:(NSTabViewType)tabViewType;
- (NSTabViewType) tabViewType;

- (void) setDrawsBackground:(BOOL)flag;
- (BOOL) drawsBackground;

- (void) setAllowsTruncatedLabels:(BOOL)allowTruncatedLabels;
- (BOOL) allowsTruncatedLabels;

- (void) setDelegate:(id)anObject;
- (id) delegate;

- (NSSize) minimumSize;
- (NSRect) contentRect;

- (NSTabViewItem *) tabViewItemAtPoint:(NSPoint)point;

@end


@interface NSObject (NSTabViewDelegate)

- (BOOL) tabView:(NSTabView *)tv shouldSelectTabViewItem:(NSTabViewItem *)ti;
- (void) tabView:(NSTabView *)tv willSelectTabViewItem:(NSTabViewItem *)ti;
- (void) tabView:(NSTabView *)tv didSelectTabViewItem:(NSTabViewItem *)ti;
- (void) tabViewDidChangeNumberOfTabViewItems:(NSTabView *)ti;

@end

/* ****************************************************************************

	NSTabViewItem

** ***************************************************************************/

typedef enum {
	NSSelectedTab = 0,
	NSBackgroundTab,
	NSPressedTab
} NSTabState;


@interface NSTabViewItem : NSObject  <NSCoding>
{
	id _identifier;
	NSString *_label;
	NSView *_view;
	NSColor *_color;
	NSTabState _tabState;
	NSTabView *_tabView;

	NSRect item_rect;			// cached
	NSImage *item_image;
}

- (id) initWithIdentifier:(id)identifier;

- (id) identifier;
- (void) setIdentifier:(id)identifier;
- (void) setLabel:(NSString *)label;
- (NSString *) label;
- (NSSize) sizeOfLabel:(BOOL)shouldTruncateLabel;

- (void) setView:(NSView *)view;
- (NSView *) view;

- (void) setColor:(NSColor *)color;
- (NSColor *) color;

- (NSTabState) tabState;
- (NSTabView *) tabView;

- (void) setInitialFirstResponder:(NSView *)view;
- (id) initialFirstResponder;

- (void) drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect;

//- (NSString *) toolTip;
//- (void) setToolTip:(NSString *)toolTip;

@end


@interface NSTabViewItem (NotOSX)

- (NSRect) _tabRect;
- (NSImage *) _image;
- (void) _setImage:(NSImage *)image;
- (void) _setTabState:(NSTabState)tabState;
- (void) _setTabView:(NSTabView *)tabView;

@end

#endif /* _mGSTEP_H_NSTabView */
