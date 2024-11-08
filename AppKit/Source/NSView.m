/*
   NSView.m

   Drawing and event handling class.

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSView.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSText.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSDragging.h>
#include <AppKit/NSAffineTransform.h>
#include <QuartzCore/CALayer.h>


#define FOCUS_VIEW		((CGContext *) _CGContext())->_gs->focusView

#define NOTE(n_name)	NSView##n_name##Notification


// Class variables
static NSView *__toolTipOwnerView = nil;
static NSMutableDictionary *__toolTipsDict = nil;
static NSText   *__toolTipText = nil;
static NSWindow *__toolTipWindow = nil;

static NSPoint __lastPoint = {-1, -1};
static unsigned int __mouseMovedEventCounter = 0;
static unsigned int __toolTipSequenceCounter = 0;
static NSTrackingRectTag __trackRectTag = 0;


/* ****************************************************************************

 		TrackingRect -- Private class describing tracking/cursor rects

** ***************************************************************************/

@interface _TrackingRect : NSObject
{
@public
	NSRect rect;
	NSTrackingRectTag tag;
	id owner;
	void *userData;
	BOOL inside;
}

- (void) push;

@end

@implementation _TrackingRect

- (void) dealloc
{
	[owner release];
	[super dealloc];
}

- (void) push							{ [owner push]; }

@end /* _TrackingRect */


@interface NSWindow (TrackingRects)

- (NSMutableArray *) _trackingRects;
- (NSMutableArray *) _cursorRects;

@end

@implementation NSWindow (TrackingRects)

- (NSMutableArray *) _trackingRects
{
	if(!(_trackRects))
		{
		_w.cursorRectsEnabled = YES;
		_trackRects = [NSMutableArray new];
		}

	return _trackRects;
}

- (NSMutableArray *) _cursorRects
{
	if(!(_cursorRects))
		{
		_w.cursorRectsEnabled = YES;
		_cursorRects = [NSMutableArray new];
		}

	return _cursorRects;
}

- (void) mouseMoved:(NSEvent *)event
{
	NSPoint current = [event locationInWindow];
	int i, j = (_trackRects) ? [_trackRects count] : 0;

	for (i = 0; i < j; ++i)								// Check tracking rects
		{
		_TrackingRect *r = (_TrackingRect *)[_trackRects objectAtIndex:i];
		BOOL last = NSMouseInRect(__lastPoint, r->rect, NO);
		BOOL now = NSMouseInRect(current, r->rect, NO);

		if ((last) && (!now))							// Mouse exited event
			{
			NSEvent *e = [NSEvent enterExitEventWithType:NSMouseExited
								  location:current 
								  modifierFlags:[event modifierFlags]
								  timestamp:0 
								  windowNumber:_windowNumber
								  context:NULL 
								  eventNumber:__mouseMovedEventCounter++ 
								  trackingNumber:r->tag 
								  userData:r->userData];

			[r->owner mouseExited:e];					// Send event to owner
			}

		if ((!last) && (now))							// Mouse entered event
			{
			NSEvent *e = [NSEvent enterExitEventWithType:NSMouseEntered
								  location:current 
								  modifierFlags:[event modifierFlags]
								  timestamp:0 
								  windowNumber:_windowNumber
								  context:NULL 
								  eventNumber:__mouseMovedEventCounter++ 
								  trackingNumber:r->tag 
								  userData:r->userData];

			[r->owner mouseEntered:e];					// Send event to owner
		}	}

	if ((_cursorRects) && ((j = [_cursorRects count]) > 0))
		{
		NSEvent *enter[j], *exit[j];
		int l = 0, k = 0;
	
		for (i = 0; i < j; ++i)							// Check cursor rects
			{
			_TrackingRect *r =(_TrackingRect*)[_cursorRects objectAtIndex:i];
			BOOL last = NSMouseInRect(__lastPoint, r->rect, NO);
			BOOL now = NSMouseInRect(current, r->rect, NO);
	
			if ((!last) && (now))							// Mouse entered
				enter[k++] = [NSEvent enterExitEventWithType: NSCursorUpdate
									  location: current
									  modifierFlags: [event modifierFlags]
									  timestamp: 0
									  windowNumber: _windowNumber
									  context: [event context]
									  eventNumber: __mouseMovedEventCounter++
									  trackingNumber: (int)YES
									  userData: (void *)r->owner];
	
			if ((last) && (!now))							// Mouse exited
				exit[l++] = [NSEvent enterExitEventWithType: NSCursorUpdate
									 location: current
									 modifierFlags: [event modifierFlags]
									 timestamp: 0
									 windowNumber: _windowNumber
									 context: [event context]
									 eventNumber: __mouseMovedEventCounter++
									 trackingNumber: (int)NO
									 userData: (void *)r];
			}
	
		while(k--)
			[self postEvent:enter[k] atStart: YES];
		while(l--)											// Post cursor
			[self postEvent:exit[l] atStart: YES];			// update events
		}

	__lastPoint = current;
}

@end /* NSWindow (TrackingRects) */

/* ****************************************************************************

 		NSView

** ***************************************************************************/

@implementation NSView

+ (NSView *) focusView				{ return FOCUS_VIEW; }

- (id) init						 	{ return [self initWithFrame:NSZeroRect]; }

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super init]))						// super is NSResponder
		{
		_frame = frameRect;
		_bounds = (NSRect){NSZeroPoint, _frame.size};

		_frameMatrix = [NSAffineTransform new];
		_boundsMatrix = [NSAffineTransform new];
		_subviews = [NSMutableArray new];
		_v.needsDisplay = YES;
		_v.autoSizeSubviews = YES;
		_v.flipped = [self isFlipped];
		}

	return self;
}

- (void) dealloc
{
	DBLog(@"NSView: dealloc class %@", [self class]);

	[_frameMatrix release];
	[_boundsMatrix release];
	[_subviews release];
	[_dragTypes release];

	if (__toolTipOwnerView == self)
		[self mouseExited:nil];
	if (_gState && _v.gStateAllocd)
		[self releaseGState];

	[super dealloc];
}

