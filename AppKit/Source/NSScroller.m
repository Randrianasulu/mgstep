/*
   NSScroller.m

   Control with which to scroll another

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSRunLoop.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSScroller.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSButtonCell.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSAffineTransform.h>


// Class variables 
static NSButtonCell *__upCell = nil;					// class button cells  
static NSButtonCell *__downCell = nil;					// used by scroller 
static NSButtonCell *__leftCell = nil;					// instances to draw 
static NSButtonCell *__rightCell = nil;					// buttons and knob.
static NSButtonCell *__knobCell = nil;

static const float __scrollerWidth = 12;				// NeXT was 17 & 16
static const float __buttonsWidth = 10;
static const float __buttonsDistance = 1;

static float __bottomOfKnob;
static float __topOfKnob;
static float __slotHeightMinusKnobHeight;

static float __leftOfKnob;
static float __rightOfKnob;
static float __slotWidthMinusKnobWidth;

static int __hideOverlay = 0;


static void
PrecalculateScroller(NSRect slotRect, NSRect knobRect, BOOL isHorizontal)
{															
	if (isHorizontal)
		{
		float halfKnobWidth = knobRect.size.width / 2;

		__leftOfKnob = slotRect.origin.x + halfKnobWidth;
		__rightOfKnob = NSMaxX(slotRect) - halfKnobWidth;
		__slotWidthMinusKnobWidth = slotRect.size.width - knobRect.size.width;
		}
	else
		{
		float halfKnobHeight = knobRect.size.height / 2;

		__bottomOfKnob = slotRect.origin.y + halfKnobHeight;
		__topOfKnob = NSMaxY(slotRect) - halfKnobHeight;
		__slotHeightMinusKnobHeight = NSHeight(slotRect) - NSHeight(knobRect);
		}
}

static float
ConvertScrollerPoint(NSPoint point, BOOL isHorizontal)
{															
	float p;

	if (isHorizontal) 									// Adjust point to lie
		{												// within the knob slot
		p = MIN(MAX(point.x, __leftOfKnob), __rightOfKnob);
		p = (p - __leftOfKnob) / __slotWidthMinusKnobWidth;
		}
	else
		{
		p = MIN(MAX(point.y, __bottomOfKnob), __topOfKnob);
		p = (p - __bottomOfKnob) / __slotHeightMinusKnobHeight;
		p = 1 - p;
		}

	return p;
}


@implementation NSScroller

+ (float) scrollerWidth						{ return __scrollerWidth; }
+ (NSScrollerStyle) preferredScrollerStyle	{ return NSScrollerStyleLegacy; }

- (id) initWithFrame:(NSRect)frameRect
{
	if (frameRect.size.width > frameRect.size.height) 		// determine the
		{													// orientation of
		_sl.isHorizontal = YES;								// the scroller and
		frameRect.size.height = [isa scrollerWidth];		// adjust it's size
		}
	else 
		frameRect.size.width = [isa scrollerWidth];

	if ((self = [super initWithFrame:frameRect]))
		{
		_hitPart = NSScrollerNoPart;
		_sl.style = [NSScroller preferredScrollerStyle];
		_sl.arrowsPosition = NSScrollerArrowsNone;

		if (_sl.style == NSScrollerStyleLegacy)
			{
			if (!__upCell)							// Cache class variables
				{
				__upCell = [NSButtonCell new];
				[__upCell setHighlightsBy:NSChangeBackgroundCellMask|NSContentsCellMask];
				[__upCell setImagePosition:NSImageOnly];
				[__upCell setContinuous:YES];
				[__upCell setPeriodicDelay:0.05 interval:0.05];
				__downCell = [__upCell copy];
				__leftCell = [__upCell copy];
				__rightCell = [__upCell copy];
			}	}
		else
			_v.hidden = YES;

		if (!__knobCell)
			{
			__knobCell = [NSButtonCell new];
			[__knobCell setButtonType:NSMomentaryChangeButton];
			[__knobCell setImagePosition:NSImageOnly];
//			if (_sl.style == NSScrollerStyleOverlay)
//				[__knobCell setBordered:NO];
			}

		[self setEnabled:NO];
		[self checkSpaceForParts];
		}
	
	return self;
}

- (void) setScrollerStyle:(NSScrollerStyle)style
{
	if ((_sl.style = style) == NSScrollerStyleOverlay)
		{
		_sl.arrowsPosition = NSScrollerArrowsNone;
		_v.hidden = YES;
		}
}

- (NSScrollerStyle) scrollerStyle					{ return _sl.style; }
- (void) setKnobStyle:(NSScrollerKnobStyle)style	{ _sl.knobStyle = style; }
- (NSScrollerKnobStyle) knobStyle					{ return _sl.knobStyle; }
- (NSScrollArrowPosition) arrowsPosition			{ return _sl.arrowsPosition; }
- (NSUsableScrollerParts) usableParts				{ return _sl.usableParts; }
- (float) knobProportion							{ return _knobProportion; }
- (float) floatValue								{ return _floatValue; }
- (NSScrollerPart) hitPart							{ return _hitPart; }
- (void) drawParts									{ }
- (void) encodeWithCoder:(NSCoder*)aCoder			{ }
- (id) initWithCoder:(NSCoder*)aDecoder				{ return self; }
- (BOOL) isOpaque									{ return YES; }
- (BOOL) acceptsFirstMouse:(NSEvent*)event			{ return YES; }
- (SEL) action										{ return _action; }
- (id) target										{ return _target; }
- (void) setAction:(SEL)action						{ _action = action; }
- (void) setTarget:(id)target						{ _target = target; }

- (void) checkSpaceForParts
{
	NSSize f = [self frame].size;
	float size = (_sl.isHorizontal ? f.width : f.height);
	float scrollerWidth = [isa scrollerWidth];

	if (size > 3 * scrollerWidth + 2)
		_sl.usableParts = NSAllScrollerParts;
	else if (size > 2 * scrollerWidth + 1)
		_sl.usableParts = NSOnlyScrollerArrows;
	else if (size > scrollerWidth)
		_sl.usableParts = NSNoScrollerParts;
}

- (void) _hide
{
	if (!_sl.isEnabled)
		return;
	if (--__hideOverlay <= 0)
		{
		_sl.hideOverlay = YES;
		[NSApp postEvent:_NSAppKitEvent() atStart:NO];
		[self setNeedsDisplayInRect:_bounds];
		}
	else
		[self performSelector:@selector(_hide) withObject:nil afterDelay:2.0];
}

- (void) setEnabled:(BOOL)flag
{
	if ((_sl.style == NSScrollerStyleOverlay))
		{
		__hideOverlay = (__hideOverlay > 0) ? __hideOverlay++ : 1;
		if (!flag)
			_sl.hideOverlay = YES;
		else
			[self performSelector:@selector(_hide) withObject:self afterDelay:2.0];
		}
	if (_v.hidden)
		_v.hidden = NO;
	if (_sl.isEnabled != flag)
		[self setNeedsDisplay:YES];
	_sl.isEnabled = flag;
}

- (void) setArrowsPosition:(NSScrollArrowPosition)pos
{
	if (_sl.arrowsPosition != pos)
		[self setNeedsDisplay:YES];
	_sl.arrowsPosition = pos;
}

- (void) setFloatValue:(float)aFloat
{
	_floatValue = MIN(MAX(aFloat, 0), 1);

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];

	if (__hideOverlay > 0 && (_sl.style == NSScrollerStyleOverlay))
		{
		[NSObject cancelPreviousPerformRequestsWithTarget:self
				  selector:@selector(_hide)
				  object:self];
		[self performSelector:@selector(_hide) withObject:self afterDelay:2.0];
		}
}

- (void) setFloatValue:(float)aFloat knobProportion:(float)ratio
{
	_knobProportion = MIN(MAX(ratio, 0), 1);
	[self setFloatValue:aFloat];
}

- (void) setKnobProportion:(float)prop  	{ _knobProportion = prop; }

- (void) setFrame:(NSRect)frame
{
	_sl.isHorizontal = (frame.size.width > frame.size.height) ? YES : NO;
	if (_sl.isHorizontal)
		frame.size.height = [isa scrollerWidth];
	else
		frame.size.width = [isa scrollerWidth];
	[super setFrame:frame];
	_hitPart = NSScrollerNoPart;
	[self checkSpaceForParts];
	[self setNeedsDisplay:YES];
}

- (void) setFrameSize:(NSSize)size
{
	_sl.isHorizontal = (size.width > size.height) ? YES : NO;
	if (_sl.isHorizontal)
		size.height = [isa scrollerWidth];
	else
		size.width = [isa scrollerWidth];
	[super setFrameSize:size];
	[self checkSpaceForParts];
	[self setNeedsDisplay:YES];
}

- (NSScrollerPart) testPart:(NSPoint)p				// find the part of the
{													// scroller at point
	if (p.x < 0 || p.y < 0 || p.x > NSWidth(_frame) || p.y > NSHeight(_frame))
		return NSScrollerNoPart;
	
	if (_sl.arrowsPosition != NSScrollerArrowsNone)
	  {
	  if ([self mouse:p inRect:[self rectForPart:NSScrollerDecrementLine]])
		  return NSScrollerDecrementLine;
	
	  if ([self mouse:p inRect:[self rectForPart:NSScrollerIncrementLine]])
		  return NSScrollerIncrementLine;
	  }
	
	if ([self mouse:p inRect:[self rectForPart:NSScrollerKnob]])
		return NSScrollerKnob;
	
	if ([self mouse:p inRect:[self rectForPart:NSScrollerKnobSlot]])
		return NSScrollerKnobSlot;
	
	if ([self mouse:p inRect:[self rectForPart:NSScrollerDecrementPage]])
		return NSScrollerDecrementPage;
	
	if ([self mouse:p inRect:[self rectForPart:NSScrollerIncrementPage]])
		return NSScrollerIncrementPage;
	
	return NSScrollerNoPart;
}

- (void) scrollWheel:(NSEvent *)event
{
	if (!_sl.isEnabled)
		return;
	if ([event pressure] > 0)
		_hitPart = NSScrollerIncrementPage;
	else
		_hitPart = NSScrollerDecrementPage;

	[self lockFocus];		// lock focus checked by clipview to copy on scroll
	[self sendAction:_action to:_target];
	[self unlockFocus];
}

- (void) mouseDown:(NSEvent*)event
{
	NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];

	if (_v.hidden)
		[self setEnabled: _sl.isEnabled];

	[self lockFocus];

	if (_sl.style == NSScrollerStyleLegacy)
		{
		if(_sl.isHorizontal)						// configure global cells
			{
			[__leftCell setAction:_action];
			[__rightCell setAction:_action];
			[__leftCell setTarget:_target];
			[__rightCell setTarget:_target];
			}
		else
			{
			[__upCell setAction:_action];
			[__downCell setAction:_action];
			[__upCell setTarget:_target];
			[__downCell setTarget:_target];
		}	}

	[__knobCell setTarget:_target];
	[__knobCell setAction:_action];

	switch ((_hitPart = [self testPart: p])) 
		{
		case NSScrollerIncrementLine:
		case NSScrollerDecrementLine:
		case NSScrollerIncrementPage:
		case NSScrollerDecrementPage:
			[self trackScrollButtons:event];
			break;
		
		case NSScrollerKnob:
			if (_sl.isEnabled)
				{
				[self drawKnobSlot];
				[self drawKnob];
				[_window flushWindow];
				[self trackKnob:event];
				}
			break;
		
		case NSScrollerKnobSlot: 
			if (_sl.isEnabled)
				{
				NSRect knobRect = [self rectForPart: NSScrollerKnob];
				NSRect slotRect = [self rectForPart: NSScrollerKnobSlot];

				PrecalculateScroller(slotRect, knobRect, _sl.isHorizontal);
				[self setFloatValue: ConvertScrollerPoint(p, _sl.isHorizontal)];
				[self sendAction:_action to:_target];
				[self drawKnobSlot];
				[self drawKnob];
				[_window flushWindow];
				[self trackKnob:event];
				}
	
		case NSScrollerNoPart:
			break;
		}

	_hitPart = NSScrollerNoPart;
	[self unlockFocus];
}

- (void) trackKnob:(NSEvent*)event
{
	NSDate *distantFuture = [NSDate distantFuture];
	NSRect knobRect = [self rectForPart: NSScrollerKnob];
	NSRect slotRect = [self rectForPart: NSScrollerKnobSlot];
	NSPoint point, current, offset;
	float previous = _floatValue;
	NSAffineTransform *matrix;
	NSEventType type;

	matrix = [self _matrixFromSubview:self toSuperview:[_window contentView]];
    [matrix invert];

	DBLog(@"NSScroller trackKnob");

	PrecalculateScroller(slotRect, knobRect, _sl.isHorizontal);

	current = [event locationInWindow];
	point = [matrix transformPoint: current];
	if (_sl.isHorizontal)
		offset = (NSPoint){NSMidX(knobRect) - point.x, 0};
	else
		offset = (NSPoint){0, NSMidY(knobRect) - point.y};
	current.x += offset.x;
	current.y += offset.y;
	knobRect.origin = [matrix transformPoint:current];

	_hitPart = NSScrollerKnob;						// set periodic events rate
													// to achieve max of ~30fps
	[NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.033];

	while ((type = [event type]) != NSLeftMouseUp)				 
		{											// user is moving scroller
		if (type != NSPeriodic)						// loop until left mouse up
			{
			current = [event locationInWindow];
			current.x += offset.x;
			current.y += offset.y;
			}
		else				
			{
			point = [matrix transformPoint:current];

			if (point.x != knobRect.origin.x || point.y != knobRect.origin.y) 
				{									
				float v = ConvertScrollerPoint(point, _sl.isHorizontal);

				if (v != previous)
					{
					previous = v;
					_floatValue = MIN(MAX(v, 0), 1);

					[self drawKnobSlot];
					[self drawKnob];				// draw the scroller knob
					[_target performSelector:_action withObject:self];
					[_window flushWindow];
					}

				knobRect.origin = point;
			}	}

		event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
					   untilDate:distantFuture 
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
  		}

	[NSEvent stopPeriodicEvents];

	if ([_target isKindOfClass:[NSResponder class]])
		[_target mouseUp:event];
}

- (void) trackScrollButtons:(NSEvent*)event
{
	NSDate *distantFuture = [NSDate distantFuture];
	unsigned int mask = NSLeftMouseDownMask | NSLeftMouseUpMask 
					  | NSLeftMouseDraggedMask | NSMouseMovedMask;

	do	{
		NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
		id theCell;
		
		switch ((_hitPart = [self testPart:p])) 			// determine which 
			{												// cell was hit
			case NSScrollerIncrementLine:
			case NSScrollerIncrementPage:
				theCell = (_sl.isHorizontal ? __rightCell : __upCell);
				break;

			case NSScrollerDecrementLine:
			case NSScrollerDecrementPage:
				theCell = (_sl.isHorizontal ? __leftCell : __downCell);
				break;

			default:
				theCell = nil;
				break;
			}

		if (theCell) 
			{
			NSRect rect = [self rectForPart:_hitPart];
			BOOL done = NO;

			[theCell highlight:YES withFrame:rect inView:self];	
			[_window flushWindow];

			DBLog (@"tracking cell %x", theCell);

			done = [theCell trackMouse:event				// Track the mouse
							inRect:rect						// until left mouse
							ofView:self						// goes up
							untilMouseUp:YES];

			[theCell highlight:NO withFrame:rect inView:self];
			[_window flushWindow];

			if (done)
				{
				if([_target isKindOfClass:[NSResponder class]])
					[_target mouseUp:event];

				break;
			}	}

		event = [NSApp nextEventMatchingMask:mask
					   untilDate:distantFuture 
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
		}
	while ([event type] == NSLeftMouseDragged);
}

- (void) drawRect:(NSRect)rect								// draw scroller
{
	DBLog (@"NSScroller drawRect: ((%f, %f), (%f, %f))",
			rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

	if (_sl.arrowsPosition != NSScrollerArrowsNone)
		{
		[self drawArrow:NSScrollerDecrementArrow highlight:NO];
		[self drawArrow:NSScrollerIncrementArrow highlight:NO];
		}
	
	[self drawKnobSlot];
	if (!_v.hidden)
		[self drawKnob];
}

- (void) drawArrow:(NSScrollerArrow)whichButton highlight:(BOOL)flag
{
	id c = nil;
	NSRect r;

	switch (whichButton)
		{
		case NSScrollerDecrementArrow:
			c = (_sl.isHorizontal ? __leftCell : __downCell);
			r = [self rectForPart:NSScrollerDecrementLine];
			break;
		case NSScrollerIncrementArrow:
			c = (_sl.isHorizontal ? __rightCell : __upCell);
			r = [self rectForPart:NSScrollerIncrementLine];
			break;
		}
	
	DBLog (@"position of %s cell is (%f, %f)",
		(whichButton == NSScrollerIncrementArrow ? "increment" : "decrement"),
		r.origin.x, r.origin.y);

	[c drawWithFrame:r inView:self];
}

- (void) drawKnob
{
	[__knobCell drawWithFrame:[self rectForPart:NSScrollerKnob] inView:self];
}

- (void) drawKnobSlot
{
	float g = NSDarkGray;

	if ((_sl.style == NSScrollerStyleOverlay))
		if ((_sl.knobStyle == NSScrollerKnobStyleLight))
			g = NSWhite;

	if (_sl.hideOverlay)
		_v.hidden = YES;
	_sl.hideOverlay = NO;

	if (_v.hidden && [_superview respondsToSelector:@selector(backgroundColor)])
		[[(NSClipView *)_superview backgroundColor] set];
	else
		PSsetgray(g);
	NSRectFill([self rectForPart: NSScrollerKnobSlot]);		// draw bar slot
}

- (NSRect) rectForPart:(NSScrollerPart)partCode
{
	float x = 1;
	float y = 1;
	float width = 0;
	float height = 0;
	float floatValue;
	NSRect scrollerFrame = _frame;
	NSScrollArrowPosition arrowsPosition;
	NSUsableScrollerParts usableParts = (!_sl.isEnabled) ? NSNoScrollerParts
														 : _sl.usableParts;
	if (!_sl.isHorizontal) 		// swap the meaning of the arrows position
		{						// if the scroller's orientation is vertical.
		if (_sl.arrowsPosition == NSScrollerArrowsMaxEnd)
			arrowsPosition = NSScrollerArrowsMinEnd;
		else
			{ 
			if (_sl.arrowsPosition == NSScrollerArrowsMinEnd)
				arrowsPosition = NSScrollerArrowsMaxEnd;
			else
				arrowsPosition = NSScrollerArrowsNone;
		}	}
	else
		arrowsPosition = _sl.arrowsPosition;

   if (_sl.isHorizontal)				// Determine width, height of scroller
		{
		width = scrollerFrame.size.height;
		height = scrollerFrame.size.width;
//		if ([_cell isBezeled])  FIX ME determine if superview is bezeled in checkSpaceForParts
			height -= 2;
		floatValue = _floatValue;
		}
    else 
		{
		width = scrollerFrame.size.width;
		height = scrollerFrame.size.height;
		floatValue = 1 - _floatValue;
    	}

	switch (partCode) 					// compute size of scroller components
		{
    	case NSScrollerKnob:
			{
			float minHeight = 2 * __scrollerWidth;
			float knobHeight, knobPosition;
			float slotHeight = height;

			if (usableParts != NSAllScrollerParts)		// no knob
				return NSZeroRect;
      													// calc the slot Height
			if (arrowsPosition != NSScrollerArrowsNone)
				slotHeight = height - 2 * (__buttonsWidth + __buttonsDistance);

			knobHeight = floor(_knobProportion * slotHeight);
			if (knobHeight < minHeight)					// adjust knob height
				{										// and proportion if
				knobHeight = minHeight;					// necessary
				_knobProportion = (float)(knobHeight / slotHeight);
				}
														// calc knob's position
      		knobPosition = floatValue * (slotHeight - knobHeight);
     		knobPosition = (float)floor(knobPosition);	// avoid rounding error

			if (_sl.isHorizontal)
				{
				if (arrowsPosition == NSScrollerArrowsMinEnd)
					{
					y = knobPosition > 0 ? knobPosition : 1;
					y += (2 * (__buttonsWidth + __buttonsDistance));
					}
				else
					if (arrowsPosition == NSScrollerArrowsNone)
						y = knobPosition > 0 ? knobPosition : 1;
					else
						y = knobPosition > 0 ? knobPosition - 1 : 1;
				}
			else
				{
				if (arrowsPosition == NSScrollerArrowsMinEnd)
					{
					y = knobPosition > 0 ? knobPosition : 0;
					y += (2 * (__buttonsWidth + __buttonsDistance));
					}
				else
					y = knobPosition > 0 ? knobPosition - 1 : 1;
			}
			height = knobHeight;
			width = __buttonsWidth;
			break;										
    		}

		case NSScrollerKnobSlot:	// if the scroller does  not have buttons
			y = 0;					// slot completely fills the scroller
			x = 0;
      		width = __scrollerWidth;

//			if (_sl.isHorizontal) 						// keeps horiz knob off
//				x++;									// of the buttons
			if (usableParts == NSNoScrollerParts)
				break;

			if (_sl.style == NSScrollerStyleLegacy)
				{
				if (arrowsPosition == NSScrollerArrowsMaxEnd)
					height -= 2 * (__buttonsWidth + __buttonsDistance);
				else 
					{
					if (arrowsPosition == NSScrollerArrowsMinEnd) 
						{
						y = 2 * (__buttonsWidth + __buttonsDistance);
						height -= y;
				}	}	}
			break;

		case NSScrollerDecrementLine:
		case NSScrollerDecrementPage:
			if (usableParts == NSNoScrollerParts)		// if scroller has no
				return NSZeroRect;						// parts or knob then
														// return a zero rect
			width = __buttonsWidth;
			if (arrowsPosition == NSScrollerArrowsMaxEnd)
				y = height - 2 * (__buttonsWidth + __buttonsDistance);
			else
				{ 
				if (arrowsPosition == NSScrollerArrowsMinEnd)
					y = 1;
				else
					return NSZeroRect;
				}
      		height = __buttonsWidth;
			break;

		case NSScrollerIncrementLine:
		case NSScrollerIncrementPage:
			if (usableParts == NSNoScrollerParts)		// if scroller has no
				return NSZeroRect;						// parts or knob then
														// return a zero rect
      		width = __buttonsWidth;
      		if (arrowsPosition == NSScrollerArrowsMaxEnd)
				y = height - (__buttonsWidth + __buttonsDistance);
      		else 
				{
				if (arrowsPosition == NSScrollerArrowsMinEnd)
					y = __buttonsWidth + __buttonsDistance + 1;
      			else
					return NSZeroRect;
				}
			height = __buttonsWidth;
			break;

		case NSScrollerNoPart:
      		return NSZeroRect;
  		}

	if (_sl.isHorizontal)
		return (NSRect) {{y, x}, {height, width}};

	return (NSRect) {{x, y}, {width, height}};
}

@end
