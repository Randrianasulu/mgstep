/*
   NSOutlineView.m

   Outline view and related component classes

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Dec 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSIndexSet.h>

#include <AppKit/NSOutlineView.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSTextFieldCell.h>

static NSColor *__alternatingColor = nil;


/* ****************************************************************************

		NSOutlineView

** ***************************************************************************/

@implementation NSOutlineView

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]))
		{
//		ASSIGN(_backgroundColor, [NSColor whiteColor]);
//		_tv.alternatingRowColor = YES;
//		__alternatingColor =	[[NSColor selectedControlColor] set];
		__alternatingColor = [[NSColor colorWithCalibratedRed:.94
									   green:.94
									   blue:1.0
									   alpha:1.0] retain];
		}
	
	return self;
}

- (void) setFrame:(NSRect)frameRect
{
	[super setFrame: frameRect];
	[self tile];
}

- (void) setDelegate:(id <NSOutlineViewDelegate>)d
{
	NSNotificationCenter *n;
	SEL sl;

	if (_delegate == d)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSOutlineView##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(ColumnDidMove);
		IGNORE_(ColumnDidResize);
		IGNORE_(SelectionDidChange);
		IGNORE_(SelectionIsChanging);
		}

	if (!(_delegate = d))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(outlineView##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(outlineView##notif_name:) \
		   name:NSOutlineView##notif_name##Notification \
		   object:self]

	OBSERVE_(ColumnDidMove);
	OBSERVE_(ColumnDidResize);
	OBSERVE_(SelectionDidChange);
	OBSERVE_(SelectionIsChanging);

	sl = @selector(outlineView:willDisplayCell:forTableColumn:item:);
	_ov.delegateWillDisplayCell = [d respondsToSelector:sl];
	sl = @selector(outlineView:shouldEditTableColumn:item:);
	_ov.delegateShouldEditTableColumn = [d respondsToSelector:sl];
	sl = @selector(outlineView:shouldSelectTableColumn:);
	_ov.delegateShouldSelectTableColumn = [d respondsToSelector:sl];
	sl = @selector(selectionShouldChangeInOutlineView:);
	_ov.delegateSelectionShouldChangeInOutlineView = [d respondsToSelector:sl];

	sl = @selector(outlineView:shouldSelectItem:);
	_ov.delegateShouldSelectItem = [d respondsToSelector:sl];
	sl = @selector(outlineView:shouldExpandItem:);
	_ov.delegateShouldExpandItem = [d respondsToSelector:sl];
	sl = @selector(outlineView:shouldCollapseItem:);
	_ov.delegateShouldCollapseItem = [d respondsToSelector:sl];
}

- (void) setDataSource:(id <NSOutlineViewDataSource>)ds
{
	SEL a = @selector(outlineView:objectValueForTableColumn:byItem:);

	if (![ds respondsToSelector: @selector(outlineView:numberOfChildrenOfItem:)]
		  || ![ds respondsToSelector: @selector(outlineView:isItemExpandable:)]
		  || ![ds respondsToSelector: @selector(outlineView:child:ofItem:)]
		  || ![ds respondsToSelector: a])
		[NSException raise: NSInternalInconsistencyException
					 format: @"OutlineView's data source does not implement the\
								NSOutlineViewDataSource protocol."];
	_dataSource = ds;
	[self tile];
}

- (id <NSOutlineViewDataSource>) dataSource		{ return _dataSource; }
- (id <NSOutlineViewDelegate>) delegate			{ return _delegate; }

- (void) setOutlineTableColumn:(NSTableColumn *)outlineTableColumn	{}
- (NSTableColumn *) outlineTableColumn			{ return nil; }

- (BOOL) isExpandable:(id)item								{ return NO; }
- (BOOL) isItemExpanded:(id)item							{ return NO; }
- (void) expandItem:(id)item expandChildren:(BOOL)flag		{}
- (void) expandItem:(id)item								{}

- (void) collapseItem:(id)item collapseChildren:(BOOL)flag	{}
- (void) collapseItem:(id)item			{}

- (void) reloadItem:(id)item reloadChildren:(BOOL)flag	{}
- (void) reloadItem:(id)item			{}

- (id) parentForItem:(id)item;				{ return nil; }

- (id) itemAtRow:(NSInteger)row;			{ return nil; }
- (NSInteger) rowForItem:(id)item			{ return 0; }
- (NSInteger) levelForItem:(id)item			{ return 0; }
- (NSInteger) levelForRow:(NSInteger)row	{ return 0; }

- (void) setIndentationPerLevel:(CGFloat)level
{
	_indentationPerLevel = level;
}

- (CGFloat) indentationPerLevel			{ return _indentationPerLevel; }
- (BOOL) indentationMarkerFollowsCell	{ return _ov.indentationMarkerInCell; }

