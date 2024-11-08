/*
   NSBox.m

   Box view that displays a border, title and contents.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSEnumerator.h>

#include <AppKit/NSBox.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSTextFieldCell.h>


@implementation NSBox

- (NSRect) _calcSizes
{
	NSRect r;
	NSSize title;
	NSSize border;
	float c = 10;

	_bx.needsTile = NO;

	switch (_bx.borderType)
		{
		case NSLineBorder: 	border = NSMakeSize(1,1);	break;
		case NSGrooveBorder:
		case NSBezelBorder: border = NSMakeSize(2,2);	break;
		case NSNoBorder:
		default:			border = NSZeroSize;		break;
		}

	_borderRect = _bounds;
	title = _bx.titlePosition == NSNoTitle ? NSZeroSize : [_titleCell cellSize];

	switch (_bx.titlePosition)
		{
		case NSNoTitle:				// Add the _offsets to border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
			break;

		case NSAboveTop:
			title.width += 4;				// Add spacer around title
			title.height += 1;
											// Adjust border rect by title cell
			_borderRect.size.height -= title.height + border.height;
			
											// Add _offsets to the border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
													// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2 + .5), 3);
			_titleRect.origin.x = _bounds.origin.x + c;
			_titleRect.origin.y = _bounds.origin.y + _borderRect.size.height
									+ border.height;
			break;

		case NSBelowTop:
			title.width += 4;					// Add spacer around title
			title.height += 1;
											// Add _offsets to the border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
												// Adjust by the title size
			r.size.height -= title.height + border.height;
												// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2 + .5), 3);
			_titleRect.origin.x = _borderRect.origin.x + c;
			_titleRect.origin.y = NSMaxY(_borderRect) - title.height
									- border.height;
			break;

		case NSAtTop:
			title.width += 4;						// Add spacer around title
			title.height += 1;
													// Adjust by the title size
			_borderRect.size.height -= (title.height / 2);
											// Add the _offsets to border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
													// Adjust by the title size
			r.size.height -= (title.height / 2);
													// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2  + .5), 3);
			_titleRect.origin.x = _borderRect.origin.x + c;
			_titleRect.origin.y = NSMaxY(_borderRect) - (title.height / 2);
			break;

		case NSAtBottom:
			title.width += 4;					// Add spacer around title
			title.height += 1;
												// Adjust by the title size
			_borderRect.origin.y += title.height / 2;
			_borderRect.size.height -= title.height / 2;
												// Add _offsets to border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
													// Adjust by the title size
			r.origin.y += (title.height / 2) + border.height;
			r.size.height -= (title.height / 2) + border.height;
													// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2 + .5), 3);
			_titleRect.origin.x = c;
			_titleRect.origin.y = 0;
			break;

		case NSBelowBottom:
			title.width += 4;						// Add spacer around title
			title.height += 1;
													// Adjust by the title
			_borderRect.origin.y += title.height + border.height;
			_borderRect.size.height -= title.height + border.height;
			
											// Add the _offsets to border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
													// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2 + .5), 3);
			_titleRect.origin.x = c;
			_titleRect.origin.y = 0;
			break;

		case NSAboveBottom:
			title.width += 4;				// Add spacer around title
			title.height += 1;
											// Add the _offsets to border rect
			r.origin.x = _borderRect.origin.x + _offsets.width + border.width;
			r.origin.y = _borderRect.origin.y + _offsets.height +border.height;
			r.size.width = _borderRect.size.width - (2 * _offsets.width)
							- (2 * border.width);
			r.size.height = _borderRect.size.height - (2 * _offsets.height)
							- (2 * border.height);
													// Adjust by the title size
			r.origin.y += title.height + border.height;
			r.size.height -= title.height + border.height;
													// center the title cell
//			c = MAX(((_bounds.size.width - title.width) / 2 + .5), 3);
			_titleRect.origin.x = _borderRect.origin.x + c;
			_titleRect.origin.y = _borderRect.origin.y + border.height;
			break;
		}

	_titleRect.size = title;
	
	return r;
}

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]))
		{
		_offsets = (NSSize){5,5};
		_borderRect = _bounds;
		_bx.borderType = NSLineBorder;
		_bx.needsTile = YES;
		_contentView = [[NSView alloc] initWithFrame:frameRect];
		[super addSubview:_contentView];
		[_contentView release];
		}

	return self;
}

- (void) dealloc
{
	[_titleCell release],	_titleCell = nil;
	[super dealloc];
}

- (void) setContentView:(NSView *)aView
{
	if (aView)
		{
		if (_contentView)
			[self replaceSubview:_contentView with:aView];
		else
			[super addSubview:_contentView];
		}
	else if (_contentView && ([_contentView superview] == self))
		[_contentView removeFromSuperview];
	_contentView = aView;
	_bx.needsTile = YES;
}

- (void) setTitle:(NSString *)aString
{
	if (!_titleCell)
		{
		_titleCell = [[NSTextFieldCell alloc] initTextCell:aString];
		[_titleCell setAlignment: NSCenterTextAlignment];
		[_titleCell setBezeled: NO];
		[_titleCell setEditable: NO];
		[_titleCell setBackgroundColor: [_window backgroundColor]];
		if (_bx.titlePosition == NSNoTitle)
			_bx.titlePosition = NSAtTop;
		}
	else
		[_titleCell setStringValue:aString];
	_bx.needsTile = YES;
	[self setNeedsDisplay: YES];
}

- (void) setTitleFont:(NSFont *)font
{
	if (!_titleCell)
		{
		[self setTitle: @"Title"];
		[_titleCell setFont:font];
		}
	else
		{
		[_titleCell setFont:font];
		_bx.needsTile = YES;
		[self setNeedsDisplay: YES];
		}
}

- (void) setTitlePosition:(NSTitlePosition)ps
{
	if (_bx.titlePosition != ps)
		{
		_bx.titlePosition = ps;
		
		if (_bx.titlePosition != NSNoTitle && !_titleCell)
			[self setTitle: @"Title"];
		else
			{
			_bx.needsTile = YES;
			[self setNeedsDisplay: YES];
		}	}
}

- (NSString *) title					{ return [_titleCell stringValue]; }
- (id) titleCell						{ return _titleCell; }
- (id) contentView						{ return _contentView; }
- (NSFont *) titleFont					{ return [_titleCell font]; }
- (NSRect) titleRect					{ return _titleRect; }
- (NSRect) borderRect					{ return _borderRect; }
- (NSSize) contentViewMargins			{ return _offsets; }
- (NSTitlePosition) titlePosition		{ return _bx.titlePosition; }
- (NSBorderType) borderType				{ return _bx.borderType; }

- (void) setBorderType:(NSBorderType)aType
{
	if (_bx.borderType != aType)
		{
		_bx.borderType = aType;
		_bx.needsTile = YES;
		[self setNeedsDisplay: YES];
		}
}

- (void) setContentViewMargins:(NSSize)offsetSize
{
	_offsets = offsetSize;
	_bx.needsTile = YES;
	[self setNeedsDisplay: YES];
}
														// Resizing the Box 
- (void) setFrameFromContentFrame:(NSRect)contentFrame
{												// First calc the sizes to see
	NSRect r = [self _calcSizes];				// how much we are off by
	NSRect f = [self frame];
												// Add difference to the frame
	f.size.width += (contentFrame.size.width - r.size.width);
	f.size.height += (contentFrame.size.height - r.size.height);
	
	[self setFrame: f];
}

- (void) sizeToFit
{
	NSRect r = NSZeroRect;
	id o, e = [[_contentView subviews] objectEnumerator];

	while ((o = [e nextObject]))
		{										// Loop through subviews and 
		NSRect f = [o frame];					// calculate rect to encompass
												// all
		if (f.origin.x < r.origin.x)
			r.origin.x = f.origin.x;
		if (f.origin.y < f.origin.y)
			r.origin.y = f.origin.y;
		if (NSMaxX(f) > NSMaxX(r))
			r.size.width = NSMaxX(f) - r.origin.x;
		if (NSMaxY(f) > NSMaxY(r))
			r.size.height = NSMaxY(f) - r.origin.y;
		}
	
	[self setFrameFromContentFrame: r];
}

- (void) resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize: oldSize];
	[_contentView setFrame: [self _calcSizes]];
}
														// NSView Hierarchy 
- (void) addSubview:(NSView *)aView
{													// Subviews get added to 
	[_contentView addSubview:aView];				// our content view's list
}

- (void) drawRect:(NSRect)rect							// Draw the box
{
	if (_bx.needsTile)
		[_contentView setFrame: [self _calcSizes]];

	switch(_bx.borderType)								// Draw the border
		{
		case NSLineBorder:
			[[_window backgroundColor] set];			// Fill inside of box
			NSRectFill(rect);
			[[NSColor blackColor] set];
			NSFrameRect(_borderRect);
			break;
		case NSBezelBorder:
			NSDrawGrayBezel(_borderRect, rect);
			break;
		case NSGrooveBorder:
			NSDrawGroove(_borderRect, rect);
		case NSNoBorder:
			break;
		}

	if (_bx.titlePosition != NSNoTitle)					// Draw the title
		{
		[_titleCell setBackgroundColor: [_window backgroundColor]];
		[_titleCell drawWithFrame: _titleRect inView: self];
		}
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeObject: _titleCell];
	[aCoder encodeObject: _contentView];
	[aCoder encodeSize: _offsets];
	[aCoder encodeRect: _borderRect];
	[aCoder encodeRect: _titleRect];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_bx];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];

	_titleCell = [aDecoder decodeObject];
	_contentView = [aDecoder decodeObject];
	_offsets = [aDecoder decodeSize];
	_borderRect = [aDecoder decodeRect];
	_titleRect = [aDecoder decodeRect];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_bx];

	return self;
}

@end
