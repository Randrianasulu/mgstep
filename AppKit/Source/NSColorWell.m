/*
   NSColorWell.m

   Color selection and display control.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/NSColor.h>
#include <AppKit/NSColorWell.h>
#include <AppKit/NSColorPanel.h>
#include <AppKit/NSEvent.h>


@implementation NSColorWell

- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame: frameRect]))
		{
		_cw.isBordered = YES;
		_color = [[NSColor whiteColor] retain];
		}
	
	return self;
}

- (void) dealloc
{
	[_color release];
	[super dealloc];
}

- (void) drawRect:(NSRect)rect
{
	float inset = 7;
	NSRect r;

	if (NSIntersectsRect(_bounds, rect) == NO)
		return;

	if (_cw.isBordered)
		{
		float grays[] = { NSBlack, NSBlack, NSWhite,	// Draw outer frame
						  NSWhite, NSDarkGray, NSDarkGray };

		r = NSDrawTiledRects(_bounds, rect, BUTTON_EDGES_NORMAL, grays, 6);

		if(_cw.isActive)
			[[NSColor whiteColor] set];
		else
			[[NSColor lightGrayColor] set];
    	}
	else
		{
		r = NSIntersectionRect(_bounds, rect);
		[[NSColor lightGrayColor] set];
		inset = 0;
		}

	NSRectFill(r);										// Fill background
	r = NSInsetRect(_bounds, inset, inset);
	NSDrawGrayBezel(r, rect);							// Draw inner frame
	r = NSInsetRect(r, 2, 2);

	[self drawWellInside: NSIntersectionRect(r, rect)];
}

- (void) drawWellInside:(NSRect)insideRect
{
	if (NSIsEmptyRect(insideRect))
		return;

	[_color set];
	NSRectFill(insideRect);
}

- (void) mouseDown:(NSEvent*)event
{
	NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];

	if (!NSMouseInRect(p, NSInsetRect(_bounds, 7, 7), NO))
		{													// click on border
		_cw.isActive = !(_cw.isActive);
		[self displayRectIgnoringOpacity:_bounds];

		if (_cw.isActive)
			{
			NSColorPanel *cp = [NSColorPanel sharedColorPanel];

			[cp setAction: @selector(takeColorFrom:)];
			[cp setTarget: self];	// FIX ME set target nil when panel closed
			[cp display];
			[cp makeKeyAndOrderFront:self];
		}	}
}

- (void) activate:(BOOL)exclusive							// Activation
{
	_cw.isActive = YES;
}

- (void) deactivate
{
	_cw.isActive = NO;
}

- (void) setColor:(NSColor*)color
{
	ASSIGN(_color, color);
	[self display];
}

- (NSColor*) color						{ return _color; }
- (BOOL) isActive						{ return _cw.isActive; }
- (BOOL) isOpaque						{ return _cw.isBordered; }
- (BOOL) isBordered						{ return _cw.isBordered; }

- (void) setBordered:(BOOL)bordered
{
	_cw.isBordered = bordered;
	[self display];
}

- (void) takeColorFrom:(id)sender
{
	if ([sender respondsToSelector:@selector(color)])
		{
		ASSIGN(_color, [sender color]);
		[self setNeedsDisplayInRect: _bounds];

		if ([_cell action] && [_cell target])
			[[_cell target] performSelector:[_cell action] withObject:self];
		}
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject: _color];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_cw];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];

	_color = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_cw];

	return self;
}

@end  /* NSColorWell */
