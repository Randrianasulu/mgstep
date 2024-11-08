/*
   NSSplitView.h

   Allows multiple views to share a region in a window

   Copyright (C) 1996-2018 Free Software Foundation, Inc.

   Author:  Robert Vasvari <vrobi@ddrummer.com>
   Date:	Jul 1998
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	November 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSSplitView.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSColor.h>


#define NOTE(n_name)	NSSplitView##n_name##Notification

static NSImage *__dimpleImage = nil;


@implementation NSSplitView

- (id) initWithFrame:(NSRect)frameRect
{	
	if ((self = [super initWithFrame:frameRect]))
		{
		[self seDividerColor:[NSColor lightGrayColor]];
		if (!__dimpleImage)
			__dimpleImage = [[NSImage imageNamed:@"dotDimple"] retain];
		if (!_dividerStyle)
			_dividerStyle = NSSplitViewDividerStyleThick;
		_dividerThickness = (int)[self dividerThickness];
		}

	return self;
}

- (void) dealloc
{
	[_dividerColor release];
	[super dealloc];
}

- (void) mouseDown:(NSEvent *)event 
{
	NSPoint p;
	NSEvent *e;
	NSRect r, r1, bigRect, vr;
	id v, prev = nil;
	float minCoord, maxCoord = -1;
	int offset = 0, i, count;
	float divVertical, divHorizontal;
	NSDate *distantFuture;

	if((count = [_subviews count]) < 2)		// if there are less than two  
		return;								// subviews, there is nothing to do

	[_window setAcceptsMouseMovedEvents:YES];
	vr = [self visibleRect];
											// find out which divider was hit
	p = [self convertPoint:[event locationInWindow] fromView:nil];
	for(i = 0; i < count; i++)
		{	
		v = [_subviews objectAtIndex:i];
		r = [v frame];

		if(!_isVertical)					// if click is inside of a subview, 
			{								// return.  should never happen
			if((p.y > NSMinY(r)) && (p.y < NSMaxY(r)))
				goto RETURN_LABEL;
			if(NSMaxY(r) > p.y)
				{	
				offset = i;								// get enclosing rect
				r = (prev) ? [prev frame] : NSZeroRect;	// for the two views
				r1 = (v) ? [v frame] : NSZeroRect;
				bigRect = NSUnionRect(r1 , r);
				divVertical = _dividerThickness;
				divHorizontal = NSWidth([self frame]);
				minCoord = NSMinY(bigRect) + divVertical;	// set drag limits
				maxCoord = NSMaxY(bigRect) - divVertical;
				NSMinY(r1) = p.y;
				break;
			}	}
		else
			{
			if((p.x > NSMinX(r)) && (p.x < NSMaxX(r)))
				goto RETURN_LABEL;
			if(NSMaxX(r) > p.x)
				{										
				offset = i;								// get enclosing rect
				r = (prev) ? [prev frame] : NSZeroRect;	// for the two views
				r1 = (v) ? [v frame] : NSZeroRect;
				bigRect = NSUnionRect(r1 , r);
				divHorizontal = _dividerThickness;
				divVertical = NSHeight([self frame]);
				minCoord = NSMinX(bigRect) + divHorizontal;	// set drag limits
				maxCoord = NSMaxX(bigRect) - divHorizontal;
				NSMinX(r1) = p.x;
				break;
			}	}
		prev = v;
		}

	if(maxCoord == -1)
		return;
										// find out what the dragging limit is 
	if(_delegate && [_delegate respondsToSelector:@selector
			   (splitView:constrainMinCoordinate:maxCoordinate:ofSubviewAt:)])
		{	
		if(!_isVertical)
        	{
			float delMinY = minCoord, delMaxY = maxCoord;

			[_delegate splitView:self
					   constrainMinCoordinate:&delMinY
					   maxCoordinate:&delMaxY
					   ofSubviewAt:offset];
			if(delMinY > minCoord)					// we are still constrained
				minCoord = delMinY;					// by the original bounds
			if(delMaxY < maxCoord) 
				maxCoord = delMaxY; 
			}
		else
			{
			float delMinX = minCoord, delMaxX = maxCoord;

			[_delegate splitView:self
					   constrainMinCoordinate:&delMinX
					   maxCoordinate:&delMaxX
					   ofSubviewAt:offset];
			if(delMinX > minCoord)					// we are still constrained
				minCoord = delMinX;					// by the original bounds
			if(delMaxX < maxCoord) 
				maxCoord = delMaxX; 
		}	}

	[self lockFocus];
	[NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
	[_dividerColor set];
	r.size = (NSSize){divHorizontal, divVertical};

	e = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
			   untilDate:(distantFuture = [NSDate distantFuture]) 
			   inMode:NSEventTrackingRunLoopMode 
			   dequeue:YES];

	while([e type] != NSLeftMouseUp)				// user is moving the knob
		{ 											// loop until left mouse up
		if ([e type] != NSPeriodic)
			p = [self convertPoint:[e locationInWindow] fromView:nil];
		if(!_isVertical)
			{
			if(p.y < minCoord) 
				p.y = minCoord;
			if(p.y > maxCoord) 
				p.y = maxCoord;
			r.origin.y = p.y - (divVertical/2.);
			r.origin.x = NSMinX(vr);
			}
		else
			{
			if(p.x < minCoord) 
				p.x = minCoord;
			if(p.x > maxCoord) 
				p.x = maxCoord;
			r.origin.x = p.x - (divHorizontal/2.);
			r.origin.y = NSMinY(vr);
			}
		DBLog(@"drawing divider at x:%d, y:%d, w:%d, h:%d\n", 
					(int)NSMinX(r),(int)NSMinY(r),
					(int)NSWidth(r),(int)NSHeight(r));

		NSRectFillUsingOperation(r, NSCompositeXOR);		// draw the divider
		[_window flushWindow];
		e = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
				   untilDate:distantFuture 
				   inMode:NSEventTrackingRunLoopMode 
				   dequeue:YES];

		NSRectFillUsingOperation(r, NSCompositeXOR);		// undraw divider
		[_window flushWindow];
		}

	[self unlockFocus];
	[NSEvent stopPeriodicEvents];
														// do nothing if move
	if(!_isVertical)									// was less than half
		{												// of divider thickness
		float d = p.y > NSMinY(r1) ? (p.y - NSMinY(r1)) : (NSMinY(r1) - p.y);
		if (d <= (_dividerThickness / 2))
			return;
		}
	else
		{
		float d = p.x > NSMinX(r1) ? (p.x - NSMinX(r1)) : (NSMinX(r1) - p.x);
		if (d <= (_dividerThickness / 2))
			return;
		}

	r = [prev frame];
	if(!_isVertical)							// resize subviews accordingly
		{
		r.size.height = p.y - NSMinY(bigRect) - (divVertical/2.);
		if(NSHeight(r) < 1.) 
			r.size.height = 1.;
		}
	else
		{
		r.size.width = p.x - NSMinX(bigRect) - (divHorizontal/2.);
		if(NSWidth(r) < 1.) 
			r.size.width = 1.;
		}
	[prev setFrame:r];
	DBLog(@"drawing PREV at x:%d, y:%d, w:%d, h:%d\n", (int)NSMinX(r), 
				(int)NSMinY(r), (int)NSWidth(r), (int)NSHeight(r));
	
	r1 = [v frame];
	if(!_isVertical)
		{
		r1.origin.y = p.y + (divVertical/2.);
		if(NSMinY(r1) < 0.) 
			r1.origin.y = 0.;
		r1.size.height = NSHeight(bigRect) - NSHeight(r) - divVertical;
		if(NSHeight(r) < 1.) 
			r.size.height = 1.;
		}
	else
		{
		r1.origin.x = p.x + (divHorizontal/2.);
		if(NSMinX(r1) < 0.) 
			r1.origin.x = 0.;
		r1.size.width = NSWidth(bigRect) - NSWidth(r) - divHorizontal;
		if(NSWidth(r1) < 1.) 
			r1.size.width = 1.;
		}

	[v setFrame:r1];
	DBLog(@"drawing LAST at x:%d, y:%d, w:%d, h:%d\n", (int)NSMinX(r1), 
				(int)NSMinY(r1), (int)NSWidth(r1), (int)NSHeight(r1));
	
	[_window invalidateCursorRectsForView:self];	
	
RETURN_LABEL:

	[_window setAcceptsMouseMovedEvents:NO];
	[self setNeedsDisplay:YES];
}

- (void) adjustSubviews
{
	SEL resizeSubviews = @selector(splitView:resizeSubviewsWithOldSize:);

	[NSNotificationCenter post: NOTE(WillResizeSubviews) object: self];

	if ((_delegate) && [_delegate respondsToSelector: resizeSubviews])
      	[_delegate splitView:self resizeSubviewsWithOldSize:_frame.size];
	else
		{
		int i, ew, count = [_subviews count];
		int div = (int)(_dividerThickness * (count - 1));
		float total = 0, maxSize;

		if (_isVertical)						// split the area up evenly
			ew = (int)ceil((NSWidth(_bounds) - div) / count);

		for(i = 0; i < count; i++)
        	{	
			id v = [_subviews objectAtIndex:i];
			NSRect r = [v frame];
			NSRect rect;

			if (_isVertical)
				{
				if (ew > NSWidth(r))		// subview smaller than allotted
					{
					if (i == 0)		// FIX ME check view's resize mask, holding priority
						{
						rect.size = NSMakeSize(NSWidth(r), NSHeight(_bounds));
						ew += (ew - NSWidth(r)) / (count - 1);
						}
					else
						rect.size = NSMakeSize(ew, NSHeight(_bounds));
					}
				else
					rect.size = NSMakeSize(ew, NSHeight(_bounds));
											// make sure nothing spills over
				while((total + NSWidth(rect)) > (NSWidth(_bounds) - div))
					NSWidth(rect) -= 1.;

				rect.origin.x = (i) ? (_dividerThickness + total) : 0;
				rect.origin.y = 0;
				total += NSWidth(rect);
				if(NSWidth(rect) < 1)
					NSWidth(rect) = 1;
				if(NSMinX(rect) < 0) 
					NSMinX(rect) = 0;
				}
			else
				{
				maxSize = total + NSHeight(r) + _dividerThickness;
				rect = (NSRect){{NSMinX(r),total}, _bounds.size};

				if(maxSize <= NSHeight(_bounds))
					{
					total += (NSHeight(r) + _dividerThickness);
					NSHeight(rect) = NSHeight(r);
					}
				else
					{			// calc divider thickness not accounted for
					float divRemainder = div - (_dividerThickness * i);

					NSHeight(rect) = NSHeight(_bounds) - total - divRemainder;
					total += (NSHeight(rect) + _dividerThickness);
					}

				if(NSHeight(rect) < 1) 
					NSHeight(rect) = 1;
				if(NSMinY(rect) < 0) 
					NSMinY(rect) = 0;
				}

			[v setFrame: rect];
		}	}

	[NSNotificationCenter post: NOTE(DidResizeSubviews) object: self];
}

- (void) addSubview:(NSView *)aView
		 positioned:(NSWindowOrderingMode)place
		 relativeTo:(NSView *)otherView
{	
	[super addSubview:aView positioned:place relativeTo:otherView];
	if ([_subviews count] > 1)
		[self adjustSubviews];
}

- (void) addSubview:(NSView *)aView
{
	[super addSubview:aView];
	if ([_subviews count] > 1)
		[self adjustSubviews];
}

- (BOOL) isVertical							{ return _isVertical; }
- (void) setVertical:(BOOL)flag				{ _isVertical = flag; }

- (CGFloat) dividerThickness
{
	return (_dividerStyle == NSSplitViewDividerStyleThin) ? 2.0 : 8.0;
}

- (void) drawDividerInRect:(NSRect)aRect
{
	NSPoint dimpleOrg;
	NSSize dimpleSize = [__dimpleImage size];
						// composite into the center of the given rect. Since 
						// NSImages are always flipped, we adjust for it here
	dimpleOrg.x = MAX(NSMidX(aRect) - (dimpleSize.width / 2), 0.);
	dimpleOrg.y = MAX(NSMidY(aRect) - (dimpleSize.height / 2),0.);
	if(_v.flipped) 
		dimpleOrg.y += dimpleSize.height;
	[__dimpleImage compositeToPoint:dimpleOrg operation:NSCompositeSourceOver];
}

- (void) drawRect:(NSRect)r
{
	int i, count = [_subviews count];

	if ([self isOpaque])
		{
		[[_window backgroundColor] set];
		NSRectFill(r);
		}

	for (i = 0; i < (count - 1); i++)						// draw the dimples
		{	
		id v = [_subviews objectAtIndex:i];
		NSRect divRect = [v frame];

		if(!_isVertical)
			{
			divRect.origin.y = NSMaxY(divRect);
			divRect.size.height = _dividerThickness;
			}
		else
			{
			divRect.origin.x = NSMaxX(divRect);
			divRect.size.width = _dividerThickness;
			}
		[self drawDividerInRect:divRect];
		}
}

- (void) resizeWithOldSuperviewSize:(NSSize)oldSize
{	
	[super resizeWithOldSuperviewSize:oldSize];
	[self adjustSubviews];
	[_window invalidateCursorRectsForView:self];
}

- (void) setDividerStyle:(NSSplitViewDividerStyle)s	{ _dividerStyle = s; }
- (NSSplitViewDividerStyle) dividerStyle			{ return _dividerStyle; }
- (BOOL) isOpaque									{ return YES; }
- (void) seDividerColor:(NSColor *)c				{ ASSIGN(_dividerColor,c); }
- (NSColor *) dividerColor							{ return _dividerColor; }
- (id) delegate										{ return _delegate; }

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;

	if (_delegate == anObject)
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(splitView##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(splitView##notif_name:) \
		   name:NSSplitView##notif_name##Notification \
		   object:self]

#define IGNORE_(notif_name) [n removeObserver:_delegate \
								name:NSSplitView##notif_name##Notification \
								object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(DidResizeSubviews);
		IGNORE_(WillResizeSubviews);
		}

	if (!(_delegate = anObject))
		return;

	OBSERVE_(DidResizeSubviews);
	OBSERVE_(WillResizeSubviews);
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:_delegate];
	[aCoder encodeObject:_dividerColor];
	[aCoder encodeValueOfObjCType:@encode(int) at:&_dividerStyle];
	[aCoder encodeValueOfObjCType:@encode(BOOL) at:&_isVertical];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];

	_delegate = [aDecoder decodeObject];
	_dividerColor = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(int) at:&_dividerStyle];
	[aDecoder decodeValueOfObjCType:@encode(BOOL) at:&_isVertical];

	return self;
}

@end
