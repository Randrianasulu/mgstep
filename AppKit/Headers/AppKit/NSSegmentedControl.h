/*
   NSSegmentedControl.h

   Segmented button control class

   Copyright (C) 2006-2017 Free Software Foundation, Inc.

   Author: H. Nikolaus Schaller <hns@computer.org>
   Date:   Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSegmentedControl
#define _mGSTEP_H_NSSegmentedControl

#include <Foundation/NSGeometry.h>
#include <AppKit/NSControl.h>
#include <AppKit/NSCell.h>
#include <AppKit/NSActionCell.h>
#include <AppKit/NSImageCell.h>

@class NSMutableArray;

typedef enum {
	NSSegmentStyleAutomatic      = 0,
	NSSegmentStyleRounded        = 1,
	NSSegmentStyleRoundRect      = 3,
	NSSegmentStyleTexturedSquare = 4,
	NSSegmentStyleSmallSquare    = 6
} NSSegmentStyle;


@interface NSSegmentedControl : NSControl

- (void) setSegmentCount:(NSInteger)count;
- (NSInteger) segmentCount;

- (void) setSelectedSegment:(NSInteger)selectedSegment;
- (NSInteger) selectedSegment;

- (BOOL) selectSegmentWithTag:(NSInteger)tag;

- (void) setWidth:(CGFloat)width forSegment:(NSInteger)segment;
- (CGFloat) widthForSegment:(NSInteger)segment;

- (void) setImage:(NSImage *)image forSegment:(NSInteger)segment;
- (NSImage *) imageForSegment:(NSInteger)segment;

//- (void) setImageScaling:(NSImageScaling)scaling forSegment:(NSInteger)segment;
//- (NSImageScaling) imageScalingForSegment:(NSInteger)segment;

- (void) setLabel:(NSString *)label forSegment:(NSInteger)segment;
- (void) setMenu:(NSMenu *)menu forSegment:(NSInteger)segment;
- (void) setSelected:(BOOL)selected forSegment:(NSInteger)segment;
- (void) setEnabled:(BOOL)enabled forSegment:(NSInteger)segment;

- (NSString *) labelForSegment:(NSInteger)segment;
- (NSMenu *) menuForSegment:(NSInteger)segment;
- (BOOL) isSelectedForSegment:(NSInteger)segment;
- (BOOL) isEnabledForSegment:(NSInteger)segment;

//- (void) setSegmentStyle:(NSSegmentStyle)segmentStyle;
//- (NSSegmentStyle) segmentStyle;

@end

/* ****************************************************************************

	NSSegmentedCell

** ***************************************************************************/

typedef enum {
	NSSegmentSwitchTrackingSelectOne = 0,  // only one button can be selected
	NSSegmentSwitchTrackingSelectAny = 1,  // any button can be selected
	NSSegmentSwitchTrackingMomentary = 2   // only selected while tracking
} NSSegmentSwitchTracking;


typedef enum {		// FIX ME move to NSCell and add support methods
	NSBackgroundStyleLight  = 0,
	NSBackgroundStyleDark   = 1,
	NSBackgroundStyleRaised = 2,
	NSBackgroundStyleLowered = 3,
} NSBackgroundStyle;


@interface NSSegmentedCell : NSActionCell
{
	NSMutableArray *_segments;
	int _trackedSegment;
	NSSegmentSwitchTracking _mode;

    NSInteger _selectedSegment;
    NSInteger _keySegment;
    NSRect _lastBounds;

    struct {
		unsigned int trackingMode:3;
		unsigned int trimmedLabels:1;
		unsigned int drawing:1;
		unsigned int reserved1:2;
		unsigned int recalcToolTips:1;
		unsigned int usesWindowsStyle:1;
		unsigned int dontShowSelectedAndPressedAppearance:1;
		unsigned int menuShouldBeUniquedAgainstMain:1;
		unsigned int style:8;
		unsigned int flatMinX:1;
		unsigned int flatMaxX:1;
		unsigned int reserved:11;
    } _seFlags;

