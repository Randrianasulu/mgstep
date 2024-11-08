/*
   NSSlider.m

   Slider control and its Cell

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: 	August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSEvent.h>
#include <AppKit/NSSlider.h>
#include <AppKit/NSSliderCell.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSApplication.h>


// Class variables
static Class __sliderCellClass = Nil;


/* ****************************************************************************

	NSSliderCell

** ***************************************************************************/

@implementation NSSliderCell

+ (BOOL) prefersTrackingUntilMouseUp			{ return YES; }

- (id) init
{
	if ((self = [self initImageCell:nil]))
		{
		_altIncrementValue = -1;
		_minValue = 0;
		_maxValue = 1;
		_floatValue = 0;
		[self setBordered:YES];
		}

	return self;
}

- (void) setFloatValue:(float)aFloat
{
	if (aFloat < _minValue)
		_floatValue = _minValue;
	else 
		_floatValue = (aFloat > _maxValue) ? _maxValue : aFloat;
}

- (void) drawBarInside:(NSRect)rect flipped:(BOOL)flipped
{														// not per spec FIX ME
	[[NSColor lightGrayColor] set];
	NSRectFill(rect);									// background

	if (_numberOfTickMarks)								// draw ticks
		{
		if (_sc.tickMarkPos != NSTickMarkAbove)
			{
			int i = _numberOfTickMarks;
			float inc = _trackRect.size.width / _numberOfTickMarks;
			NSRect dr = rect;
			
			dr.origin.x += inc;
			dr.size.width = 2;
			while (i--)
				{
				NSDrawButton (dr, dr);
				dr.origin.x += inc;
				}
			}
		}

	if (!_c.bezeled)
		{
		rect = NSInsetRect(rect, 5, 5);
		if (rect.size.width > rect.size.height)
			rect.size.height = 5;
		else
			rect.size.width = 5;
		NSDrawGrayBezel(rect, rect);					// draw bar slide
		}
}

- (NSRect) knobRectFlipped:(BOOL)flipped
{
	NSImage *image = [self image];
	NSSize size;
	NSPoint origin;
	float floatValue;

	if (_sc.isVertical && flipped)
		_floatValue = _maxValue + _minValue - _floatValue;
	
	floatValue = (_floatValue - _minValue) / (_maxValue - _minValue);
	size = [image size];
	
	if (_sc.isVertical)
		{
		origin.x = (_c.bezeled) ? 2 : 1;
		origin.y = ((_trackRect.size.height - size.height) * floatValue);
		if (_c.bezeled)
			origin.y += 2;
		}
	else 
		{
		origin.x = ((_trackRect.size.width - size.width) * floatValue);
		origin.y = 2;
		if (_c.bezeled)
			origin.x += 2;
		}
	
	return NSMakeRect (origin.x, origin.y, size.width, size.height);  
}

- (void) drawKnob
{
	[self drawKnob:[self knobRectFlipped:[_controlView isFlipped]]];
}

- (void) drawKnob:(NSRect)knobRect
{
	[super drawInteriorWithFrame:knobRect inView:_controlView];
}

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	BOOL vertical = (cellFrame.size.height > cellFrame.size.width);

	if (_sc.sliderType == NSCircularSlider)
		NSLog(@"FIX ME NSCircularSlider");

	if (vertical != _sc.isVertical || (!_sc.verticalSet))
		{
		NSImage *image;

		if (!_c.bezeled)
			image = [NSImage imageNamed: @"slider"];
		else
			image = (vertical) ? [NSImage imageNamed: @"sliderVert"]
							   : [NSImage imageNamed: @"sliderHoriz"];
		_sc.verticalSet = 1;
		[self setImage:image];

		if (_c.bezeled)
			{
			NSSize size;

			if (vertical) 
				size = NSMakeSize (cellFrame.size.width, [image size].height);
			else 
				size = NSMakeSize ([image size].width, cellFrame.size.height);
			[image setSize:size];
		}	}

	_sc.isVertical = vertical;
	_trackRect = cellFrame;
	
	[self drawBarInside:cellFrame flipped:[controlView isFlipped]];
	[self drawKnob];
}

- (float) knobThickness
{
	NSSize size = [[self image] size];

	return _sc.isVertical ? size.height : size.width;
}

- (void) setAltIncrementValue:(double)increment
{
	_altIncrementValue = increment;
}

- (void) setMinValue:(double)aDouble
{
	_minValue = aDouble;
	if (_floatValue < _minValue)
		_floatValue = _minValue;
}

- (void) setMaxValue:(double)aDouble
{
	_maxValue = aDouble;
	if (_floatValue > _maxValue)
    	_floatValue = _maxValue;
}

- (NSInteger) isVertical						{ return _sc.isVertical; }
- (NSSliderType) sliderType						{ return _sc.sliderType; }
- (void) setSliderType:(NSSliderType)t			{ _sc.sliderType = t; }
- (double) altIncrementValue					{ return _altIncrementValue; }
- (NSRect) trackRect							{ return _trackRect; }
- (double) minValue								{ return _minValue; }
- (double) maxValue								{ return _maxValue; }
- (double) doubleValue							{ return _floatValue; }
- (float) floatValue							{ return _floatValue; }
- (NSTickMarkPosition) tickMarkPosition			{ return _sc.tickMarkPos; }
- (void) setTickMarkPosition:(NSTickMarkPosition)p { _sc.tickMarkPos = p; }

- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	[decoder decodeValuesOfObjCTypes:"ffff", &_minValue, &_maxValue, 
										&_floatValue, &_altIncrementValue];
	return self;
}

- (void) encodeWithCoder:(NSCoder*)coder
{
	[coder encodeValuesOfObjCTypes:"ffff", _minValue, _maxValue, 
									_floatValue, _altIncrementValue];
}

@end  /* NSSliderCell */

/* ****************************************************************************

	NSSlider

** ***************************************************************************/

@implementation NSSlider

+ (void) initialize
{
	__sliderCellClass = [NSSliderCell class];
}

+ (void) setCellClass:(Class)class			{ __sliderCellClass = class; }
+ (Class) cellClass							{ return __sliderCellClass; }

- (NSInteger) isVertical					{ return [_cell isVertical]; }
- (float) knobThickness						{ return [_cell knobThickness]; }
- (double) maxValue							{ return [_cell maxValue]; }
- (double) minValue							{ return [_cell minValue]; }
- (void) setMaxValue:(double)aDouble		{ [_cell setMaxValue:aDouble]; }
- (void) setMinValue:(double)aDouble		{ [_cell setMinValue:aDouble]; }
- (BOOL) acceptsFirstMouse:(NSEvent*)event	{ return YES; }

- (void) drawRect:(NSRect)rect	
{ 
	[_cell drawWithFrame:rect inView:self];
}

- (float) _floatValueForMousePoint:(NSPoint)point knobRect:(NSRect)knobRect
{
	NSRect slotRect = [_cell trackRect];
	BOOL isVertical = [_cell isVertical];
	float minValue = [_cell minValue];
	float maxValue = [_cell maxValue];
	float floatValue = 0;
	float position;
										// Adjust the point to lie inside the 
	if (isVertical) 					// knob slot. We don't have to worry
		{								// whether the view is flipped or not.
		if (point.y < slotRect.origin.y + knobRect.size.height / 2)
			position = slotRect.origin.y + knobRect.size.height / 2;
    	else 
			if (point.y <= (position = NSMaxY(slotRect) -NSHeight(knobRect)/2))
      			position = point.y;
													// Compute the float value 
    	floatValue = (position - (slotRect.origin.y + knobRect.size.height/2))
		  				/ (slotRect.size.height - knobRect.size.height);
   		if (_v.flipped)
      		floatValue = 1 - floatValue;
  		}
	else 											// Adjust the point to lie
		{						 					// inside the knob slot 
		if (point.x < slotRect.origin.x + knobRect.size.width / 2)
			position = slotRect.origin.x + knobRect.size.width / 2;
		else 
			if (point.x <= (position = NSMaxX(slotRect) - NSWidth(knobRect)/2))
      			position = point.x;
													// Compute the float value
						 							// given the knob size
    	floatValue = (position - (slotRect.origin.x + knobRect.size.width / 2))
		  				/ (slotRect.size.width - knobRect.size.width);
  		}

	return floatValue * (maxValue - minValue) + minValue;
}

- (void) trackKnob:(NSEvent*)event knobRect:(NSRect)knobRect
{
	NSEventType eventType = NSLeftMouseDown;
	NSPoint current, previous;
	BOOL isContinuous = [self isContinuous];
	float oldFloatValue = [_cell floatValue];
	NSDate *distantFuture = [NSDate distantFuture];
	id target = [_cell target];
	SEL action = [_cell action];

	[NSEvent startPeriodicEventsAfterDelay:0.05 withPeriod:0.05];

	while ((eventType = [event type]) != NSLeftMouseUp) 
		{
		if (eventType != NSPeriodic)
			current = [event locationInWindow];
		else
			{
			if (current.x != previous.x || current.y != previous.y) 
				{
				NSPoint p = [self convertPoint:current fromView:nil];
				float v = [self _floatValueForMousePoint:p knobRect:knobRect];

				previous = current;
				if (v != oldFloatValue) 
					{
					oldFloatValue = v;
					[_cell setFloatValue:v];
					[_cell drawWithFrame:_bounds inView:self];
					[_window flushWindow];
					if (isContinuous)
	  					[target performSelector:action withObject:self];
      				}
      			knobRect.origin = p;
			}	}

		event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
					   untilDate:distantFuture 
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
		}
									// If the control is not continuous send
	if (!isContinuous)				// the action at the end of the drag
		[target performSelector:action withObject:self];
	[NSEvent stopPeriodicEvents];
}

- (void) mouseDown:(NSEvent *)event
{
	NSPoint location = [self convertPoint:[event locationInWindow]fromView:nil];
	NSRect rect = [_cell knobRectFlipped:_v.flipped];

	[self lockFocus];
														// Mouse is not on the 
	if (![self mouse:location inRect:rect]) 			// knob, move knob to
		{												// the mouse position 
		float value = [self _floatValueForMousePoint:location knobRect:rect];
	
		[_cell setFloatValue:value];
		if ([self isContinuous])
			[[_cell target] performSelector:[_cell action] withObject:self];
		[_cell drawWithFrame:[self bounds] inView:self];
		[_window flushWindow];
		}
	
	[self trackKnob:event knobRect:rect];
	[self unlockFocus];
}

@end  /* NSSlider */
