/*
   NSSliderCell.h

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: September 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSliderCell
#define _mGSTEP_H_NSSliderCell

#include <AppKit/NSActionCell.h>


typedef enum {
	NSTickMarkBelow = 0,
	NSTickMarkAbove = 1,
	NSTickMarkLeft  = NSTickMarkAbove,
	NSTickMarkRight = NSTickMarkBelow
} NSTickMarkPosition;

typedef enum {
	NSLinearSlider   = 0,
	NSCircularSlider = 1
} NSSliderType;



@interface NSSliderCell : NSActionCell  <NSCoding>
{
	float _minValue;
	float _maxValue;
	float _floatValue;
	float _altIncrementValue;
	NSRect _trackRect;
    int _numberOfTickMarks;

	struct __SliderCellFlags {
		unsigned int isVertical:1;
		unsigned int verticalSet:1;
        unsigned int tickMarkPos:1;
		NSSliderType sliderType:2;
		unsigned int reserved:3;
	} _sc;
}

+ (BOOL) prefersTrackingUntilMouseUp;

- (NSTickMarkPosition) tickMarkPosition;
- (void) setTickMarkPosition:(NSTickMarkPosition)position;
- (void) setSliderType:(NSSliderType)type;
- (NSSliderType) sliderType;

- (double) altIncrementValue;
- (void) setAltIncrementValue:(double)increment;
- (NSRect) trackRect;

- (void) drawBarInside:(NSRect)rect flipped:(BOOL)flipped;
- (void) drawKnob;
- (void) drawKnob:(NSRect)knobRect;
- (NSRect) knobRectFlipped:(BOOL)flipped;

- (float) knobThickness;								// Graphic Attributes
- (NSInteger) isVertical;

- (double) minValue;									// Cell Limits
- (double) maxValue;
- (void) setMinValue:(double)aDouble;
- (void) setMaxValue:(double)aDouble;

@end

#endif /* _mGSTEP_H_NSSliderCell */