- (void) setIndentationMarkerFollowsCell:(BOOL)flag
{
	_ov.indentationMarkerInCell = flag;
}

- (NSRange) rowsInRect:(NSRect)rect 
{
	NSRange r = {0,0};

	if (NSWidth(rect) > 0 && NSHeight(rect) > 0)
		{
		int i, count = [_dataSource outlineView:self numberOfChildrenOfItem:nil];

		for (i = 0; i < count; i++)
			{
			float y = (_rowHeight + _intercellSpacing.height) * i;	// calc row
			NSRect rowRect = {0, y, NSWidth(_frame), _rowHeight};	// rect
			NSRect intersection = NSIntersectionRect(rowRect, rect);

			if (NSWidth(intersection) > 0 && NSHeight(intersection) > 0)
				{
				if (r.length == 0)
					r = (NSRange){i,1};
				else
					r.length++;
		}	}	}

	return r;
}

- (int) numberOfRows
{
	return [_dataSource outlineView:self numberOfChildrenOfItem:nil];
}

- (void) mouseDown:(NSEvent *)event
{
	if ([event clickCount] > 1)
		{											// double click	on
		if (_target && _doubleAction)				// double click
			[_target performSelector:_doubleAction withObject:self];

		return;
		}

	[super mouseDown: event];
}

- (void) tile 
{
	int rows = [_dataSource outlineView:self numberOfChildrenOfItem:nil];
	NSRect r = [self rectOfRow:rows - 1];
	NSRect c = [self rectOfColumn:[_tableColumns count] - 1];
												// limit column rect height in
	c.size.height = NSMaxY(r);					// case frame size has changed
	r.size.width = NSWidth(c);
	if (r.size.width == 0)
		r.size.width = NSWidth(_frame);
	if (c.size.width == 0)
		c.size.width = NSWidth(_frame);
	[super setFrame:NSUnionRect(r, c)];
	r = [_headerView frame];
	r.size.width = NSMaxX(c);
	[_headerView setFrame: r];
//	[_headerView resetCursorRects];
}

- (void) drawRect:(NSRect)rect
{
	NSRange rowRange = [self rowsInRect:rect];
	NSRect rowClipRect = [self rectOfRow: rowRange.location];
	int i, maxRowRange = NSMaxRange(rowRange);

	[_backgroundColor set];
	NSRectFill(rect);

	rowClipRect.origin.x = NSMinX(rect);
	rowClipRect.size.width = NSWidth(rect);
	for (i = rowRange.location; i < maxRowRange; i++)
		{
		if ([_selectedRows containsIndex: i])
			[self highlightSelectionInClipRect: rowClipRect];
		[self drawRow: i clipRect: rowClipRect];
		rowClipRect.origin.y += (_rowHeight + _intercellSpacing.height);
		}
}

- (void) drawRow:(int)row clipRect:(NSRect)rect
{
	int i, maxColRange;

	if (row == _editingRow)									// don't draw over
		return;												// field editor

	if(_cacheOrigin != NSMinX(rect) || (_cacheWidth != NSWidth(rect)))
		{
		_cacheOrigin = NSMinX(rect);						// cache col origin
		_cacheWidth = NSWidth(rect);						// and size info
		_columnRange = [self columnsInRect:rect];
		_cachedColOrigin = NSMinX([self rectOfColumn:_columnRange.location]);
		}

	maxColRange = NSMaxRange(_columnRange);
	rect.origin.x = _cachedColOrigin;

		id item = [_dataSource outlineView:self
							   child:row
							   ofItem:nil];
	for (i = _columnRange.location; i < maxColRange; i++)
		{
		NSTableColumn *col = [_tableColumns objectAtIndex:i];
//		NSTableDataCell *aCell = [col dataCell];
		NSCell *aCell = [col dataCell];
		id data = [_dataSource outlineView:self
							   objectValueForTableColumn:col
							   byItem:item];

if (row % 2 && _tv.alternatingRowColor)
	{
	[__alternatingColor set];
	NSRectFill(rect);
	}
		rect.size.width = col->_width;
		if(data)
			{
			[aCell setObjectValue:data];
NSLog(@"row %d col %d data: %@", row, i, data);

			if(_ov.delegateWillDisplayCell)
				[_delegate outlineView:self
						   willDisplayCell:aCell 
						   forTableColumn:col
						   item:item];

			if ([_selectedRows containsIndex: row] || [_selectedColumns containsIndex: i])
				[aCell highlight:YES withFrame:rect inView:self];
			else
				[aCell drawInteriorWithFrame:rect inView:self];
			}
		rect.origin.x = NSMaxX(rect) + _intercellSpacing.width;
		}
}

@end /* NSOutlineView */


NSString * NSFileTypeForHFSTypeCode(unsigned int hfsFileTypeCode)
{
	if (hfsFileTypeCode == kGenericFolderIcon /* 'fldr' */)
		return @"/";
	return @"";
}