- (void) lockFocus
{
	NSPoint point;
														// do nothing if view 
	if (!_window)										// is not in a window's
		return;											// view heirarchy

	point = [self convertPoint:NSZeroPoint toView:nil];

	if(_v.flipped)										// view is flipped
		{
		if (_superview)									
			point.y = NSHeight([_window frame]) - point.y;
		else
		    point.y = NSHeight([_window frame]);
		}

	_NSLockFocus(self, point, YES);
	PSinitclip();
	NSRectClip([self visibleRect]);						// set clipping path
}

- (void) unlockFocus
{
	if (FOCUS_VIEW != self)
		NSLog (@"NSView: attempt to unlockFocus on an unfocused view.");

	PSgrestore();										// Restore the graphics
}									

- (void) addSubview:(NSView *)aView
{
	if (!aView || [self isDescendantOf:aView])
		{
		NSLog(((aView) ? @"addSubview: would create a loop in the view tree!"
					   : @"addSubview: can't add nil view"));
		return;
		}

	[aView viewWillMoveToWindow:_window];
	[aView setSuperview:self];
	[_subviews addObject: aView];					// Add to our subview list
	_v.hasSubviews = YES;
}

- (void) addSubview:(NSView *)aView
		 positioned:(NSWindowOrderingMode)place
		 relativeTo:(NSView *)otherView
{
	NSUInteger i;
													// making self a subview of
	if ([self isDescendantOf:aView])				// view would create a loop
		{											// in the view heirarchy
		NSLog(@"addSubview:positioned:relativeTo: would loop the view tree!");
		return;
		}

	if ([_subviews indexOfObjectIdenticalTo:aView] != NSNotFound)
		{											// already in view heirarchy
		NSLog(@"addSubview:positioned:relativeTo: *** already in view tree!");
		return;
		}

	[aView viewWillMoveToWindow:_window];			// Inform view of new win 
	[aView setSuperview:self];
	_v.hasSubviews = YES;

	if (otherView && (i = [_subviews indexOfObjectIdenticalTo: otherView])
			&& i != NSNotFound)
		{
		i = (place == NSWindowAbove) ? i : i-1;
		[_subviews insertObject:aView atIndex:i];
		return;
		}

	if (place == NSWindowAbove)
		[_subviews addObject: aView];				// Add to our subview list
	else
		[_subviews insertObject:aView atIndex:0];
}

- (NSView *) ancestorSharedWithView:(NSView *)aView
{
	if (self == aView)								// Are they the same view?
		return self;

	if ([self isDescendantOf: aView])
		return aView;
	if ([aView isDescendantOf: self])
		return self;

	if (![self superview])			// If neither are descendants of each other
		return nil;					// and either does not have a superview
	if (![aView superview])			// then they cannot have a common ancestor
		return nil;
									// Find the common ancestor of superviews
	return [[self superview] ancestorSharedWithView: [aView superview]];
}

- (BOOL) isDescendantOf:(NSView *)aView
{
	if (aView == self || (_superview == aView))
		return YES;

	if (!_superview) 								// No superview then this
		return NO;									// is end of the line

	return [_superview isDescendantOf:aView];
}

- (NSView *) opaqueAncestor
{
	return !_superview || [self isOpaque] ? self : [_superview opaqueAncestor];
}

- (void) _frameChanged
{
	NSPoint frameOrigin = _frame.origin;
	NSPoint boundsOrigin = (NSPoint){-NSMinX(_bounds), -NSMinY(_bounds)};

	if (!_superview)
		return;

	if((_v.flipped) && !_superview->_v.flipped && !_v.clipped)
		frameOrigin.y = NSMaxY(_frame);
	else
		if(!(_v.flipped) && (_superview->_v.flipped))
			{
			frameOrigin.y = NSHeight(_frame);
			boundsOrigin.y = NSHeight(_frame);
			}

	[_frameMatrix setFrameOrigin:frameOrigin];
	[_boundsMatrix setFrameOrigin:boundsOrigin];

	if (_v.hasToolTip)
		{
		NSMutableArray *trackRects = [_window _trackingRects];
		int i, j = [trackRects count];

		for (i = 0; i < j; ++i)
			{
			_TrackingRect *m = (_TrackingRect *)[trackRects objectAtIndex:i];

			if (m->owner == self)
				{
				[trackRects removeObjectAtIndex:i];
				break;
			}	}

		[self addTrackingRect:_bounds owner:self userData:NULL assumeInside:NO];
		}
}

- (void) setSuperview:(NSView *)superview
{
	if (superview == nil)
		[self removeFromSuperview];
	else
		{
		[self setNextResponder: (_superview = superview)];
		if ((_v.flipped) && [_superview isKindOfClass: [NSClipView class]])
			_v.clipped = YES;
		else
			_v.clipped = NO;

		[self _frameChanged];
		}
}

- (void) removeFromSuperview
{
	if (_window != nil)
		[self viewWillMoveToWindow:nil];

	if (_superview != nil)
		{
		[self setNextResponder:nil];
		[[_superview subviews] removeObjectIdenticalTo:self];
		_superview = nil;
		}
}

- (void) replaceSubview:(NSView *)oldView with:(NSView *)newView
{
	if (!newView)
		return;

	if (!oldView)
		[self addSubview:newView];
	else
		{
		NSUInteger index = [_subviews indexOfObjectIdenticalTo:oldView];

		if (index != NSNotFound)
			{
			[oldView viewWillMoveToWindow:nil];
			[_subviews replaceObjectAtIndex:index withObject:newView];
			[newView viewWillMoveToWindow:_window];
			[newView setSuperview:self];
    	}	}
}

