/*
   NSLevelIndicator.h

   Copyright (c) 2005 DSITRI.

   Created by Dr. H. Nikolaus Schaller on Sat Jan 07 2006.

   Author:	Fabian Spillner <fabian.spillner@gmail.com>
   Date:	13. November 2007 - aligned with 10.5
 
   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSLevelIndicator
#define _mGSTEP_H_NSLevelIndicator

#include "AppKit/NSControl.h"
#include "AppKit/NSActionCell.h"
#include "AppKit/NSSliderCell.h"

@class NSImage;

typedef enum _NSLevelIndicatorStyle {
    NSRelevancyLevelIndicatorStyle          = 0,
    NSContinuousCapacityLevelIndicatorStyle = 1,
    NSDiscreteCapacityLevelIndicatorStyle   = 2,
    NSRatingLevelIndicatorStyle             = 3
} NSLevelIndicatorStyle;



@interface NSLevelIndicatorCell : NSActionCell
{
	NSImage *_image;
	double _value;
	double _minValue;
	double _warningValue;	// switching to yellow
	double _criticalValue;	// switching to red
	double _maxValue;
	int _numberOfMajorTickMarks;
	int _numberOfTickMarks;
	NSTickMarkPosition _tickMarkPosition;

	struct __LevelCellFlags {
		unsigned int isVertical:1;
		unsigned int verticalSet:1;
        unsigned int tickMarkPos:1;
		NSLevelIndicatorStyle style:2;
		unsigned int reserved:3;
	} _lc;
}

- (double) criticalValue;
- (id) initWithLevelIndicatorStyle:(NSLevelIndicatorStyle) style;
- (NSLevelIndicatorStyle) levelIndicatorStyle;
- (double) maxValue;
- (double) minValue;
- (NSInteger) numberOfMajorTickMarks;
- (NSInteger) numberOfTickMarks;
- (NSRect) rectOfTickMarkAtIndex:(NSInteger) index;
- (void) setCriticalValue:(double) val;
- (void) setImage:(NSImage *) image;
- (void) setLevelIndicatorStyle:(NSLevelIndicatorStyle) style;
- (void) setMaxValue:(double) val;
- (void) setMinValue:(double) val;
- (void) setNumberOfMajorTickMarks:(NSInteger) count;
- (void) setNumberOfTickMarks:(NSInteger) count;
- (void) setTickMarkPosition:(NSTickMarkPosition) pos;
- (void) setWarningValue:(double) val;
- (NSTickMarkPosition) tickMarkPosition;
- (double) tickMarkValueAtIndex:(NSInteger)index;
- (double) warningValue;

@end


@interface NSLevelIndicator : NSControl

- (double) criticalValue;
- (double) maxValue;
- (double) minValue;
- (NSInteger) numberOfMajorTickMarks;
- (NSInteger) numberOfTickMarks;
- (NSRect) rectOfTickMarkAtIndex:(NSInteger) index;
- (void) setCriticalValue:(double) val;
- (void) setMaxValue:(double) val;
- (void) setMinValue:(double) val;
- (void) setNumberOfMajorTickMarks:(NSInteger) count;
- (void) setNumberOfTickMarks:(NSInteger) count;
- (void) setTickMarkPosition:(NSTickMarkPosition) pos;
- (void) setWarningValue:(double) val;
- (NSTickMarkPosition) tickMarkPosition;
- (double) tickMarkValueAtIndex:(NSInteger) index;
- (double) warningValue;

@end

#endif /* _mGSTEP_H_NSLevelIndicator */
