/*
   NSSlider.h

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: September 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSlider
#define _mGSTEP_H_NSSlider

#include <AppKit/NSControl.h>
#include <AppKit/NSSliderCell.h>

@class NSEvent;


@interface NSSlider : NSControl

- (NSInteger) isVertical;
- (float) knobThickness;
- (double) maxValue;
- (double) minValue;
- (void) setMaxValue:(double)aDouble;
- (void) setMinValue:(double)aDouble;
- (BOOL) acceptsFirstMouse:(NSEvent *)event;

@end


@interface NSSlider  (NotImplemented)

- (NSTickMarkPosition) tickMarkPosition;
- (void) setTickMarkPosition:(NSTickMarkPosition)position;
- (void) setNumberOfTickMarks:(NSInteger)count;
- (NSInteger) numberOfTickMarks;

@end

#endif /* _mGSTEP_H_NSSlider */