- (void) sortSubviewsUsingFunction:(NSInteger (*)(id ,id ,void *))compare
						   context:(void *)cx
{
	[_subviews sortUsingFunction:compare context:cx];
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow
{
	if (_window != newWindow)
		{
		int i, count = [_subviews count];

		if ([_window firstResponder] == self)
			[_window makeFirstResponder: _window];
		_window = newWindow;
		if (!_v.gStateAllocd)
			_gState = (_window != nil) ? [_window gState] : 0;
		for (i = 0; i < count; ++i)							// Pass to subviews
			[[_subviews objectAtIndex:i] viewWillMoveToWindow:newWindow];
		}
}

- (void) rotateByAngle:(float)angle
{
	[_boundsMatrix rotateByDegrees:angle];
	_v.isRotatedFromBase = _v.isRotatedOrScaledFromBase = YES;

	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (void) setFrame:(NSRect)frameRect
{
	_frame.origin = frameRect.origin;
	[self setFrameSize: frameRect.size];
}

- (void) setFrameOrigin:(NSPoint)newOrigin
{
	_frame.origin = newOrigin;
	if(_superview)
		[self _frameChanged];
	if (_v.postFrameChange)
		[NSNotificationCenter post: NOTE(FrameDidChange) object: self];
}

- (void) setFrameSize:(NSSize)newSize
{
	NSSize o = _frame.size;

	_frame.size = _bounds.size = newSize;
	_invalid = NSZeroRect;
	if (_superview)
		[self _frameChanged];
	if (_v.autoSizeSubviews)
		[self resizeSubviewsWithOldSize: o];				// Resize subviews
	if (_v.postFrameChange)
		[NSNotificationCenter post: NOTE(FrameDidChange) object: self];
}

- (void) setFrameRotation:(float)angle
{
	[_frameMatrix rotateByDegrees:angle];
	_v.isRotatedFromBase = _v.isRotatedOrScaledFromBase = YES;

	if (_v.postFrameChange)
		[NSNotificationCenter post: NOTE(FrameDidChange) object: self];
}

- (BOOL) isRotatedFromBase
{
	if (_v.isRotatedFromBase)
		return _v.isRotatedFromBase;

	return (_superview) ? [_superview isRotatedFromBase] : NO;
}

- (BOOL) isRotatedOrScaledFromBase
{
	if (_v.isRotatedOrScaledFromBase)
		return _v.isRotatedOrScaledFromBase;

	return (_superview) ? [_superview isRotatedOrScaledFromBase] : NO;
}

- (void) scaleUnitSquareToSize:(NSSize)newSize
{
	if (!newSize.width)
		newSize.width = 1;
	if (!newSize.height)
		newSize.height = 1;

	_bounds.size.width = _frame.size.width / newSize.width;
	_bounds.size.height = _frame.size.height / newSize.height;
	_v.isRotatedOrScaledFromBase = YES;
	_invalid = NSZeroRect;					

	[_boundsMatrix scaleXBy:_frame.size.width / _bounds.size.width
				   		yBy:_frame.size.height / _bounds.size.height];

	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (void) setBounds:(NSRect)aRect
{
	_bounds.origin = aRect.origin;
	[_boundsMatrix setFrameOrigin:(NSPoint){-NSMinX(_bounds),-NSMinY(_bounds)}];
	[self setBoundsSize: aRect.size];
}

- (void) setBoundsOrigin:(NSPoint)newOrigin			// translate bounds origin
{													// in opposite direction so
	_bounds.origin = newOrigin;						// that newOrigin becomes 
													// the origin when viewed. 
	[_boundsMatrix setFrameOrigin:NSMakePoint(-newOrigin.x, -newOrigin.y)];

	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (void) setBoundsSize:(NSSize)newSize
{
	_bounds.size = newSize;
	_invalid = NSZeroRect;					

	if (_bounds.size.width != 0.0 && _bounds.size.height != 0.0)
		{
		float sx = _frame.size.width / _bounds.size.width;
		float sy = _frame.size.height / _bounds.size.height;

		if (sx != 1.0 || sy != 1.0)
			_v.isRotatedOrScaledFromBase = YES;
		if (_v.isRotatedOrScaledFromBase)
			[_boundsMatrix scaleTo:sx :sy];
		}
	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (void) setBoundsRotation:(float)angle
{
	[_boundsMatrix rotateByDegrees:angle];
	_v.isRotatedFromBase = _v.isRotatedOrScaledFromBase = YES;

	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (void) translateOriginToPoint:(NSPoint)point
{
	[_boundsMatrix translateToPoint:point];

	if (_v.postBoundsChange)
		[NSNotificationCenter post: NOTE(BoundsDidChange) object: self];
}

- (NSRect) centerScanRect:(NSRect)aRect
{
	return NSZeroRect;
}

- (NSAffineTransform*) _matrixFromSubview:(NSView*)subview
							  toSuperview:(NSView*)superview
{
	NSView *view = subview;
	int c = 0, i = 0;
	NSAffineTransform *matrix = [NSAffineTransform transform];

	while (view && view != superview) 						// count the views
		{
		c++;
		view = view->_superview;
  		}
	{
	NSView *a[c];

	view = subview;
	while (view && view != superview) 						// create an array
		{													// of views from
		a[i++] = view;										// the subview up
		view = view->_superview;							// to the superview
  		}

	for (i = c - 1; i >= 0; i--)							// concatenate the
		{													// matrices in
		if(!a[i]->_v.clipped)								// reverse order
			{
			[matrix appendTransform:a[i]->_frameMatrix];

			if(!a[i]->_v.isClip || (a[i]->_v.isClip && !a[i]->_v.flipped))
				{
				[matrix appendTransform:a[i]->_boundsMatrix];
				if (a[i]->_v.flipped != a[i]->_superview->_v.flipped)
					[matrix scaleXBy:1.0 yBy:-1.0];
				}
			else
				if(a[i]->_v.isClip)
					{
					if (a[i]->_v.flipped != a[i]->_superview->_v.flipped)
						[matrix scaleXBy:1.0 yBy:-1.0];
					[matrix appendTransform:a[i]->_boundsMatrix];
			}		}
		else
			if(a[i]->_v.flipped != a[i]->_superview->_v.flipped)
				[matrix scaleXBy:1.0 yBy:-1.0];				// flip Y axis
	}	}

	return matrix;
}

- (NSAffineTransform*) _boundsMatrixFromSubview:(NSView*)subview
									toSuperview:(NSView*)superview
{
	NSView *view = subview;
	int c = 0, i = 0;
	NSAffineTransform *matrix = [NSAffineTransform transform];

	while (view && view != superview) 						// count the views
		{
		c++;
		view = view->_superview;
  		}
	{
	NSView *array[c];										// create an array
															// of views from
	view = subview;											// the subview up
	while (view && view != superview) 						// to the superview
		{
		array[i++] = view;
		view = view->_superview;							// concatenate the
  		}													// bounds matrices
	for (i = c - 1; i >= 0; i--)							// in reverse order  
		[matrix appendTransform:array[i]->_boundsMatrix];
	}

	return matrix;
}

- (NSPoint) convertPoint:(NSPoint)aPoint fromView:(NSView*)aView
{
	NSPoint new;
	NSAffineTransform *matrix;

	if (!_window)
		return NSZeroPoint;
	if (aView == self)
		return aPoint;

	if ((aView == nil) || [self isDescendantOf:aView]) 
		{
		if ((aView == nil) && ((aView = [_window contentView]) == self))
			return aPoint;

		matrix = [self _matrixFromSubview:self toSuperview:aView];
		[matrix invert];
		new = [matrix transformPoint:aPoint];
		}
	else 
		if ([aView isDescendantOf:self])
			{
			matrix = [self _matrixFromSubview:aView toSuperview:self];
			new = [matrix transformPoint:aPoint];
			}			// The views are not in the same hierarchy of views.
		else 			// Convert the point to window from the other's view
			{			// coordinates and then to our view coordinates.
			new = [aView convertPoint:aPoint toView:nil];
			new = [self convertPoint:new fromView:nil];
			}

	return new;
}

- (NSRect) convertRect:(NSRect)aRect fromView:(NSView *)aView
{
	NSRect r;

	if (aView && _window != [aView window])				// Must belong to the
		return NSZeroRect;								// same window

	r.origin = [self convertPoint:aRect.origin fromView:aView];
	r.size = [self convertSize:aRect.size fromView:aView];

	if (!aView)
		aView = [_window contentView];
	if (aView && _v.flipped != aView->_v.flipped)
		r.origin.y -= r.size.height;

	return r;
}

- (NSSize) convertSize:(NSSize)aSize fromView:(NSView *)aView
{
	NSSize new;
	NSAffineTransform *matrix;

	if (!aView)
		aView = [_window contentView];

	if ([self isDescendantOf:aView]) 
		{
		matrix = [self _boundsMatrixFromSubview:self toSuperview:aView];
		[matrix invert];
		new = [matrix transformSize:aSize];
		}
	else 
		if ([aView isDescendantOf:self]) 
			{
			matrix = [self _boundsMatrixFromSubview:aView toSuperview:self];
			new = [matrix transformSize:aSize];
			}			// The views are not in the same hierarchy of views.
		else 			// Convert the point to window from the other's view
			{			// coordinates and then to our view coordinates.
			new = [aView convertSize:aSize toView:nil];
			new = [self convertSize:new fromView:nil];
			}

	return new;
}

- (NSPoint) convertPoint:(NSPoint)aPoint toView:(NSView *)aView
{
	if (!aView)
		aView = [_window contentView];
	if (aView == self)
		return aPoint;

	return [aView convertPoint:aPoint fromView:self];
}

- (NSRect) convertRect:(NSRect)aRect toView:(NSView *)aView
{
	NSRect r;

	if (aView && _window != [aView window])				// Must belong to the 
		return NSZeroRect;								// same window

	if (!aView)
		aView = [_window contentView];

	r.origin = [self convertPoint:aRect.origin toView:aView];
	r.size = [self convertSize:aRect.size toView:aView];

	if (aView && _v.flipped != aView->_v.flipped)
		r.origin.y -= r.size.height;

	return r;
}

- (NSSize) convertSize:(NSSize)aSize toView:(NSView *)aView
{
	if (!aView)
		aView = [_window contentView];
	if (aView == self)
		return aSize;

	return [aView convertSize:aSize fromView:self];
}

- (void) setPostsFrameChangedNotifications:(BOOL)flag
{
	_v.postFrameChange = flag;
}

- (void) setPostsBoundsChangedNotifications:(BOOL)flag
{
	_v.postBoundsChange = flag;
}

- (void) viewWillStartLiveResize
{
	if (_v.inLiveResize)
		NSLog(@"SANITY **** %@ viewWillStartLiveResize is inLiveResize", self);
	if (!_v.inLiveResize)
      [_subviews makeObjectsPerformSelector:@selector(viewWillStartLiveResize)];
	_v.inLiveResize = 1;
}

- (void) viewDidEndLiveResize
{
	if (!_v.inLiveResize)
		NSLog(@"SANITY **** %@ viewDidEndLiveResize NOT inLiveResize", self);
	if (_v.inLiveResize)
		[_subviews makeObjectsPerformSelector:@selector(viewDidEndLiveResize)];
	_v.inLiveResize = 0;
}

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (!_v.isRotatedFromBase && _v.autoSizeSubviews)					 
		{												// resize subviews only
		int i, count = [_subviews count];				// if we are supposed
		id array[count];								// to and we have never
														// been rotated
		[_subviews getObjects:array];
		for (i = 0; i < count; i++)						// resize the subviews
			[array[i] resizeWithOldSuperviewSize: oldSize];
		}
}

- (void) resizeWithOldSuperviewSize:(NSSize)oldSize		
{
	float change, changePerOption;
	NSSize old_size = _frame.size;
	NSSize superViewFrameSize = [_superview frame].size;
	BOOL changedOrigin = NO;
	BOOL changedSize = NO;
	int options = 0;
														// do nothing if view 
	if(_v.autoresizingMask == NSViewNotSizable)			// is not resizable
		return;											
														// determine if and how
	if(_v.autoresizingMask & NSViewWidthSizable)		// the X axis can be
		options++;										// resized 
	if(_v.autoresizingMask & NSViewMinXMargin)				
		options++;
	if(_v.autoresizingMask & NSViewMaxXMargin)				
		options++;
														// adjust the X axis if
	if(options >= 1)									// any X options are
		{												// set in the mask
		change = superViewFrameSize.width - oldSize.width;
		changePerOption = floor(change / options);		
	
		if(_v.autoresizingMask & NSViewWidthSizable)		
			{		
			float oldFrameWidth = _frame.size.width;

			_frame.size.width += changePerOption;
			if (NSWidth(_frame) <= 0)
				{
				NSAssert((NSWidth(_frame) <= 0), @"View frame width <= 0!");
				NSLog(@"resizeWithOldSuperviewSize: View frame width <= 0!");
				NSWidth(_frame) = 0;
				}
			if(_v.isRotatedFromBase)
				{
				_bounds.size.width *= _frame.size.width / oldFrameWidth;
				_bounds.size.width = floor(_bounds.size.width);
				}
			else
				_bounds.size.width += changePerOption;
			changedSize = YES;
			}
		if(_v.autoresizingMask & NSViewMinXMargin)
			{
			_frame.origin.x += changePerOption;
			changedOrigin = YES;
		}	}
														// determine if and how 
	options = 0;										// the Y axis can be
	if(_v.autoresizingMask & NSViewHeightSizable)		// resized	
		options++;										
	if(_v.autoresizingMask & NSViewMinYMargin)				
		options++;
	if(_v.autoresizingMask & NSViewMaxYMargin)				
		options++;
														// adjust the Y axis if
	if(options >= 1)									// any Y options are  
		{												// set in the mask
		change = superViewFrameSize.height - oldSize.height;
		changePerOption = floor(change / options);		
	
		if(_v.autoresizingMask & NSViewHeightSizable)		
			{											
			float oldFrameHeight = _frame.size.height;

			_frame.size.height += changePerOption;
			if (NSHeight(_frame) <= 0)
				{
				NSAssert((NSHeight(_frame) <= 0), @"View frame height <= 0!");
				NSLog(@"resizeWithOldSuperviewSize: View frame height <= 0!");
				NSHeight(_frame) = 0;
				}
			if(_v.isRotatedFromBase)			
				{										
				_bounds.size.height *= _frame.size.height / oldFrameHeight;
				_bounds.size.height = floor(_bounds.size.height);
				}
			else
				_bounds.size.height += changePerOption;
			changedSize = YES;
			}
		if(_v.autoresizingMask & NSViewMinYMargin)
			{				
			_frame.origin.y += changePerOption;
			changedOrigin = YES;
		}	}

	if (changedSize && _v.isRotatedFromBase)	
		{
		float sx = _frame.size.width / _bounds.size.width;
		float sy = _frame.size.height / _bounds.size.height;

		[_boundsMatrix scaleTo:sx :sy];
		}
														
	if (changedSize || changedOrigin)
		{					 
		if(_superview)
			[self _frameChanged];
		[self resizeSubviewsWithOldSize: old_size];
		}
}
				// FIX ME s/return NO if view overrides -drawRect ...etc
- (BOOL) wantsUpdateLayer						{ return YES; }
- (BOOL) wantsLayer								{ return _v.wantsLayer; }
- (void) setWantsLayer:(BOOL)flag				{ _v.wantsLayer = flag; }
- (void) setLayer:(CALayer *)layer				{ ASSIGN(_layer, layer); }

- (void) display
{														// if opaque display
	if ((_window))										// else back up to
		{												// first opaque view.
		if (_v.wantsLayer && _layer)
			[_layer display];
		else if ([self isOpaque])
			[self displayRectIgnoringOpacity:[self visibleRect]];
		else											// convert bounds into
			{											// coords of first
			NSView *firstOpaque = [self opaqueAncestor];
			NSRect rect = [firstOpaque convertRect:_bounds fromView:self];

			[firstOpaque displayRectIgnoringOpacity:rect];
		}	}
}

- (void) displayRect:(NSRect)aRect						// if self is opaque
{														// display rect else
	if ([self isOpaque])								// back up to the first
		[self displayRectIgnoringOpacity: aRect];		// opaque view, convert
	else												// rect into its coords
		{												// and begin display
		NSView *firstOpaque = [self opaqueAncestor];
		NSRect rect = [firstOpaque convertRect:aRect fromView:self];

		[firstOpaque displayRectIgnoringOpacity:rect];
		}
}

- (void) displayIfNeeded								// if self is opaque
{														// display if needed
	if (_v.needsDisplay)								// else back up to a
		{												// view which is and
		if (_v.wantsLayer && _layer)
			[_layer display];
		else if ([self isOpaque]) 						// begin drawing there
			[self displayIfNeededIgnoringOpacity];
		else
			{
			if(NSWidth(_invalid) > 0 && NSHeight(_invalid) > 0)
				{
				NSView *firstOpaque = [self opaqueAncestor];
				NSRect r = [firstOpaque convertRect:_invalid fromView:self];

				[firstOpaque displayIfNeededInRectIgnoringOpacity:r];
		}	}	}
}

- (void) displayIfNeededInRect:(NSRect)aRect
{
	if(_v.needsDisplay)
		{
		NSRect intersect = NSIntersectionRect(_invalid, aRect);

		if (NSWidth(intersect) && NSHeight(intersect))
			{
			if ([self isOpaque])
				[self displayRectIgnoringOpacity: intersect];
			else
				{
				NSView *firstOpaque = [self opaqueAncestor];

				intersect = [firstOpaque convertRect:intersect fromView:self];
				[firstOpaque displayRectIgnoringOpacity:intersect];
		}	}	}
}				

- (void) displayIfNeededInRectIgnoringOpacity:(NSRect)aRect
{														// display self & subs
	if ((_window) && _v.needsDisplay && !_v.hidden)		// if need but contain
		{												// drawing to aRect
		NSRect intersect = NSIntersectionRect(_invalid, aRect);
		int i = 0, count;

		if (NSWidth(intersect) && NSHeight(intersect))
			{
			[self lockFocus];							// self has an invalid
			[self drawRect:intersect];					// rect that needs to
			[self unlockFocus];							// be displayed

			_v.needsDisplay = NO;
			_invalid = NSZeroRect;						// Reset invalid rect

			for (count = [_subviews count]; i < count; ++i)
				{
				NSView *subview = [_subviews objectAtIndex:i];

				if(subview->_v.needsDisplay)			
					{						// Display subview if it intersects
					NSRect rect, subviewFrame = subview->_frame;

					if (subview->_v.isRotatedOrScaledFromBase)
						[subview->_frameMatrix boundingRectFor:subviewFrame 
											   result:&subviewFrame];

					rect = NSIntersectionRect(intersect, subviewFrame);
					if (NSWidth(rect) > 0 && NSHeight(rect) > 0) 
						[subview displayRectIgnoringOpacity:rect];				
		}	}	}	}
}
												// display any part of self or
- (void) displayIfNeededIgnoringOpacity			// subs that has been marked as
{												// invalid with setNeedsDisplay
	if ((_window) && _v.needsDisplay && !_v.hidden)
		{
		int i = 0, count;

		if (NSWidth(_invalid) > 0 && NSHeight(_invalid) > 0)
			{
			[self lockFocus];					// self has an invalid rect
			[self drawRect:_invalid];			// that needs to be displayed
			[self unlockFocus];
								// display any subs that intersect invalidRect
			for (count = [_subviews count]; i < count; ++i) 	
				{
				NSView *subview = [_subviews objectAtIndex:i];	
				NSRect intersect, subviewFrame = subview->_frame;
								// If subview is rotated compute it's bounding
								// rect and use this instead of subview's frame
				if (subview->_v.isRotatedOrScaledFromBase)
					[subview->_frameMatrix boundingRectFor:subviewFrame 
										   result:&subviewFrame];
									// Display subview if it intersects
				intersect = NSIntersectionRect(_invalid, subviewFrame);
				if (NSWidth(intersect) && NSHeight(intersect)) 
					{				// Convert intersection to subview's coords
					intersect = [subview convertRect:intersect fromView:self];
					[subview displayRectIgnoringOpacity:intersect];
					}				// subview does not intersect invalidRect
				else				// but it may be marked as needing display
					if(subview->_v.needsDisplay)
						[subview displayIfNeededIgnoringOpacity];
				}
			_invalid = NSZeroRect;					
			}											// self does not need
		else											// display but a sub
			{											// view might 
			for (count = [_subviews count]; i < count; ++i) 	
				{												
				NSView *subview = [_subviews objectAtIndex:i];	
														// a subview contains a
				if(subview->_v.needsDisplay)			// view needing display
					[subview displayIfNeededIgnoringOpacity];				
			}	}												

		_v.needsDisplay = NO;								
		}
}														
														
- (void) displayRectIgnoringOpacity:(NSRect)rect
{
	int i, count;

	if(!_window || _v.hidden)							// do nothing if not in
		return;											// a window's heirarchy

	_v.needsDisplay = NO;
	_invalid = NSZeroRect;								// Reset invalid rect

	if([NSView focusView] == self)
		{
		[self drawRect:rect];							// if already focused &
		if(!_v.hasSubviews)								// have no subs, assume
			return;										// we are scrolling
		}
	else
		{
		[self lockFocus];
		[self drawRect:rect];
		[self unlockFocus];
		}

	for (i = 0, count = [_subviews count]; i < count; ++i)
		{												// display any subviews
    	NSView *subview = [_subviews objectAtIndex:i];	// that intersect rect
    	NSRect intersection, subviewFrame = subview->_frame;
								// If subview is rotated calc it's bounding
								// rect and use it instead of subview's frame
		if (subview->_v.isRotatedOrScaledFromBase)
      		[subview->_frameMatrix boundingRectFor:subviewFrame
								   result:&subviewFrame];
														// Display subview if
														// it intersects rect
    	intersection = NSIntersectionRect (rect, subviewFrame);
		if (NSWidth(intersection) && NSHeight(intersection))
			{						// Convert intersection to subview's coords
			intersection = [subview convertRect:intersection fromView:self];
      		[subview displayRectIgnoringOpacity:intersection];
    	}	}

	[_window flushWindow];
}	

- (void) drawRect:(NSRect)rect
{
	if((_superview == nil) && _window != nil)
		{												// fill background if
		[[_window backgroundColor] set];				// top most view
		NSRectFill(rect);
		if(_v.interfaceStyle)
			{
			[[NSColor blackColor] set];
			NSFrameRect(rect);
		}	}
}

- (NSRect) visibleRect									// return intersection
{														// between bounds and
	if (_superview)										// superview's visible
		{												// rect
		NSRect s = [self convertRect:[_superview visibleRect]
						 fromView:_superview];

		return NSIntersectionRect(s, _bounds);
		}

	return _bounds;										// if no super view
}														// bounds is visible

- (void) setNeedsDisplay:(BOOL)flag
{
	if ((_v.needsDisplay = flag))
		{
		NSView *firstOpaque = [self opaqueAncestor];	// convert rect into
														// coordinates of the
		if(firstOpaque != self)							// first opaque view
			{
			NSRect rect = [firstOpaque convertRect:_bounds fromView:self];
			NSView *currentView = _superview;

			_v.needsDisplay = YES;
			while (currentView && currentView != firstOpaque)
				{										// set needs display
				currentView->_v.needsDisplay = YES;		// flag all the way up
				currentView = currentView->_superview;	// the view heirarchy
				}
			[firstOpaque setNeedsDisplayInRect:rect];
			}
		else
			[self setNeedsDisplayInRect:_bounds];
		}
	else
		_invalid = NSZeroRect;
}

- (void) setNeedsDisplayInRect:(NSRect)rect				// not per spec FIX ME
{														// assumes opaque view
	NSView *currentView = _superview;

	_v.needsDisplay = YES;
	_invalid = NSUnionRect(_invalid, NSIntersectionRect(rect, _bounds));
	[_window setViewsNeedDisplay:YES];

	while (currentView) 								// set needs display
		{												// flag all the way up
		currentView->_v.needsDisplay = YES;				// the view heirarchy
		currentView = currentView->_superview;
		}
}

- (BOOL) autoscroll:(NSEvent *)event					// Auto Scrolling
{
	return (_superview && _v.clipped) ? [_superview autoscroll:event] : NO;
}

- (BOOL) scrollRectToVisible:(NSRect)aRect
{
	if(_superview && [_superview respondsToSelector:@selector(scrollToPoint:)])
		{
		NSRect v = [self visibleRect];
		NSPoint a = [_superview bounds].origin;
		BOOL shouldScroll = NO;

		if(NSWidth(v) == 0 && NSHeight(v) == 0)			
			return NO;

		if((NSWidth(_bounds) > NSWidth(v)) && !(NSMinX(v) <= NSMinX(aRect) 
				&& (NSMaxX(v) >= NSMaxX(aRect))))		
			{									// X dimension of aRect is not
			shouldScroll = YES;					// within visible rect
			if(aRect.origin.x < v.origin.x)
				a.x = aRect.origin.x;
			else
				a.x = v.origin.x + (NSMaxX(aRect) - NSMaxX(v));
			}

		if((NSHeight(_bounds) > NSHeight(v)) && !(NSMinY(v) <= NSMinY(aRect) 
				&& (NSMaxY(v) >= NSMaxY(aRect))))		
			{									// Y dimension of aRect is not
			shouldScroll = YES;					// within visible rect
			if(aRect.origin.y < v.origin.y)
				a.y = aRect.origin.y;
			else
				a.y = v.origin.y + (NSMaxY(aRect) - NSMaxY(v));
			}

		if(shouldScroll)
			{
			id cSuper = [_superview superview];
			NSClipView *clipView = (NSClipView *)_superview;

			DBLog(@"NSView scrollToPoint: (%1.2f, %1.2f)\n", a.x, a.y);

			a = [clipView constrainScrollPoint:a];
			[clipView scrollToPoint:a];

			if([cSuper respondsToSelector:@selector(reflectScrolledClipView:)])
				[(NSScrollView *)cSuper reflectScrolledClipView: clipView];

			return YES;
		}	}

	return NO;
}
									// allows subs to constrain scroll position
- (NSRect) adjustScroll:(NSRect)proposed					{ return proposed; }
- (void) reflectScrolledClipView:(NSClipView*)aClipView 	{}
- (void) scrollClipView:(NSClipView *)c toPoint:(NSPoint)p	{}
- (void) scrollPoint:(NSPoint)aPoint						{}
- (void) scrollRect:(NSRect)aRect by:(NSSize)delta			{}

- (id) viewWithTag:(int)aTag
{
	int i, count = [_subviews count];
	id v;

	for (i = 0; i < count; ++i)
		if ([(v = [_subviews objectAtIndex:i]) tag] == aTag)
			return v;

	return nil;
}

- (NSView*) hitTest:(NSPoint)aPoint					// aPoint is in superview's
{													// coordinates
	int i;
	NSPoint p;
	NSView *v;

	if(!NSMouseInRect(aPoint, _frame, _v.flipped))	// If not within our frame
		return nil;									// then immediately return

	p = [self convertPoint:aPoint fromView:_superview];
	for (i = [_subviews count] - 1; i >= 0; i--)	// Check our subviews
		if ((v = [[_subviews objectAtIndex:i] hitTest:p]))
			return v;
													// mouse is either in the
	return self;									// subview or within self
}

- (BOOL) mouse:(NSPoint)aPoint inRect:(NSRect)aRect
{
	return NSMouseInRect(aPoint, aRect, _v.flipped);
}

- (BOOL) acceptsFirstMouse:(NSEvent *)event					{ return NO; }
- (BOOL) shouldDelayWindowOrderingForEvent:(NSEvent*)event	{ return NO; }

- (BOOL) performKeyEquivalent:(NSEvent *)event
{
	int i, count = [_subviews count];

	for (i = 0; i < count; ++i)
		if ([[_subviews objectAtIndex:i] performKeyEquivalent: event])
			return YES;

	return NO;
}

- (void) rightMouseDown:(NSEvent *)event
{
	[NSApp rightMouseDown:event];
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[_window concludeDragOperation:sender];
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	return [_window draggingEntered:sender];
}

- (void) draggingExited:(id <NSDraggingInfo>)sender
{
	[_window draggingExited:sender];
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [_window draggingUpdated:sender];
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	return [_window performDragOperation:sender];
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [_window prepareForDragOperation:sender];
}

- (NSView*) nextValidKeyView
{ 
	return [_nextKeyView acceptsFirstResponder] ? _nextKeyView : nil;
}

- (NSView*) previousValidKeyView
{ 
	NSView *p = [self previousKeyView];

	return [p acceptsFirstResponder] ? p : nil;
}

- (NSView*) previousKeyView
{
	NSView *a = [_window initialFirstResponder];
	NSView *p = nil;

	while (a)
		{
		if (a == self)
			break;
		p = a;
		a = [a nextKeyView];
		}
													// value in p is not valid
	return (a) ? p : nil;							// if self was not found
}

- (void) setNextKeyView:(NSView *)next			{ _nextKeyView = next; }
- (NSView*) nextKeyView							{ return _nextKeyView; }
- (NSView*) superview							{ return _superview; }
- (NSWindow*) window							{ return _window; }
- (NSMutableArray*) subviews					{ return _subviews; }
- (unsigned int) autoresizingMask				{ return _v.autoresizingMask; }
- (void) setAutoresizesSubviews:(BOOL)flag		{ _v.autoSizeSubviews = flag; }
- (void) setAutoresizingMask:(unsigned int)mask	{ _v.autoresizingMask = mask; }
- (BOOL) autoresizesSubviews					{ return _v.autoSizeSubviews; }
- (BOOL) acceptsFirstResponder					{ return YES; }
- (BOOL) isOpaque								{ return (_superview == nil); }
- (BOOL) canDraw								{ return (_window != nil); }
- (BOOL) shouldDrawColor						{ return YES; }
- (BOOL) needsDisplay							{ return _v.needsDisplay;}
- (BOOL) isFlipped								{ return NO; }
- (BOOL) postsFrameChangedNotifications			{ return _v.postFrameChange; }
- (BOOL) postsBoundsChangedNotifications		{ return _v.postBoundsChange;}
- (BOOL) inLiveResize							{ return _v.inLiveResize; }
- (int) tag										{ return -1; }
- (NSInteger) gState							{ return _gState; }
- (void) setHidden:(BOOL)flag					{ _v.hidden = flag; }
- (BOOL) isHidden								{ return _v.hidden; }
- (void) viewDidHide		{ /* FIX ME called when view or ancestor is hidden */ }
- (void) viewDidUnhide		{ /* called when view or ancestor is set visible */ }

- (BOOL) isHiddenOrHasHiddenAncestor
{
	return (_v.hidden || [_superview isHiddenOrHasHiddenAncestor]);
}

- (NSRect) bounds					{ return _bounds; }
- (NSRect) frame					{ return _frame; }
- (float) boundsRotation			{ return [_boundsMatrix rotationAngle]; }
- (float) frameRotation				{ return [_frameMatrix rotationAngle]; }

- (void) setToolTip:(NSString *)string
{
	if(string)
		{
		if(!__toolTipsDict)
			__toolTipsDict = [NSMutableDictionary new];
		if(!_v.hasToolTip && _window)
			[self addTrackingRect:_bounds
				  owner:self
				  userData:NULL
				  assumeInside: NO];
		_v.hasToolTip = YES;
		[__toolTipsDict setObject:string forKey:self];
		}
	else
		_v.hasToolTip = NO;
}

- (NSString *) toolTip
{
	return _v.hasToolTip ? [__toolTipsDict objectForKey:self] : nil;
}

- (BOOL) _isMouseInToolTipOwnerView
{
	NSPoint location = [_window mouseLocationOutsideOfEventStream];
	NSPoint p = [self convertPoint:location fromView: nil];

	if((__toolTipOwnerView == self) && NSMouseInRect(p, _bounds, _v.flipped))
		{
		[NSTimer scheduledTimerWithTimeInterval: 0.5
				 target: self
				 selector: @selector(_isMouseInToolTipOwnerView)
				 userInfo: nil
				 repeats: NO];

		return YES;
		}

	if([__toolTipWindow isVisible])
		[__toolTipWindow orderOut:(__toolTipOwnerView = nil)];

	return NO;
}

- (void) _showToolTip:(id)sender
{
	NSEvent *e = [(NSTimer *)sender userInfo];

	if (__toolTipOwnerView == self && ![__toolTipWindow isVisible]
			&& (__toolTipSequenceCounter == [e eventNumber])
			&& [self _isMouseInToolTipOwnerView])
		{
		NSString *tip = [__toolTipsDict objectForKey:self];
		NSRect r;

		if(!__toolTipWindow)							// create shared 
			{											// tool tip window
			NSRect wRect = (NSRect){{0,3},{170,20}};
			NSColor *y;
			NSView *v;

			__toolTipText = [[NSText alloc] initWithFrame:wRect];
			y = [NSColor colorWithCalibratedRed:1 green:1 blue:0.5 alpha:1];
			[__toolTipText setDrawsBackground:NO];
			[__toolTipText setSelectable:NO];

			__toolTipWindow = [NSWindow alloc];
			[__toolTipWindow initWithContentRect:wRect
							 styleMask:NSBorderlessWindowMask
							 backing:NSBackingStoreBuffered	
							 defer:YES];
			[__toolTipWindow setBackgroundColor:y];
			v = [__toolTipWindow contentView];
			v->_v.interfaceStyle = YES;
			[v addSubview:__toolTipText];
			}

		r.origin = [_window convertBaseToScreen:[e locationInWindow]];
		r.origin = (NSPoint){NSMinX(r) + 5, NSMinY(r) + 10};

		[__toolTipText setString:tip];
		[__toolTipText sizeToFit];
		r.size = [__toolTipText frame].size;
		r.size.height += 5;
		NSWidth(r) = MIN(NSWidth(r), [[__toolTipText font] widthOfString:tip] + 10);
		[__toolTipWindow setFrame:r display:YES];
		[__toolTipWindow orderFront:nil];
		}
}

- (void) mouseEntered:(NSEvent *)event
{
	if (_v.hasToolTip)
		{
		if((__toolTipOwnerView != nil) && [__toolTipWindow isVisible])
			[__toolTipWindow orderOut: self];

		__toolTipSequenceCounter = __mouseMovedEventCounter - 1;

		[NSTimer scheduledTimerWithTimeInterval: 1.0
				 target: (__toolTipOwnerView = self)
				 selector: @selector(_showToolTip:)
				 userInfo: event
				 repeats: NO];
		}

	if(event)
		[super mouseEntered:event];
}

- (void) mouseExited:(NSEvent *)event
{
	if (__toolTipOwnerView == self)
		[__toolTipWindow orderOut:(__toolTipOwnerView = nil)];

	if(event)
		[super mouseExited:event];
}

- (void) addCursorRect:(NSRect)r cursor:(NSCursor *)anObject
{
	_TrackingRect *m = [_TrackingRect alloc];

	m->rect = [self convertRect:r toView:nil];
	m->tag = 0;
	m->owner = [anObject retain];
	m->userData = self;
	m->inside = YES;
	[[_window _cursorRects] addObject:[m autorelease]];
}

- (void) discardCursorRects
{
	NSMutableArray *cursorRects = [_window _cursorRects];
	id e = [cursorRects reverseObjectEnumerator];
	_TrackingRect *o;

	while ((o = [e nextObject]))
		if ((id)o->userData == self)
			[cursorRects removeObject: o];
}

- (void) resetCursorRects
{
	[_subviews makeObjectsPerformSelector:@selector(resetCursorRects)];
}

- (void) removeCursorRect:(NSRect)aRect cursor:(NSCursor *)anObject
{
	NSMutableArray *cursorRects = [_window _cursorRects];
	id e = [cursorRects reverseObjectEnumerator];
	_TrackingRect *o;

	while ((o = [e nextObject]))
		{
		NSCursor *c = (NSCursor *)o->owner;

		if (c == anObject)
			{
			[cursorRects removeObject: o];
			break;
		}	}
}

- (void) removeTrackingRect:(NSTrackingRectTag)tag
{
	NSMutableArray *trackingRects = [_window _trackingRects];
	int i, j = [trackingRects count];

	for (i = 0; i < j; ++i)
		{
		_TrackingRect *m = (_TrackingRect *)[trackingRects objectAtIndex:i];

		if (m->tag == tag)
			{
			[trackingRects removeObjectAtIndex:i];
			return;
		}	}
}

- (NSTrackingRectTag) addTrackingRect:(NSRect)aRect
								owner:(id)anObject
								userData:(void *)data
								assumeInside:(BOOL)flag
{
	NSMutableArray *trackingRects = [_window _trackingRects];
	_TrackingRect *m = [_TrackingRect alloc];

	m->rect = [self convertRect:aRect toView:nil];
	m->tag = (++__trackRectTag);
	m->owner = [anObject retain];
	m->userData = data;
	m->inside = flag;
	[trackingRects addObject: [m autorelease]];

	return m->tag;
}

- (void) encodeWithCoder:(NSCoder *)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeRect: _frame];
	[aCoder encodeRect: _bounds];
	[aCoder encodeConditionalObject:_superview];
	[aCoder encodeObject: _subviews];
	[aCoder encodeConditionalObject:_window];
	[aCoder encodeConditionalObject:_nextKeyView];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_v];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_frame = [aDecoder decodeRect];
	_bounds = [aDecoder decodeRect];
	_superview = [aDecoder decodeObject];
	_subviews = [aDecoder decodeObject];
	_window = [aDecoder decodeObject];
	_nextKeyView = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_v];
	
	return self;
}

@end /* NSView */
