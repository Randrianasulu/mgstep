/*
   NSScroller.h

   Scroller control

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: July 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSScroller
#define _mGSTEP_H_NSScroller

#include <AppKit/NSControl.h>

@class NSEvent;

typedef enum _NSScrollArrowPosition {
	NSScrollerArrowsMaxEnd,
	NSScrollerArrowsMinEnd,
	NSScrollerArrowsNone 
} NSScrollArrowPosition;

typedef enum _NSScrollerPart {
	NSScrollerNoPart = 0,
	NSScrollerDecrementPage,
	NSScrollerKnob,
	NSScrollerIncrementPage,
	NSScrollerDecrementLine,
	NSScrollerIncrementLine,
	NSScrollerKnobSlot
} NSScrollerPart;

typedef enum _NSScrollerUsablePart {
	NSNoScrollerParts = 0,
	NSOnlyScrollerArrows,
	NSAllScrollerParts  
} NSUsableScrollerParts;

typedef enum _NSScrollerArrow {
	NSScrollerIncrementArrow,
	NSScrollerDecrementArrow
} NSScrollerArrow;

typedef enum _NSScrollerStyle {
	NSScrollerStyleLegacy = 0,
	NSScrollerStyleOverlay
} NSScrollerStyle;

typedef enum _NSScrollerKnobStyle {
	NSScrollerKnobStyleDefault = 0,
	NSScrollerKnobStyleDark,
	NSScrollerKnobStyleLight
} NSScrollerKnobStyle;


@interface NSScroller : NSControl  <NSCoding>
{
	id _target;
	SEL _action;
	float _floatValue;
	float _knobProportion;
	NSScrollerPart _hitPart;

	struct __ScrollerFlags {
		NSScrollerStyle       style:1;
		NSScrollerKnobStyle   knobStyle:2;
		NSScrollArrowPosition arrowsPosition:2;
		NSUsableScrollerParts usableParts:2;
        unsigned int hideOverlay:1;
		unsigned int isHorizontal:1;
		unsigned int isEnabled:1;
		unsigned int reserved:22;
	} _sl;
}

+ (NSScrollerStyle) preferredScrollerStyle;					// OSX >= 10.7

- (NSScrollerStyle) scrollerStyle;
- (void) setScrollerStyle:(NSScrollerStyle)style;
- (void) setKnobStyle:(NSScrollerKnobStyle)style;
- (NSScrollerKnobStyle) knobStyle;

+ (float) scrollerWidth;

- (void) checkSpaceForParts;
- (void) setArrowsPosition:(NSScrollArrowPosition)where;
- (NSScrollArrowPosition) arrowsPosition;
- (NSUsableScrollerParts) usableParts;
- (NSRect) rectForPart:(NSScrollerPart)partCode;

- (float) knobProportion;									// Attributes
- (void) setKnobProportion:(float)proportion;
- (void) setFloatValue:(float)aFloat knobProportion:(float)ratio;
- (void) setEnabled:(BOOL)flag;

- (void) drawKnobSlot;										// Displaying
- (void) drawKnob;
- (void) drawParts;
- (void) drawArrow:(NSScrollerArrow)whichButton highlight:(BOOL)flag;

- (NSScrollerPart) hitPart;									// Handling Events
- (NSScrollerPart) testPart:(NSPoint)thePoint;
- (void) trackKnob:(NSEvent *)event;
- (void) trackScrollButtons:(NSEvent *)event;

@end

#endif /* _mGSTEP_H_NSScroller */