    id _segmentTrackingInfo;
    id _menuUniquer;
    NSInteger _reserved3;
    NSInteger _reserved4;
}

- (void) setSegmentCount:(NSInteger)count;
- (NSInteger) segmentCount;
- (NSInteger) selectedSegment;				// active button
- (void) setSelectedSegment:(NSInteger)segment;

- (BOOL) selectSegmentWithTag:(NSInteger)tag;

- (void) makeNextSegmentKey;
- (void) makePreviousSegmentKey;

- (void) setTrackingMode:(NSSegmentSwitchTracking)trackingMode;
- (NSSegmentSwitchTracking) trackingMode;

- (void) setWidth:(CGFloat)width forSegment:(NSInteger)segment;
- (CGFloat) widthForSegment:(NSInteger)segment;	// width 0 == autosize to fit

- (void) setImage:(NSImage *)image forSegment:(NSInteger)segment;
- (NSImage *) imageForSegment:(NSInteger)segment;

//- (void)setImageScaling:(NSImageScaling)scaling forSegment:(NSInteger)segment;
//- (NSImageScaling)imageScalingForSegment:(NSInteger)segment;

- (void) setLabel:(NSString *)label forSegment:(NSInteger)segment;
- (void) setSelected:(BOOL)selected forSegment:(NSInteger)segment;
- (void) setEnabled:(BOOL)enabled forSegment:(NSInteger)segment;
- (void) setMenu:(NSMenu *)menu forSegment:(NSInteger)segment;

- (NSString *) labelForSegment:(NSInteger)segment;
- (BOOL) isSelectedForSegment:(NSInteger)segment;
- (BOOL) isEnabledForSegment:(NSInteger)segment;
- (NSMenu *) menuForSegment:(NSInteger)segment;

//- (void) setToolTip:(NSString *)toolTip forSegment:(NSInteger)segment;
//- (NSString *)toolTipForSegment:(NSInteger)segment;

- (void) setTag:(NSInteger)tag forSegment:(NSInteger)segment;
- (NSInteger) tagForSegment:(NSInteger)segment;

//- (void) setSegmentStyle:(NSSegmentStyle)segmentStyle;
//- (NSSegmentStyle) segmentStyle;

- (void) drawSegment:(NSInteger)segment		// custom drawing
			 inFrame:(NSRect)frame			// content area frame
			 withView:(NSView *)controlView;
@end


@interface NSSegmentedCell (NSSegmentBackgroundStyle)
/* FIX ME not implemented:  Describes the surface drawn onto in -[NSCell drawSegment:inFrame:withView:]. That method draws a segment interior, not the segment bezel.  This is both an override point and a useful method to call. A segmented cell that draws a custom bezel would override this to describe that surface. A cell that has custom segment drawing might query this method to help pick an image that looks good on the cell. Calling this method gives you some independence from changes in framework art style.
*/
- (NSBackgroundStyle) interiorBackgroundStyleForSegment:(NSInteger)segment;

@end


@interface NSSegmentItem : NSObject			// internal class
{
	NSString *_label;
	NSString *_tooltip;
	NSImage *_image;
	NSMenu *_menu;
	float _width;
	int _tag;
	BOOL _enabled;
	BOOL _highlighted;
	BOOL _selected;
}
- (NSString *) label;
- (NSString *) tooltip;
- (NSImage *) image;
- (NSMenu *) menu;
- (float) width;
- (float) autoWidth;
- (int) tag;
- (BOOL) enabled;
- (BOOL) highlighted;
- (BOOL) selected;
- (void) setLabel:(NSString *) label;
- (void) setTooltip:(NSString *) tooltip;
- (void) setImage:(NSImage *) image;
- (void) setMenu:(NSMenu *) menu;
- (void) setWidth:(float) width;		// 0.0 = autosize
- (void) setTag:(int) tag;
- (void) setEnabled:(BOOL) enabled;
- (void) setHighlighted:(BOOL) selected;
- (void) setSelected:(BOOL) selected;
@end

#endif /* _mGSTEP_H_NSSegmentedControl */
