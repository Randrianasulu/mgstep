/*
   NSForm.m

   Single column matrix of labeled text fields.

   Copyright (C) 1997-2016 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: March 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/NSForm.h>
#include <AppKit/NSFormCell.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSTextFieldCell.h>


// Class variables
static Class __formCellClass = Nil;


/* ****************************************************************************

		NSFormCell

** ***************************************************************************/

@implementation NSFormCell
										 
- (id) init						{ return [self initTextCell:@"Field:"]; }

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:@""]))
		{
		_c.bordered = YES;
		_c.bezeled = YES;
		[self setAlignment:NSLeftTextAlignment];
		_titleWidth = -1;
		_titleCell = [[NSCell alloc] initTextCell:aString];
		[_titleCell setAlignment:NSRightTextAlignment];
		}
	
	return self;
}

- (void) dealloc
{
	[_titleCell release];
	[super dealloc];
}

- (id) copy
{
	NSFormCell *c = [super copy];

	c->_titleWidth = _titleWidth;
	c->_titleCell = [_titleCell copy];

	return c;
}

- (BOOL) isOpaque
{
	return [super isOpaque] && [_titleCell isOpaque];
}

- (void) setTitle:(NSString*)aString
{
	[_titleCell setStringValue:aString];
}

- (void) setTitleAlignment:(NSTextAlignment)mode
{
	[_titleCell setAlignment:mode];
}

- (void) setTitleFont:(NSFont*)fontObject	{ [_titleCell setFont:fontObject];}
- (void) setTitleWidth:(float)width			{ _titleWidth = width; }
- (NSString*) title							{ return [_titleCell stringValue];}
- (NSTextAlignment) titleAlignment			{ return [_titleCell alignment]; }
- (NSFont*) titleFont						{ return [_titleCell font]; }

- (float) titleWidth
{
	if (_titleWidth < 0)
		return [[_titleCell font] widthOfString:[self title]];

	return _titleWidth;
}

- (float) titleWidth:(NSSize)aSize
{
	return 0;											// FIX ME
}

- (void) selectWithFrame:(NSRect)aRect					// similar to editWith-
				  inView:(NSView *)controlView	 		// Frame method but can
				  editor:(NSText *)textObject	 		// be called from more
				  delegate:(id)anObject	 				// than just mouseDown
				  start:(int)selStart	 
				  length:(int)selLength
{
	NSRect title, text;

	NSDivideRect(aRect, &title, &text, [self titleWidth] + 4, NSMinXEdge);

	[super selectWithFrame: NSInsetRect(text, 2, 2) 			
		   inView: controlView				
		   editor: textObject	
		   delegate: anObject
		   start: selStart	 
		   length: selLength];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect title, text;

	if (_c.editing)
		return;

	NSDivideRect(cellFrame, &title, &text, [self titleWidth] + 4, NSMinXEdge);
	[_titleCell drawWithFrame:title inView:controlView];

	[super drawWithFrame:text inView:controlView];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[aCoder encodeObject: _titleCell];
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	_titleCell = [aDecoder decodeObject];

	return [super initWithCoder:aDecoder];
}

@end  /* NSFormCell */

/* ****************************************************************************

		NSForm

** ***************************************************************************/

@implementation NSForm

+ (void) initialize
{
	if (self == [NSForm class]) 
		__formCellClass = [NSFormCell class];
}

+ (Class) cellClass							{ return __formCellClass; }
+ (void) setCellClass:(Class)cls			{ __formCellClass = cls; }

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [self initWithFrame:frameRect
					  mode:NSRadioModeMatrix
					  cellClass:__formCellClass
					  numberOfRows:0
					  numberOfColumns:1]))
		{
		_cellSize = (NSSize){100, 20};
		_interCell = (NSSize){1, 2};
		}

	return self;
}

- (NSFormCell*) addEntry:(NSString*)title	
{
	return [self insertEntry:title atIndex:[self numberOfRows]];
}

- (NSFormCell*) insertEntry:(NSString*)title atIndex:(int)index
{
	NSFormCell *new = [_cellPrototype copy];

	[new setTitle:title];
	[self insertRow:index];
	[self putCell:new atRow:index column:0];
	
	return new;
}

- (void) removeEntryAtIndex:(int)index		{ [self removeRow:index]; }

- (void) setBezeled:(BOOL)flag
{
	int i, count = [self numberOfRows];

	[_cellPrototype setBezeled:flag];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setBezeled:flag];
}

- (void) setBordered:(BOOL)flag
{
	int i, count = [self numberOfRows];

	[_cellPrototype setBordered:flag];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setBordered:flag];
}

- (void) setEntryWidth:(float)width
{
	NSSize size = {width, [self cellSize].height};

	[self setCellSize:size];
	[self sizeToCells];	
}

- (void) setInterlineSpacing:(float)spacing
{
	[self setIntercellSpacing:NSMakeSize(0, spacing)];
}

- (void) setTitleAlignment:(NSTextAlignment)aMode
{
	int i, count = [self numberOfRows];

	[_cellPrototype setTitleAlignment:aMode];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setTitleAlignment:aMode];
}

- (void) setTextAlignment:(int)aMode
{
	int i, count = [self numberOfRows];

	[_cellPrototype setAlignment:aMode];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setAlignment:aMode];
}

- (void) setTitleFont:(NSFont*)fontObject
{
	int i, count = [self numberOfRows];

	[_cellPrototype setTitleFont:fontObject];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setTitleFont:fontObject];
}

- (void) setTextFont:(NSFont*)fontObject
{
	int i, count = [self numberOfRows];

	[_cellPrototype setFont:fontObject];

	for (i = 0; i < count; i++)
		[[self cellAtRow:i column:0] setFont:fontObject];
}

- (int) indexOfCellWithTag:(int)aTag
{
	int i, count = [self numberOfRows];

	for (i = 0; i < count; i++)
		if ([[self cellAtRow:i column:0] tag] == aTag)
			return i;
	
	return -1;
}

- (int) indexOfSelectedItem			{ return [self selectedRow]; }
- (id) cellAtIndex:(int)index		{ return [self cellAtRow:index column:0]; }
- (void) selectTextAtIndex:(int)idx	{ [self selectTextAtRow:idx column:0]; }

- (void) drawCellAtIndex:(int)index
{
	id c = [self cellAtIndex:index];

	[c drawWithFrame:[self cellFrameAtRow:index column:0] inView:self];
}

- (void) drawCellAtRow:(int)row column:(int)column
{
	[self drawCellAtIndex:row];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	return [super initWithCoder:aDecoder];
}

@end  /* NSForm */
