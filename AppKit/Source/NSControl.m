/*
   NSControl.m

   Abstract View control class

   Copyright (C) 1996-2021 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:    August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSGeometry.h> 

#include <AppKit/NSControl.h>
#include <AppKit/NSGraphicsContext.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSActionCell.h>
#include <AppKit/NSMenu.h>

// Class variables
static Class __controlCellClass = Nil;


@implementation NSControl

+ (void) initialize
{
	if ((self == [NSControl class]))
		__controlCellClass = [NSActionCell class];
}

+ (Class) cellClass						{ return __controlCellClass; }
+ (void) setCellClass:(Class)aClass		{ __controlCellClass = aClass; }

- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]) && !_cell)
		_cell = [[isa cellClass] new];

	_v.autoresizingMask = (NSViewMaxXMargin | NSViewMaxYMargin);

    return self;
}

- (void) dealloc
{
    [_cell release];										// release our cell
    [super dealloc];
}

- (void) setCell:(NSCell*)aCell	{ ASSIGN(_cell, aCell); }
- (id) cell						{ return _cell; }
- (id) selectedCell				{ return _cell; }
- (BOOL) isEnabled				{ return [[self selectedCell] isEnabled]; }
- (void) setEnabled:(BOOL)flag	{ [[self selectedCell] setEnabled:flag]; }
- (void) setNeedsDisplay		{ [super setNeedsDisplay:YES]; }
- (void) setFont:(NSFont*)font	{ [_cell setFont:font]; }
- (NSFont*) font				{ return (_cell) ? [_cell font] : nil;}
- (int) selectedTag				{ return [[self selectedCell] tag]; }
- (int) intValue				{ return [[self selectedCell] intValue]; }
- (float) floatValue			{ return [[self selectedCell] floatValue]; }
- (double) doubleValue			{ return [[self selectedCell] doubleValue]; }
- (NSString*) stringValue		{ return [[self selectedCell] stringValue]; }
- (id) objectValue				{ return [[self selectedCell] objectValue]; }
- (id) formatter				{ return [[self selectedCell] formatter]; }

- (void) setFormatter:(NSFormatter *)newFormatter;
{
	[[self selectedCell] setFormatter:newFormatter];
	[self setNeedsDisplay:YES];
}

- (void) setObjectValue:(id)anObject
{
	[[self selectedCell] setObjectValue:anObject];
	[self setNeedsDisplay:YES];
}

- (void) setStringValue:(NSString*)aString
{
	[[self selectedCell] setStringValue:aString];
	[self setNeedsDisplay:YES];
}

- (void) setDoubleValue:(double)aDouble
{
	[[self selectedCell] setDoubleValue:aDouble];
	[self setNeedsDisplay:YES];
}

- (void) setFloatValue:(float)aFloat
{
	[[self selectedCell] setFloatValue:aFloat];
	[self setNeedsDisplay:YES];
}

- (void) setIntValue:(int)anInt
{
	[[self selectedCell] setIntValue:anInt];
	[self setNeedsDisplay:YES];
}

- (void) takeDoubleValueFrom:(id)sender
{
	[[self selectedCell] takeDoubleValueFrom:sender];
	[self setNeedsDisplay:YES];
}

- (void) takeFloatValueFrom:(id)sender
{
	[[self selectedCell] takeFloatValueFrom:sender];
	[self setNeedsDisplay:YES];
}

- (void) takeIntValueFrom:(id)sender
{
	[[self selectedCell] takeIntValueFrom:sender];
	[self setNeedsDisplay:YES];
}

- (void) takeStringValueFrom:(id)sender
{
	[[self selectedCell] takeStringValueFrom:sender];
	[self setNeedsDisplay:YES];
}

- (void) takeObjectValueFrom:(id)sender
{
	[[self selectedCell] takeObjectValueFrom:sender];
	[self setNeedsDisplay:YES];
}

- (NSTextAlignment) alignment
{ 
	return (_cell != nil) ? [_cell alignment] : NSLeftTextAlignment;
}

- (void) setAlignment:(NSTextAlignment)mode
{
	if (_cell)
		{
		[_cell setAlignment:mode];
		[self setNeedsDisplay:YES];
		}
}

- (BOOL) abortEditing
{
	NSText *t;

	if ((t = [self currentEditor]))
		{
		[[self selectedCell] endEditing:t];
		[_window makeFirstResponder:self];

		return YES;
		}

	return NO;
}

- (NSText*) currentEditor
{
	NSText *t = [_window fieldEditor:NO forObject:_cell];

	return ([t delegate] == self && [_window firstResponder] == self) ? t :nil;
}

- (void) validateEditing			{ }					// FIX ME
- (void) sizeToFit					{ [self setFrameSize:[_cell cellSize]]; }
- (void) calcSize					{ [_cell calcDrawInfo: _bounds]; }

- (void) drawRect:(NSRect)rect
{
	[_cell drawWithFrame:_bounds inView:self]; 
}

- (void) drawCell:(NSCell*)aCell
{
	if (_cell == aCell)
		{
		[self lockFocus];
		[_cell drawWithFrame:_bounds inView:self];
		[self unlockFocus];
		}
}

- (void) drawCellInside:(NSCell*)aCell
{
	if (_cell == aCell)
		{
		[self lockFocus];
		[_cell drawInteriorWithFrame:_bounds inView:self];
		[self unlockFocus];
		}
}

- (void) selectCell:(NSCell*)aCell			
{ 
	if (_cell == aCell) 
		[_cell setState:1];
}

- (BOOL) sendAction:(SEL)action to:(id)target				// Target / Action
{
	if (action && target)
		return [NSApp sendAction:action to:target from:self];

	return NO;
}

- (void) performClick:(id)sender
{
	[self lockFocus];
	[_cell performClick: sender];
	[self unlockFocus];
}

- (BOOL) refusesFirstResponder
{
	return [_cell refusesFirstResponder];
}

- (void) setRefusesFirstResponder:(BOOL)flag
{
	[_cell setRefusesFirstResponder:flag];
}

- (void) setIgnoresMultiClick:(BOOL)flag	{}					// FIX ME
- (BOOL) ignoresMultiClick					{ return NO; }
- (BOOL) isContinuous						{ return [_cell isContinuous]; }
- (void) setContinuous:(BOOL)flag			{ [_cell setContinuous:flag]; }
- (void) updateCell:(NSCell*)aCell			{ [self setNeedsDisplay:YES]; }
- (void) updateCellInside:(NSCell*)aCell	{ [self setNeedsDisplay:YES]; }
- (void) setTag:(int)anInt					{ _tag = anInt; }
- (int) tag									{ return _tag; }
- (int) sendActionOn:(int)msk				{ return [_cell sendActionOn:msk];}
- (SEL) action								{ return [_cell action]; }
- (void) setAction:(SEL)aSelector			{ [_cell setAction:aSelector]; }
- (void) setTarget:(id)anObject				{ [_cell setTarget:anObject]; }
- (id) target								{ return [_cell target]; }

- (void) mouseDown:(NSEvent*)e
{
	DBLog(@"NSControl mouseDown\n");

	if (_v.hidden || ![self isEnabled])				// If we are not enabled
		return;										// then ignore the mouse

	[self lockFocus];

	for (;;) 										// loop until mouse goes up
		{
		NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];
		BOOL mouseUpInCell = NO;

		if (NSMouseInRect(p, _bounds, YES))
			{										// highlight cell
			[_cell highlight:YES withFrame:_bounds inView:self];
			[_window flushWindow];

			if ([_cell trackMouse:e inRect:_bounds ofView:self untilMouseUp:YES])
				mouseUpInCell = YES;

			[_cell highlight:NO withFrame:_bounds inView:self];
			[_window flushWindow];

			if (mouseUpInCell)
				break;
			}

		e = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
				   untilDate:[NSDate distantFuture]
				   inMode:NSEventTrackingRunLoopMode
				   dequeue:YES];

		if ([e type] == NSLeftMouseUp)				// done if mouse goes up
			break;
  		}

	[self unlockFocus];
}

- (void) rightMouseDown:(NSEvent *)event
{
	if (_cell && [_cell menu])
		{
		NSMenu *m = [_cell menuForEvent:event inRect:_bounds ofView:self];
		
		[[m menuCells] rightMouseDown:event];
		}
	else
		[super rightMouseDown:event];
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeValueOfObjCType: "i" at: &_tag];
	[aCoder encodeObject: _cell];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];
	
	[aDecoder decodeValueOfObjCType: "i" at: &_tag];
	_cell = [aDecoder decodeObject];
	
	return self;
}

@end  /* NSControl */
