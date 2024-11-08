/*
   NSCell.m

   Display contents and performs actions for a view.

   Copyright (C) 1998-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSFormatter.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/_CGFont.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSCell.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSView.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSControl.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSMenu.h>


#define CONTEXT		((CGContextRef)_CGContext())
#define ISFLIPPED	((CGContext *) cx)->_gs->isFlipped
#define FONT		((CGContext *) cx)->_gs->font
#define ASCENDER	((CGContext *) cx)->_gs->ascender
#define DESCENDER	((CGContext *) cx)->_gs->descender


// Class variables
static NSFont *__defaultFont = nil;
static NSColor *__borderedBackgroundColor = nil;
static NSCursor *__textCursor = nil;


@implementation NSCell

+ (void) initialize
{
	if (self == [NSCell class])
		{
		__defaultFont = [NSFont userFontOfSize:0];
		__borderedBackgroundColor = [NSColor lightGrayColor];
		__textCursor = [[NSCursor IBeamCursor] retain];
		}
}

+ (NSMenu *) defaultMenu					{ return nil; }
+ (BOOL) prefersTrackingUntilMouseUp		{ return NO; }

- (id) init									{ return [self initTextCell:@""]; }

- (id) initImageCell:(NSImage*)anImage
{
	_c.enabled = YES;
	_c.type = NSImageCellType;
	_c.imagePosition = NSImageOnly;
	_contents = [anImage retain];
	
	return self;
}

- (id) initTextCell:(NSString*)aString
{
	_c.enabled = YES;
	_c.type = NSTextCellType;
	_c.alignment = NSCenterTextAlignment;
	_font = [__defaultFont retain];
	_contents = [aString retain];

	return self;
}

- (void) dealloc
{
	[_font release],				_font = nil;
	[_contents release],			_contents = nil;
	[_representedObject release],	_representedObject = nil;
	[super dealloc];
}

- (id) copy
{
	NSCell *c = [isa alloc];

	c->_font = [_font retain];
	c->_contents = [_contents copy];
	c->_formatter = [_formatter retain];
	c->_c = _c;
	c->_controlView = _controlView;
	c->_representedObject = [_representedObject retain];
	
	return c;
}

- (NSSize) cellSize							// min size needed to display cell
{
	NSSize m;

	if (_c.type == NSTextCellType && _font)
		m = (NSSize){[_font widthOfString:_contents], [_font ascender]};
	else if (_c.type == NSImageCellType && _contents != nil)
		m = [_contents size];
	else
		m = NSZeroSize;

	if (_c.bezeled)
		m = (NSSize){m.width+12, m.height+12};
	else
		m = (_c.bordered) ? (NSSize){m.width+10, m.height+10}
						  : (NSSize){m.width+8,  m.height+6};
	return m;
}

- (NSSize) cellSizeForBounds:(NSRect)cb		// min size needed to display cell
{											// given cell bounds
	return NSIntersectionRect(cb, (NSRect){cb.origin, [self cellSize]}).size;
}

- (void) calcDrawInfo:(NSRect)aRect		// recalc cell drawing dimensions
{										// implemented by subclasses
}										// invoked by a control's calcsize

- (NSRect) drawingRectForBounds:(NSRect)rect
{
	if (!_c.bordered && !_c.bezeled)	// draw rect is inset on all sides to
		return rect;					// account for the cell's border type.

	return (_c.bezeled) ? NSInsetRect(rect, 2, 2) : NSInsetRect(rect, 1, 1);		
}

- (NSRect) imageRectForBounds:(NSRect)br
{
	return [self drawingRectForBounds: br];		// image drawing rect
}

- (NSRect) titleRectForBounds:(NSRect)br
{
	return [self drawingRectForBounds: br];		// title drawing rect
}

- (void) setImage:(NSImage *)anImage
{							 
	ASSIGN(_contents, anImage);		
	_c.type = NSImageCellType;
}

- (NSInteger) nextState
{
	return (_c.allowsMixedState) ? (_c.state + 1) % 3 : !_c.state;
}

- (NSImage *) image							{ return _contents; }
- (NSCellType) type							{ return _c.type; }
- (void) setType:(NSCellType)aType			{ _c.type = aType; }
- (void) setEnabled:(BOOL)flag				{ _c.enabled = flag; }
- (void) setAllowsMixedState:(BOOL)flag		{ _c.allowsMixedState = flag; }
- (void) setNextState						{ _c.state = [self nextState]; }
- (void) setState:(int)value				{ _c.state = value % 3; }
- (int) state								{ return _c.state == 2 ? -1 : _c.state; }
- (BOOL) allowsMixedState					{ return _c.allowsMixedState; }
- (BOOL) isEnabled							{ return _c.enabled; }
- (BOOL) acceptsFirstResponder				{ return _c.enabled && !_c.refusesFirstResponder; }
- (BOOL) refusesFirstResponder				{ return _c.refusesFirstResponder; }
- (BOOL) showsFirstResponder				{ return _c.showsFirstResponder; }
- (void) setShowsFirstResponder:(BOOL)flag	{ _c.showsFirstResponder = flag; }
- (void) setRefusesFirstResponder:(BOOL)f	{ _c.refusesFirstResponder = f; }
- (BOOL) hasValidObjectValue				{ return (_contents) ? YES : NO; }
- (void) setFormatter:(NSFormatter*)fmt		{ ASSIGN(_formatter, fmt); }
- (id) formatter							{ return _formatter; }
- (id) representedObject					{ return _representedObject; }
- (void) setRepresentedObject:(id)o			{ ASSIGN(_representedObject, o); }
- (void) setTitle:(NSString *)title			{ [self setStringValue:title]; }
- (NSString *) title						{ return [self stringValue]; }
- (NSString *) stringValue					{ return [_contents description]; }
- (double) doubleValue						{ return [_contents doubleValue]; }
- (float) floatValue;						{ return [_contents floatValue]; }
- (int) intValue							{ return [_contents intValue]; }
- (id) objectValue							{ return _contents; }

- (void) setObjectValue:(id)anObject
{
	if(_c.editing)
		[_controlView abortEditing];
	ASSIGN(_contents, anObject);
}

- (void) setDoubleValue:(double)aDouble
{
	if(_c.editing)
		[_controlView abortEditing];
	ASSIGN(_contents, [NSNumber numberWithDouble:aDouble]);
}

- (void) setFloatValue:(float)aFloat
{
	if(_c.editing)
		[_controlView abortEditing];
	ASSIGN(_contents, [NSNumber numberWithFloat:aFloat]);
}

- (void) setIntValue:(int)anInt
{
	if(_c.editing)
		[_controlView abortEditing];
	ASSIGN(_contents, [NSNumber numberWithInt:anInt]);
}

- (void) setStringValue:(NSString*)aString
{
	if(_c.editing)
		[_controlView abortEditing];
	ASSIGN(_contents, aString);
}

- (void) takeDoubleValueFrom:(id)sender						// Cell Interaction
{
	ASSIGN(_contents, [NSNumber numberWithDouble:[sender doubleValue]]);
}

- (void) takeFloatValueFrom:(id)sender
{
	ASSIGN(_contents, [NSNumber numberWithFloat:[sender floatValue]]);
}

- (void) takeIntValueFrom:(id)sender
{
	ASSIGN(_contents, [NSNumber numberWithInt:[sender intValue]]);
}

- (void) takeStringValueFrom:(id)sender
{
	ASSIGN(_contents, [sender stringValue]);
}

- (void) takeObjectValueFrom:(id)sender
{
	ASSIGN(_contents, [sender objectValue]);
}

- (void) setFont:(NSFont*)fontObject
{
	ASSIGN(_font, ((fontObject) ? fontObject : __defaultFont));
}

- (NSFont*) font								{ return _font; }
- (NSTextAlignment) alignment					{ return _c.alignment; }
- (void) setAlignment:(NSTextAlignment)mode		{ _c.alignment = mode; }
- (BOOL) isScrollable							{ return _c.scrollable; }
- (BOOL) wraps									{ return _c.wraps; }

- (void) setScrollable:(BOOL)flag
{
	if ((_c.scrollable = flag))
		_c.wraps = NO;
}

- (void) setWraps:(BOOL)flag
{
	if ((_c.wraps = flag))
		_c.scrollable = NO;
}

- (BOOL) isEditable					{ return _c.editable && !_c.editing; }
- (BOOL) isSelectable				{ return _c.selectable && !_c.editing; }

- (void) setEditable:(BOOL)flag
{
	if ((_c.editable = flag))							// If cell is editable
		_c.selectable = flag;							// it is selectable 
}														

- (void) setSelectable:(BOOL)flag
{
	if (!(_c.selectable = flag))						// If cell is not 
		_c.editable = NO;								// selectable then it's 
}														// not editable

- (NSText*) setUpFieldEditorAttributes:(NSText*)textObject
{
	if(_c.enabled)
		[textObject setTextColor:[NSColor blackColor]];
	else
		[textObject setTextColor:[NSColor darkGrayColor]];

	[textObject setFont:_font];
	[textObject setAlignment:_c.alignment];
	if (_formatter)
		[textObject setString:[_formatter stringForObjectValue:_contents]];
	else
		[textObject setString:[self stringValue]];
	[textObject setEditable:_c.editable];
	if (!_c.editable)
		[textObject setSelectable:_c.selectable];

	if (_c.drawsBackground || _c.bordered || (!_c.cellSubclass))
		{
		NSColor *color = (_c.drawsBackground) ? [(id)self backgroundColor]
											  : [NSColor whiteColor];
		[textObject setBackgroundColor:color];
		[textObject setDrawsBackground:YES];
		}
	else
		[textObject setDrawsBackground:NO];

	return textObject;
}

- (void) editWithFrame:(NSRect)aRect 					// edit the cell's text
				inView:(NSView*)controlView				// using the fieldEditr
				editor:(NSText*)textObject				// s/b called only from 
				delegate:(id)anObject					// a mouseDown
				event:(NSEvent*)event
{
	if (_c.type != NSTextCellType || _c.editing)
		return;

	[self selectWithFrame:aRect
		  inView:controlView
		  editor:textObject
		  delegate:anObject
		  start:(int)0
		  length:(int)0];

	[[controlView window] makeFirstResponder:textObject];
	[textObject mouseDown:event];
}
											// editing is complete, remove the
- (void) endEditing:(NSText*)textObject		// text obj	acting as field	editor
{											// from window's view heirarchy
	NSView *v;
	NSRect r;

	NSLog(@" NSCell endEditing ");
	_c.editing = NO;
	if (_c.scrollable)
		{
		NSClipView *c = (NSClipView *)[textObject superview];

		v = [c superview];
		r = [c frame];
		[c removeFromSuperview];
		}
	else
		{
		v = [textObject superview];
		r = [textObject frame];
		[textObject removeFromSuperview];
		}
	[textObject setDelegate:nil];
	[v displayRect:r];
}

- (void) selectWithFrame:(NSRect)aRect				// similar to editWithFrame
				  inView:(NSView*)controlView	 	// but can be invoked from
				  editor:(NSText*)textObject	 	// more than just mouseDown
				  delegate:(id)anObject
				  start:(int)selStart
				  length:(int)selLength
{
	if(controlView && textObject && _font && _c.type == NSTextCellType)
		{
		NSWindow *w;
		id c, spv;

		_c.editing = YES;
		if((w = [textObject window]))					// make sure field edit
			[w makeFirstResponder:w];					// is not in use

		if((spv = c = [textObject superview]))
			if(![c isKindOfClass:[NSClipView class]])
				c = nil;

		if(_c.scrollable)
			[textObject setFrame:(NSRect){{0,0},aRect.size}];
		else
			{
			if(c)
				{
				[c setDocumentView:nil];
				[c removeFromSuperview];
				[c release];
				}
			else if(spv)
				[textObject removeFromSuperview];

			[textObject setFrame:aRect];
			}

		_controlView = controlView;
		[textObject setDelegate:anObject];
		[self setUpFieldEditorAttributes:textObject];
		[textObject setSelectedRange:(NSRange){selStart, selLength}];

		if(_c.scrollable)
			{
			if(!c)
				{
				c = [[NSClipView alloc] initWithFrame:aRect];
				[c setDocumentView:textObject];
				}
			else
				{
				[c setBoundsOrigin:NSZeroPoint];
				[c setFrame:aRect];
				}
			[controlView addSubview:c];
			[textObject sizeToFit];
			}
		else
			[controlView addSubview:textObject];
		if (_contents)
			[controlView displayRect:aRect];
		}
}

- (BOOL) isEntryAcceptable:(NSString *)s
{
	NSString *e;
	id o;

	if (_formatter && _c.editing)
		return [_formatter getObjectValue:&o forString:s errorDescription:&e];

	return YES;
}

- (BOOL) isBezeled								{ return _c.bezeled; }
- (BOOL) isBordered								{ return _c.bordered; }
- (BOOL) isOpaque								{ return _c.bezeled; }
- (void) setBezeled:(BOOL)flag					{ _c.bezeled = flag; }
- (void) setBordered:(BOOL)flag					{ _c.bordered = flag; }

- (int) cellAttribute:(NSCellAttribute)aParameter
{
	switch (aParameter)									// FIX ME unfinished
		{
		case NSCellDisabled:	return (int)_c.enabled;
		case NSCellIsBordered:	return (int)_c.bordered;
		case NSCellHighlighted:	return (int)_c.highlighted;
		case NSCellState:		return (int)_c.state;
		case NSCellEditable:	return (int)_c.editable;
		default:				return -1;
		}
}

- (void) setCellAttribute:(NSCellAttribute)aParameter to:(int)value
{
	switch (aParameter)
		{
		case NSCellDisabled:	_c.enabled = (BOOL)value;		break;
		case NSCellIsBordered:	_c.bordered = (BOOL)value;		break;
		case NSCellHighlighted:	_c.highlighted = (BOOL)value;	break;
		case NSCellState:		_c.state = value % 3;			break;
		case NSCellEditable:	_c.editable = _c.selectable = (BOOL)value;
		default:
			break;
		}
}

- (void) highlight:(BOOL)lit							// Drawing the cell
		 withFrame:(NSRect)cellFrame						
		 inView:(NSView *)controlView					
{
	_c.highlighted = lit;
	[self drawWithFrame:cellFrame inView:controlView];
}											

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	if (_c.bezeled)
		{
		NSDrawWhiteBezel(cellFrame, cellFrame);
		cellFrame = NSInsetRect(cellFrame, 2, 2);
		}
	else if (_c.bordered)
		{
		[__borderedBackgroundColor set];
		NSRectFill(cellFrame);
		NSFrameRect(cellFrame);
		cellFrame = NSInsetRect(cellFrame, 1, 1);
		}

	if (_c.editing)
		return;

	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void) drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView
{
	if (!_contents)
		return;

	_controlView = controlView;					// cache for actionCell updates

	if (_c.type == NSTextCellType)
		{
		CGContextRef cx = CONTEXT;				// tableview requires focusview
		BOOL shouldUnClip = NO;
		float margin = 0;
		NSPoint point;
		float titleWidth;
		const char *s;
		int len;
												// do not set text color if we
		if(!_c.cellSubclass)					// are drawing for a subclass
			PSsetgray(_c.enabled ? NSBlack : NSDarkGray);

		if(_font != FONT)
			[_font set];

		if(_formatter)
			s = [[_formatter stringForObjectValue:_contents] cString];
		else
			s = [[_contents description] cString];
		len = strlen(s);
		titleWidth = _CGContextTextWidth(cx, (CGFontRef)_font, s, len);
												// calc y margin of the text
		if (!_c.wraps && NSHeight(frame) > (ASCENDER + DESCENDER) + 1)
			margin = floor((NSHeight(frame) - (ASCENDER + DESCENDER)) / 2);

		if (ISFLIPPED)
			point.y = NSMaxY(frame) - DESCENDER - margin;
		else
			point.y = NSMinY(frame) + margin + DESCENDER;

		switch (_c.alignment) 					// Determine x position of text
			{						 
			case NSLeftTextAlignment:	 		// ignore justified and natural
			case NSJustifiedTextAlignment:		// alignments
			case NSNaturalTextAlignment:
				point.x = frame.origin.x + 2;
				break;
			case NSRightTextAlignment:
				if (titleWidth < frame.size.width)
					point.x = NSMaxX(frame) - (2 + titleWidth);
				else
					point.x = frame.origin.x + 2;
				break;
			case NSCenterTextAlignment:
				if (titleWidth < frame.size.width)
					point.x = NSMinX(frame) - 1 + ((NSWidth(frame) - titleWidth) / 2.);
				else
					point.x = frame.origin.x + 2;
				break;
			}										 

		frame.origin.x = point.x;
		if ((titleWidth > (NSWidth(frame) - (point.x - NSMinX(frame))))
				|| (ASCENDER + DESCENDER) >= NSHeight(frame))
			{										// avoid clipping if title
			shouldUnClip = YES;						// fits within frame		
			CGContextSaveGState(cx);
			PSrectclip( NSMinX(frame), NSMinY(frame) + 1,
						NSWidth(frame) - 2, NSHeight(frame));
			}

		frame.origin.y = point.y;

		if (_c.secure)
			{
			char buffer[1024];

			s = (len > 1023) ? (char*)malloc(len+1) : buffer;
		
			memset((char*)s, '\0', len+1);
			memset((char*)s, '*', len);
			CGContextShowTextAtPoint(cx, NSMinX(frame), point.y, s, len);
			if (s != buffer)
				free((char*)s);
			}
		else
			{						// wrapping text field with excess content
			if (shouldUnClip && _c.wraps)
				{
				float lines = titleWidth / NSWidth(frame);
				int charsPerLine = (len / lines) - 1;
				int approxLines = lines + 1;
				const char *e = s + len;
				const char *p = s;
				char buf[charsPerLine+5];

				if (!ISFLIPPED)
					frame.origin.y = NSMaxY(frame) - (ASCENDER + DESCENDER) - margin - 1;
				memset(buf, 0, charsPerLine+5);
				while (approxLines-- && e > p)
					{
					int cpl = MIN(charsPerLine, e - p);
					int etc = 0;

					memcpy(buf, p, cpl);
					if (approxLines)						// don't frag last
						while (cpl-- > 0 && *(buf+cpl) != ' ');
					if (!ISFLIPPED && (NSMinY(frame) - (ASCENDER + DESCENDER) < 0))
						{
						while (cpl-- > 0 && etc++ < 3)		// text spills out
							*(buf+cpl) = '.';
						cpl += 3;
						}
					cpl++;

					CGContextShowTextAtPoint(cx, NSMinX(frame), NSMinY(frame), buf, cpl);

					if (ISFLIPPED)
						NSMinY(frame) += (ASCENDER + DESCENDER);
					else
						NSMinY(frame) -= (ASCENDER + DESCENDER);
					if ((!ISFLIPPED && NSMinY(frame) < 0))
						break;
					p += cpl;
					}
				}
			else
				CGContextShowTextAtPoint(cx, NSMinX(frame), point.y, s, len);
			}

		if (shouldUnClip)
			CGContextRestoreGState(cx);

		return;
		}

	if (_c.type == NSImageCellType)
		{
		NSSize size = [(NSImage *)_contents size];
		NSCompositingOperation op = (_c.highlighted) ? NSCompositeHighlight 
													 : NSCompositeSourceOver;
		if(NSWidth(frame) > size.width)						// center if needed
			NSMinX(frame) += (NSWidth(frame) - size.width) / 2.;
		if(NSHeight(frame) > size.height)
			NSMinY(frame) += (NSHeight(frame) - size.height) / 2.;

		[_contents compositeToPoint:frame.origin operation:op];	  
		}
}

- (NSView *) controlView						{ return _controlView; }
- (void) setHighlighted:(BOOL)flag				{ _c.highlighted = flag; }
- (BOOL) isHighlighted							{ return _c.highlighted; }
- (BOOL) isContinuous							{ return _c.continuous; }
- (void) setContinuous:(BOOL)flag				{ _c.continuous = flag; }
- (void) setTag:(int)anInt						{}
- (int) tag										{ return -1; }
- (void) setTarget:(id)anObject					{}			// Target / Action
- (void) setAction:(SEL)aSelector				{}
- (id) target									{ return nil; }
- (SEL) action									{ return NULL; }

- (int) sendActionOn:(int)mask
{
	unsigned int previousMask = 0;

	previousMask |= _c.continuous ? NSPeriodicMask : 0;
	previousMask |= _c.actOnMouseDown ? NSLeftMouseDownMask : 0;
	previousMask |= _c.dontActOnMouseUp ? 0 : NSLeftMouseUpMask;
	previousMask |= _c.actOnMouseDragged ? NSLeftMouseDraggedMask : 0;

	_c.continuous        = ((unsigned int)mask & NSPeriodicMask);
	_c.actOnMouseDown    = ((unsigned int)mask & NSLeftMouseDownMask);
	_c.actOnMouseDragged = ((unsigned int)mask & NSLeftMouseDraggedMask);
	_c.dontActOnMouseUp  = !((unsigned int)mask & NSLeftMouseUpMask);

	return previousMask;
}

- (void) performClick:(id)sender
{
	NSRect b;
	id target;
	SEL action;
	NSWindow *w;

	if (!_controlView && [sender isKindOfClass: [NSView class]])
		_controlView = sender;

	if (!_controlView || _c.editing || !(w = [_controlView window]))
		return;

	b = [_controlView bounds];
	[_controlView lockFocus];
	[self highlight:YES withFrame:b inView:_controlView];
	[w flushWindow];
	[_controlView unlockFocus];

	if ((action = [self action]) && (target = [self target]))
		{
		NS_DURING
			[(NSControl*)_controlView sendAction:action to:target];
		NS_HANDLER
			{
			[self setHighlighted:NO];
			[localException raise];
			}
		NS_ENDHANDLER
		}

	[self setHighlighted:NO];
	[_controlView setNeedsDisplayInRect:b];
}

- (int) mouseDownFlags							{ return 0; }
- (NSString *) keyEquivalent					{ return nil; }

- (void) getPeriodicDelay:(float *)delay interval:(float *)interval
{
	*delay = 0.2;
	*interval = 0.2;
}

- (BOOL) continueTracking:(NSPoint)lastPoint			// Tracking the Mouse
					   at:(NSPoint)currentPoint
					   inView:(NSView *)controlView
{
    return YES;
}

- (BOOL) startTrackingAt:(NSPoint)startPoint
				  inView:(NSView*)control				// If point is in view 
{														// start tracking
	return [control mouse:startPoint inRect:[control bounds]];
}

- (void) stopTracking:(NSPoint)lastPoint				// Implemented by subs
				   at:(NSPoint)stopPoint
				   inView:(NSView *)controlView
				   mouseIsUp:(BOOL)flag				
{
}

- (BOOL) trackMouse:(NSEvent *)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView *)controlView
			 untilMouseUp:(BOOL)flag
{
	NSDate *distantFuture = [NSDate distantFuture];
	NSPoint location = [event locationInWindow];
	NSPoint point = [controlView convertPoint: location fromView: nil];
	id target = [self target];
	SEL action = [self action];
	NSPoint last_point = point;
	BOOL mouseWentUp = NO;
	BOOL done = NO;
	int periodCount = 0;							// allows a forced update
	unsigned int mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSMouseMovedMask 
						| NSLeftMouseDraggedMask | NSRightMouseDraggedMask;

	if (![self startTrackingAt:point inView:controlView])
		return NO;

	if (![controlView mouse:point inRect:cellFrame]) 		 
		return NO;										// point is not in cell

	if (_c.actOnMouseDown && ([event type] == NSLeftMouseDown))
		[(NSControl*)controlView sendAction:action to:target];

	if (_c.continuous) 
		{
		float delay, interval;

		[self getPeriodicDelay:&delay interval:&interval];
		[NSEvent startPeriodicEventsAfterDelay:delay withPeriod:interval];
		mask |= NSPeriodicMask;
		}

	while (!done) 										// Get next mouse 
		{												// event until a mouse
		NSEventType t = 0;								// up is obtained
		BOOL pointIsInCell;

		event = [NSApp nextEventMatchingMask:mask
					   untilDate:distantFuture
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];

		if (event && (t = [event type]) != NSPeriodic || periodCount == 2)
			{
			last_point = point;

			if (periodCount == 2)				// safety check periodic events
				{								// in case mouse has left cell
				NSWindow *w = [controlView window];

				location = [w mouseLocationOutsideOfEventStream];
				point = [controlView convertPoint:location fromView:nil];
				}
			else
				{
				location = [event locationInWindow];
				point = [controlView convertPoint:location fromView:nil];
			}	}
		else									// if periodic cntr reaches 4
			periodCount++;						// a forced update of pointers'
												// position occurs
		if (![controlView mouse:point inRect:cellFrame]) 
			{
			pointIsInCell = NO;							// Do we return now or 
														// keep tracking?
			if (![[self class] prefersTrackingUntilMouseUp] && flag) 
				done = YES;
			}
		else 
			pointIsInCell = YES;						// Point is in cell

		if (!done)										// continue tracking?
			if (![self continueTracking:last_point at:point inView:controlView])
				done = YES;

		if (t == NSLeftMouseUp)					// Did mouse go up?
			{
			done = mouseWentUp = YES;
			_c.state = [self nextState];

			if (!(_c.dontActOnMouseUp))
				[(NSControl*)controlView sendAction:action to:target];
			}
		else
			{
			if (pointIsInCell && (((t == NSPeriodic) && (_c.continuous))
					|| (t == NSLeftMouseDragged && (_c.actOnMouseDragged))))
				[(NSControl *)controlView sendAction:action to:target];
		}	}

	[self stopTracking:last_point 						// Stop tracking mouse
		  at:point
		  inView:controlView
		  mouseIsUp:mouseWentUp];

	if (_c.continuous)
		[NSEvent stopPeriodicEvents];

	if (mouseWentUp && [controlView mouse:point inRect:cellFrame])
		return YES;										// YES if mouse went up
														// withing the cell
	[controlView setNeedsDisplayInRect:cellFrame];
														// Mouse did not go up
	return NO;											// within cell
}

- (void) resetCursorRect:(NSRect)cellFrame				// Managing the Cursor
				  inView:(NSView *)controlView
{
//	if(_c.selectable && _c.enabled && !_c.editing && _c.type == NSTextCellType)
//		[controlView addCursorRect:cellFrame cursor:__textCursor];
}

- (NSComparisonResult) compare:(id)otherCell			// Compare NSCell's
{
	return (self == otherCell) ? 1 : 0;
}

- (void) setMenu:(NSMenu *)menu				{ }
- (NSMenu *) menu							{ return nil; }

- (NSMenu *) menuForEvent:(NSEvent *)event
				   inRect:(NSRect)cellFrame
				   ofView:(NSView *)view
{
	[NSMenu popUpContextMenu:[view menu] withEvent:event forView:view];

	return [view menu];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeObject: _contents];
	[aCoder encodeObject: _font];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_c];
	[aCoder encodeConditionalObject: _controlView];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	_contents = [aDecoder decodeObject];
	_font = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_c];
	_controlView = [aDecoder decodeObject];

	return self;
}

@end
