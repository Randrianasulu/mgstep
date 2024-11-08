/*
   NSTableView.m

   NSTableView and related component classes

   Copyright (C) 1999-2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1999

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
#include <CoreFoundation/CFBase.h>

#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/Private/PSOperators.h>

#include <AppKit/NSTableView.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>


#define NOTE(n_name)    NSTableView##n_name##Notification
#define CNOTE(n_name)   NSControl##n_name##Notification

static NSImage *__tableHeaderImage = nil;
static NSImage *__tableHeaderImageH = nil;


/* ****************************************************************************

		NSTableHeaderCell

** ***************************************************************************/

@implementation NSTableHeaderCell

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:aString]))
		{
		_c.editable = NO;
		_c.selectable = NO;
		_c.alignment = NSCenterTextAlignment;
//		_c.type = NSImageCellType;
		_c.imagePosition = NSImageLeft;
		ASSIGN(_backgroundColor, [NSColor darkGrayColor]);
		}

	return self;
}

- (NSImage *) image						{ return _indicatorImage; }
- (void) setImage:(NSImage *)anImage	{ ASSIGN(_indicatorImage, anImage); }

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect rect;

	if (cellFrame.size.width <= 0 || cellFrame.size.height <= 0)
		return;

	_controlView = controlView;							// last view drawn in

	if (__tableHeaderImage)
		{
		NSImage *a = (_c.highlighted) ? __tableHeaderImageH : __tableHeaderImage;
		float grays[] = { NSDarkGray, NSDarkGray, NSBlack, NSWhite };
		NSRectEdge *edges = (NSRectEdge[]){ NSMaxXEdge, NSMinYEdge,
											NSMinXEdge, NSMinYEdge };
		[a drawInRect:cellFrame
		   fromRect:(NSRect){{0,0},cellFrame.size}
		   operation:NSCompositeSourceOver
		   fraction:1.0];

		cellFrame = NSDrawTiledRects(cellFrame, cellFrame, edges, grays, 4);
		}
	else
		{
		NSRectEdge *edges = BUTTON_EDGES_FLIPPED;
		float grays[] = { NSBlack, NSBlack,    NSWhite,
						  NSWhite, NSDarkGray, NSDarkGray };

		cellFrame = NSDrawTiledRects(cellFrame, cellFrame, edges, grays, 6);
		[_backgroundColor set];
		NSRectFill(cellFrame);
		}

	rect.origin = cellFrame.origin;

	if (_indicatorImage)		// NSImageLeft
		{
		NSSize imageSize = [_indicatorImage size];

		rect.size = imageSize;
		rect.size.width = imageSize.width + 4;
		rect.size.height = cellFrame.size.height;
		cellFrame.origin.x += (rect.size.width - imageSize.width) / 2;
		cellFrame.origin.y += (rect.size.height - imageSize.height) / 2;
		[_indicatorImage compositeToPoint:cellFrame.origin operation:NSCompositeCopy];
		rect.origin.x += rect.size.width;
		rect.size.width = cellFrame.size.width - rect.size.width;
		cellFrame = rect;
		}

	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

@end /* NSTableHeaderCell */

/* ****************************************************************************

		_TableDataCell

** ***************************************************************************/

@interface _TableDataCell : NSTextFieldCell
@end
@implementation _TableDataCell

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:aString]))
		{
		_c.editable = NO;
		_c.selectable = NO;
		_c.bezeled = NO;
		}

	return self;
}

- (void) dealloc
{
	_contents = nil;
	[super dealloc];
}

- (void) setObjectValue:(id)anObject 			{ _contents = anObject; }

- (void) highlight:(BOOL)lit
		 withFrame:(NSRect)cellFrame						
		 inView:(NSView *)controlView					
{
	_c.highlighted = lit;
	[self drawInteriorWithFrame:cellFrame inView:controlView];
	_c.highlighted = NO;
}											

@end /* _TableDataCell */

/* ****************************************************************************

		NSTableHeaderView

** ***************************************************************************/

@implementation NSTableHeaderView

- (id) initWithFrame:(NSRect)frameRect
{
	_draggedColumn = _clickedColumn = -1;

	return [super initWithFrame:frameRect];
}

- (void) dealloc
{
	[_tableView release];

	[super dealloc];
}

- (void) mouseDown:(NSEvent *)event
{
	NSEventType eventType;
	NSPoint current = [event locationInWindow];
	NSPoint p = [self convertPoint:current fromView:nil];
	NSPoint previous = current;
	NSInteger col = [_tableView columnAtPoint:p];
	NSDate *distantFuture = [NSDate distantFuture];
	NSRect c = [self visibleRect];
	BOOL scrolled = NO;
	BOOL resizing = (col == NSNotFound
				|| [NSCursor currentCursor] == [NSCursor resizeCursor]);

	if ((resizing && ![_tableView allowsColumnResizing])
			|| (!resizing && ![_tableView allowsColumnReordering]))
		return;

	[NSEvent startPeriodicEventsAfterDelay:0.05 withPeriod:0.05];
	[self lockFocus];

	if (resizing)
		{
		NSRect u = {0};
		NSRect t, d = (NSRect){{0,0},{2,1}};
		BOOL resizable;
		NSPoint o = p;
		NSTableColumn *column;
		float minWidth, maxWidth;
		NSRect f = [_tableView visibleRect];

		c.size.height = NSMaxY(c) + NSHeight(f);
		PSinitclip();
		NSRectClip(c);
		[[NSColor lightGrayColor] set];
		NSMinX(u) = -1;

		o.x -= [_tableView intercellSpacing].width;
		while((col = [_tableView columnAtPoint:o]) == NSNotFound && o.x > 0)
			o.x -= 1;

		if(col == NSNotFound)
			[NSException raise: NSInternalInconsistencyException 
						 format: @"Unable to determine column to be resized"];

		column = [[_tableView tableColumns] objectAtIndex:col];
		t = [_tableView rectOfColumn:col];

		if((resizable = [column isResizable]))
			{
			minWidth = [column minWidth];
			maxWidth = [column maxWidth];
			_highCell = nil;
			}

		while ((eventType = [event type]) != NSLeftMouseUp) 
			{
			if (eventType != NSPeriodic)
				current = [event locationInWindow];
			else
				{
				if (current.x != previous.x || scrolled) 
					{
					NSPoint p = [self convertPoint:current fromView:nil];
	
					if(resizable)
						{
						float delta = p.x - NSMinX(t);
	
						if(delta < minWidth)
							p.x = NSMinX(t) + minWidth;
						else
							if(delta > maxWidth)
								p.x = NSMinX(t) + maxWidth;
						}
					else
						p.x = NSMaxX(t);
	
					if(NSMinX(u) >= 0)
						NSRectFillUsingOperation(u, NSCompositeXOR);
					d.origin.x = p.x;
					d.origin.y = f.origin.y;
					if ((scrolled = [_tableView scrollRectToVisible:d]))
						{
						[self scrollRectToVisible:(NSRect){{p.x,0},d.size}];
						[[NSColor lightGrayColor] set];
						}
	
					u = (NSRect){{p.x,0},{2,NSHeight(c)}};
					NSRectFillUsingOperation(u, NSCompositeXOR);
					[_window flushWindow];
				}	}

			event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
						   untilDate:distantFuture 
						   inMode:NSEventTrackingRunLoopMode
						   dequeue:YES];
			}
	
		[column setWidth:(NSMinX(u) - NSMinX(t))];
		DBLog(@"col %d setWidth: %f\n", col, (NSMinX(u) - NSMinX(t)));
		c = [self visibleRect];
		c.size.width = c.size.width - (NSMinX(t) - NSMinX(c));
		NSMinX(c) = NSMinX(t);
		[self drawRect:c];

		[_tableView lockFocus];
		f.origin.x = c.origin.x;
		f.size.width = c.size.width;
		[_tableView drawRect:f];
		[_tableView unlockFocus];
		[NSCursor pop];
		}
	else
		{
		NSPoint lastPoint = p;
		NSTableColumn *column = [[_tableView tableColumns] objectAtIndex:col];
		NSTableHeaderCell *headerCell = [column headerCell];
		NSRect h = [self headerRectOfColumn:col];
		NSRect oldRect = h;
		NSRect cRepBounds = {0};
		int    cRepGState;
		int    colUnder = -1;
		NSColor *tableBackground = [_tableView backgroundColor];
		float intercellWidth = [_tableView intercellSpacing].width;
		BOOL wasSelected;
		BOOL movedColumn = NO;
		NSRect t = [_tableView visibleRect];
		NSRect u = [_tableView rectOfColumn:col];
		NSRect f = u;

		_draggedColumn = _clickedColumn = col;

		if (!(wasSelected = [_tableView isColumnSelected:col]))
			{
			_highRect.size.width += 2;
			if (_highCell)
				[_highCell highlight:NO withFrame:_highRect inView:self];
			_highCell = headerCell;
			_highRect = h;
			[headerCell highlight:YES withFrame:h inView:self];

			[_tableView selectColumn:col byExtendingSelection:NO];
			[_tableView displayIfNeededInRect:t];
			}
//		else
//			[headerCell highlight:NO withFrame:h inView:self];

		c.size.height = NSMaxY(c) + NSHeight(t);		// clip to scrollview's
		PSinitclip();
		NSRectClip(c);									// document rect 
		u.size.height = f.size.height = NSHeight(c);

		while ((eventType = [event type]) != NSLeftMouseUp)
			{
			if (eventType != NSPeriodic)
				current = [event locationInWindow];
			else
				{
				if (current.x != previous.x || scrolled) 
					{
					NSPoint p = [self convertPoint:current fromView:nil];
					float delta = p.x - lastPoint.x;
					NSRect d = (NSRect){{0,0},{2,1}};

					if(!_headerDragImage)				// lock focus / render
						{								// into image cache
						NSColor *color = [headerCell backgroundColor];
								 
						cRepBounds = (NSRect){{0,0},u.size};
						_headerDragImage = [NSImage alloc];
						[_headerDragImage initWithSize:u.size];
						[_headerDragImage lockFocusOnRepresentation:nil];
						cRepGState = [[NSView focusView] gState];
						NSMinY(u) = NSMinY(t);
						PStranslate(-NSMinX(u), NSHeight(_frame) - NSMinY(u));
						[_tableView drawRect:u];
						PStranslate(0, -(NSHeight(_frame) - NSMinY(u)));

						[headerCell setBackgroundColor:[NSColor blackColor]];
						[headerCell drawWithFrame:h inView:self];
						[headerCell setBackgroundColor:color];

						PStranslate(NSMinX(u), 0);
						[_headerDragImage unlockFocus];
						[_tableView deselectColumn:col];
						movedColumn = YES;
						[[NSCursor dragCopyCursor] set];
						}

					previous = current;
					NSMinX(h) += delta;
					NSMinX(h) = MAX(0, NSMinX(h));			// limit movement
					if(NSMaxX(h) > NSWidth(_bounds))		// to view bounds
						NSMinX(h) = NSWidth(_bounds) - NSWidth(h);
	
					if (NSMinX(h) != NSMinX(oldRect) || scrolled) 
						{
						if(delta < 0)
							{									// moving left
							if((NSMinX(h) < NSMinX(u)) || (colUnder == -1))
								col = [_tableView columnAtPoint:h.origin];
							}
						else
							{									// moving right
							NSPoint m = {NSMaxX(h), NSMinY(h)};
						
							if((m.x > NSMaxX(u)) || (colUnder == -1))
								col = [_tableView columnAtPoint:m];
							}
												// move columns if needed and
						if(col != NSNotFound)	// not in between columns
							{
							if(col != colUnder)
								{
								if(col > _draggedColumn + 1)
									col = _draggedColumn + 1;
								else
									if(col < _draggedColumn - 1)
										col = _draggedColumn - 1;
								colUnder = col;
								u = [self headerRectOfColumn:col];
								}
							
							if(delta < 0)						// moving left
								{
								if(NSMinX(h) < NSMidX(u))
									{
									[_tableView moveColumn:_draggedColumn 
												toColumn:col];
									oldRect = NSUnionRect(oldRect, u);
									oldRect = NSUnionRect(oldRect, f);
									_draggedColumn = col;
									f = [_tableView rectOfColumn:col];
								}	}
							else								// moving right
								{
								float maxX = NSMaxX(h);
							
								if(maxX > NSMidX(u))
									{
									[_tableView moveColumn:_draggedColumn 
												toColumn:col];
									oldRect = NSUnionRect(oldRect, u);
									oldRect = NSUnionRect(oldRect, f);
									_draggedColumn = col;
									f = [_tableView rectOfColumn:col];
							}	}	}
	
						t.origin.x = oldRect.origin.x;
						oldRect.size.width += intercellWidth;
						t.size.width = oldRect.size.width;
	
						d.origin.x = p.x;
						d.origin.y = t.origin.y;
						if ((scrolled = [_tableView scrollRectToVisible:d]))
						   [self scrollRectToVisible:(NSRect){{p.x,0},d.size}];
	
						[self drawRect:oldRect];

						[_tableView lockFocus];
						  {
						  NSRect vr =	[_tableView visibleRect];

						  vr = NSUnionRect(oldRect, vr);
						  [_tableView drawRect: vr];
						  }
						[tableBackground set];
						NSRectFill(f);
						[_tableView unlockFocus];
	
						NSCopyBits(cRepGState, cRepBounds, h.origin);
	
						NSMinX(oldRect) = NSMinX(h);
						NSWidth(oldRect) = NSWidth(h);
						[_window flushWindow];
						lastPoint = p;
				}	}	}
	
			event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
						   untilDate:distantFuture 
						   inMode:NSEventTrackingRunLoopMode
						   dequeue:YES];
			}
	
		if (movedColumn)
			{
			if (wasSelected)
				{
				[_tableView selectColumn:_draggedColumn byExtendingSelection:NO];
				_highRect = [self headerRectOfColumn:_draggedColumn];
				}
			else
				{
				_highCell = nil;		// invalidate highlighted cell cache
				[headerCell highlight:NO withFrame:h inView:self];
				}
			[NSNotificationCenter post:NOTE(ColumnDidMove) object:_tableView];
			[[NSCursor arrowCursor] set];
			}
		else
			{
			id dl = [_tableView delegate];
			SEL sel = @selector(tableView:mouseDownInHeaderOfTableColumn:);

			if (dl && [dl respondsToSelector: sel])
				[dl tableView:_tableView mouseDownInHeaderOfTableColumn:column];

			if (!wasSelected)
				[_tableView selectColumn:col byExtendingSelection:NO];
			else
				{
				[_tableView deselectColumn:col];
				[headerCell highlight:NO withFrame:h inView:self];
				}
			}

		oldRect = NSUnionRect(oldRect, [self headerRectOfColumn:_draggedColumn]);
		_draggedColumn = -1;
		[self drawRect:oldRect];
	
		if (movedColumn)
			[_tableView setNeedsDisplay:YES];

		ASSIGN(_headerDragImage, nil);
		}

	[_window flushWindow];
	[self unlockFocus];
	[NSEvent stopPeriodicEvents];
	[_window invalidateCursorRectsForView:self];
}

- (void) drawRect:(NSRect)rect		
{
	if (NSWidth(rect) > 0 && NSHeight(rect) > 0)
		{
		NSArray *tableColumns = [_tableView tableColumns];
		int i, count = [tableColumns count];
		NSTableColumn *colArray[count];
		NSRect h = _bounds, aRect;
		float max_X = NSMaxX(rect);
		float intercellWidth = [_tableView intercellSpacing].width;

		[[_tableView backgroundColor] set];
		NSRectFill(rect);

		[tableColumns getObjects:colArray];
		for (i = 0; i < count; i++)
			{
			h.size.width = colArray[i]->_width + intercellWidth;

			if(i != _draggedColumn)
				{
				aRect = NSIntersectionRect(h, rect);
	
				if (NSWidth(aRect) > 0)
					[[colArray[i] headerCell] drawWithFrame:h inView:self];
				else
					if (NSMinX(h) > max_X)
						return;
				}
			h.origin.x += h.size.width;
		}	}
}

- (NSRect) headerRectOfColumn:(int)column	  
{
	NSRect h = [_tableView rectOfColumn:column];

	return (NSRect){{NSMinX(h),NSMinY(_bounds)},{NSWidth(h),NSHeight(_bounds)}};
}

- (void) resetCursorRects
{
	NSRange columnRange = [_tableView columnsInRect:[self visibleRect]];
	NSArray *tableColumns = [_tableView tableColumns];
	int i, count = [tableColumns count];
	NSTableColumn *colArray[count];
	NSCursor *resize = [NSCursor resizeCursor];
	float intercellWidth = [_tableView intercellSpacing].width;
	NSRect r = (NSRect){{0,0}, {MAX(1, intercellWidth), NSHeight(_frame)}};

	[tableColumns getObjects:colArray];
	count = NSMaxRange(columnRange);
	[self discardCursorRects];
	for (i = 0; i < count; i++)
		{
		NSMinX(r) += colArray[i]->_width;
		if(i >= columnRange.location)
			[self addCursorRect:r cursor:resize];
		NSMinX(r) += intercellWidth;
		}
}

- (void) _resetClickedHeaderCell
{
	if (_clickedColumn >= 0)
		{
		NSArray *a = [_tableView tableColumns];
		NSTableColumn *column = [a objectAtIndex:_clickedColumn];
		NSTableHeaderCell *headerCell = [column headerCell];
		NSRect h = [self headerRectOfColumn:_clickedColumn];

		_clickedColumn = -1;
		[self lockFocus];
		h.size.width += 2;		// FIX ME
		[headerCell highlight:NO withFrame:h inView:self];
		[_window flushWindow];
		[self unlockFocus];
		}
}

- (int) columnAtPoint:(NSPoint)p
{
	return [_tableView columnAtPoint:p];
}

- (void) setTableView:(NSTableView*)tview	{ ASSIGN(_tableView, tview);}
- (NSTableView*) tableView					{ return _tableView; }
- (float) draggedDistance					{ return _draggedDistance; }
- (int) draggedColumn						{ return _draggedColumn; }
- (int) resizedColumn						{ return _resizedColumn; }
- (BOOL) isFlipped							{ return YES; }
- (BOOL) isOpaque							{ return YES; }				
- (BOOL) acceptsFirstResponder				{ return YES; }

@end /* NSTableHeaderView */

/* ****************************************************************************

		NSTableColumn

** ***************************************************************************/

@implementation NSTableColumn

- (id) initWithIdentifier:(id)identifier			
{
	_identifier = [identifier retain];
	_headerCell = [NSTableHeaderCell new];
	_dataCell = [_TableDataCell new];
	_maxWidth = 9999;

	return self;
}

- (void) dealloc
{
	[_identifier release];
	[_tableView release];

	[super dealloc];
}

- (void) setWidth:(float)width
{
	_width = MIN(MAX(width, _minWidth), _maxWidth);
}

- (id) identifier							 { return _identifier; }
- (void) setIdentifier:(id)identifier		 { ASSIGN(_identifier,identifier);}
- (void) setTableView:(NSTableView*)table	 { ASSIGN(_tableView, table); }
- (NSTableView*) tableView					 { return _tableView; }
- (void) setMinWidth:(float)minWidth 		 { _minWidth = minWidth; }
- (void) setMaxWidth:(float)maxWidth 		 { _maxWidth = maxWidth; }
- (float) minWidth							 { return _minWidth; }
- (float) maxWidth							 { return _maxWidth; }
- (float) width								 { return _width; }
- (void) sizeToFit							 {}
- (void) setHeaderCell:(NSCell *)cell		 { _headerCell = cell; }
- (void) setDataCell:(NSCell *)cell			 { _dataCell = cell; }
- (id) headerCell							 { return _headerCell; }
- (id) dataCell								 { return _dataCell; }
- (void) setResizable:(BOOL)flag			 { _tc.isResizable = flag; }
- (void) setEditable:(BOOL)flag				 { _tc.isEditable = flag; }
- (BOOL) isResizable						 { return _tc.isResizable; }
- (BOOL) isEditable							 { return _tc.isEditable; }
- (BOOL) isHidden							 { return _tc.isHidden; }
- (void) setHidden:(BOOL)flag				 { _tc.isHidden = flag; }

@end /* NSTableColumn */

/* ****************************************************************************

		NSTableView

** ***************************************************************************/

@implementation NSTableView

- (id) initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]))
		{
		NSRect h = (NSRect){{NSMinX(frameRect),0},{NSWidth(frameRect),20}};

		if (!__tableHeaderImage)
			__tableHeaderImage = [[NSImage imageNamed:@"tableHeader"] retain];
		if (!__tableHeaderImageH)
			__tableHeaderImageH = [[NSImage imageNamed:@"tableHeaderH"] retain];

		_intercellSpacing = (NSSize){2,2};
		_rowHeight = 17;
		_headerView = [[NSTableHeaderView alloc] initWithFrame:h];
		[_headerView setTableView:self];
		_tableColumns = [NSMutableArray new];
		_selectedRows = [NSMutableIndexSet new];
		_selectedColumns = [NSMutableIndexSet new];
		_lastSelectedRow = _lastSelectedColumn = -1;
		_editingRow = _editingColumn = -1;
		_backgroundColor = [[NSColor lightGrayColor] retain];
		_highlightColor = [[NSColor grayColor] retain];
		_tv.allowsColumnReordering = YES;
		_tv.allowsColumnResizing = YES;
		}

	return self;
}

- (void) dealloc
{
	[_headerView release];
	[_tableColumns release];
	[_backgroundColor release];
	[_highlightColor release];
	[_selectedRows release];
	[_selectedColumns release];
	[_target release];

	[super dealloc];
}

- (void) setDataSource:(id)ds
{
	SEL a = @selector(numberOfRowsInTableView:);
	SEL b = @selector(tableView:objectValueForTableColumn:row:);

	if (![ds respondsToSelector: a] || ![ds respondsToSelector: b])
		[NSException raise: NSInternalInconsistencyException 
					 format: @"TableView's data source does not implement the\
								NSTableDataSource protocol."];

	b = @selector(tableView:setObjectValue:forTableColumn:row:);
	_tv.dataSourceSetObjectValue = [ds respondsToSelector: b];

	_dataSource = ds;
	[self tile];
}

- (id) dataSource							{ return _dataSource; }
- (NSView*) cornerView						{ return _cornerView; }
- (NSTableHeaderView*) headerView			{ return _headerView; }
- (void) setHeaderView:(NSTableHeaderView*)h{ ASSIGN(_headerView, h); }
- (void) setCornerView:(NSView*)cornerView	{ ASSIGN(_cornerView,cornerView); }

- (void) setDelegate:(id)anObject
{
	NSNotificationCenter *n;
	SEL sel;

	if (_delegate == anObject)
		return;

#define IGNORE_(notif_name) [n removeObserver:_delegate \
							   name:NSTableView##notif_name##Notification \
							   object:self]

	n = [NSNotificationCenter defaultCenter];
	if (_delegate)
		{
		IGNORE_(ColumnDidMove);
		IGNORE_(ColumnDidResize);
		IGNORE_(SelectionDidChange);
		IGNORE_(SelectionIsChanging);
		}

	if (!(_delegate = anObject))
		return;

#define OBSERVE_(notif_name) \
	if ([_delegate respondsToSelector:@selector(tableView##notif_name:)]) \
		[n addObserver:_delegate \
		   selector:@selector(tableView##notif_name:) \
		   name:NSTableView##notif_name##Notification \
		   object:self]

	OBSERVE_(ColumnDidMove);
	OBSERVE_(ColumnDidResize);
	OBSERVE_(SelectionDidChange);
	OBSERVE_(SelectionIsChanging);

	sel = @selector(tableView:willDisplayCell:forTableColumn:row:);
	_tv.delegateWillDisplayCell = [_delegate respondsToSelector:sel];
	sel = @selector(tableView:shouldSelectRow:);
	_tv.delegateShouldSelectRow = [_delegate respondsToSelector:sel];
	sel = @selector(tableView:shouldSelectTableColumn:);
	_tv.delegateShouldSelectTableColumn = [_delegate respondsToSelector:sel];
	sel = @selector(selectionShouldChangeInTableView:);
	_tv.delegateSelectionShouldChangeInTableView 
		= [_delegate respondsToSelector:sel];
	sel = @selector(tableView:shouldEditTableColumn:row:);
	_tv.delegateShouldEditTableColumn = [_delegate respondsToSelector:sel];
}

- (void) setUsesAlternatingRowBackgroundColors:(BOOL)flag
{
	_tv.alternatingRowColor = flag;
}

- (id) delegate								{ return _delegate; }
- (BOOL) usesAlternatingRowBackgroundColors	{ return _tv.alternatingRowColor; }
- (BOOL) drawsGrid							{ return _tv.drawsGrid; }
- (void) setDrawsGrid:(BOOL)flag			{ _tv.drawsGrid = flag; }
- (void) setBackgroundColor:(NSColor*)color	{ ASSIGN(_backgroundColor,color); }
- (void) setGridColor:(NSColor*)color		{ ASSIGN(_gridColor, color); }
- (void) setHighlightColor:(NSColor *)color	{ ASSIGN(_highlightColor, color); }
- (NSColor*) backgroundColor				{ return _backgroundColor; }
- (NSColor*) gridColor						{ return _gridColor; }
- (NSColor*) highlightColor					{ return _highlightColor; }
- (float) rowHeight							{ return _rowHeight; }
- (void) setRowHeight:(float)rowHeight		{ _rowHeight = rowHeight; }
- (void) setIntercellSpacing:(NSSize)aSize	{ _intercellSpacing = aSize; }
- (NSSize) intercellSpacing					{ return _intercellSpacing; }
- (NSArray*) tableColumns					{ return _tableColumns; }
- (int) numberOfColumns						{ return [_tableColumns count]; }

- (int) numberOfRows							 
{
	return [_dataSource numberOfRowsInTableView:self];
}

- (void) addTableColumn:(NSTableColumn *)column 
{
	[_tableColumns addObject:column];
}

- (void) removeTableColumn:(NSTableColumn *)column
{
	[_tableColumns removeObject:column];
}

- (int) columnWithIdentifier:(id)identifier 
{
	int i, count = [_tableColumns count];

	for (i = 0; i < count; i++)
		if ([[[_tableColumns objectAtIndex:i] identifier] isEqual:identifier])
			return i;

	return -1;
}

- (NSTableColumn *) tableColumnWithIdentifier:(id)identifier 
{
	int index = [self columnWithIdentifier:identifier];

	return (index != -1) ? [_tableColumns objectAtIndex:index] : nil;
}

- (void) scrollRowToVisible:(int)row 
{
	[self scrollRectToVisible:[self rectOfRow:row]];
}

- (void) scrollColumnToVisible:(int)column 
{
	[self scrollRectToVisible:[self rectOfColumn:column]];
}

- (void) moveColumn:(int)column toColumn:(int)newIndex 
{
	NSTableColumn *c = [_tableColumns objectAtIndex:column];

	[_tableColumns removeObjectAtIndex:column];
	[_tableColumns insertObject:c atIndex:newIndex];

	if ([_headerView draggedColumn] == -1)				// if not dragging
		[NSNotificationCenter post: NOTE(ColumnDidMove) object: self];
}

- (void) sizeLastColumnToFit 
{
}

- (void) noteNumberOfRowsChanged		{ }
- (id) target							{ return _target; }
- (void) setTarget:anObject				{ ASSIGN(_target, anObject); }
- (void) setAction:(SEL)aSelector		{ _action = aSelector; }
- (void) setDoubleAction:(SEL)aSelector	{ _doubleAction = aSelector; }
- (SEL) action							{ return _action; }
- (SEL) doubleAction					{ return _doubleAction; }
- (BOOL) isFlipped 						{ return YES; }
- (BOOL) isOpaque						{ return YES; }
- (BOOL) acceptsFirstResponder			{ return YES; }

- (void) setAllowsColumnReordering:(BOOL)flag 
{ 
	_tv.allowsColumnReordering = flag; 
}

- (void) setAllowsColumnResizing:(BOOL)flag	 
{ 
	_tv.allowsColumnResizing = flag; 
}

- (void) setAutoresizesAllColumnsToFit:(BOOL)flag 
{ 
	_tv.autoresizesAllColumnsToFit = flag; 
}

- (BOOL) autoresizesAllColumnsToFit	
{ 
	return _tv.autoresizesAllColumnsToFit; 
}

- (BOOL) allowsColumnReordering			{ return _tv.allowsColumnReordering; }
- (BOOL) allowsColumnResizing			{ return _tv.allowsColumnResizing; }
- (BOOL) allowsEmptySelection			{ return _tv.allowsEmptySelection; }
- (BOOL) allowsColumnSelection 			{ return _tv.allowsColumnSelection; }
- (BOOL) allowsMultipleSelection		{ return _tv.allowsMultipleSelection; }

- (void) setAllowsMultipleSelection:(BOOL)flag
{ 
	_tv.allowsMultipleSelection = flag; 
}

- (void) setAllowsEmptySelection:(BOOL)flag
{
	_tv.allowsEmptySelection = flag;
}

- (void) setAllowsColumnSelection:(BOOL)flag 
{ 
	_tv.allowsColumnSelection = flag; 
}

- (void) selectAll:(id)sender
{
	NSRange a;
	NSUInteger i;
	BOOL selectionDidChange = NO;

	_lastSelectedColumn = [self numberOfColumns] - 1;
	_lastSelectedRow = [self numberOfRows] - 1;

	a = (NSRange){0, _lastSelectedColumn};
	if (![_selectedColumns containsIndexesInRange: a])
		{
		selectionDidChange = YES;
		[_selectedColumns addIndexesInRange: a];
		}

	a = (NSRange){0, _lastSelectedRow};
	if (![_selectedRows containsIndexesInRange: a])
		{
		selectionDidChange = YES;
		[_selectedRows addIndexesInRange: a];
		}

	if (selectionDidChange)
		{
		[self setNeedsDisplayInRect:[self visibleRect]];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}

- (void) deselectAll:(id)sender
{
	BOOL selectionDidChange = NO;

	if (!_tv.allowsEmptySelection)
		return;

	if (_tv.delegateSelectionShouldChangeInTableView)
		if(![_delegate selectionShouldChangeInTableView:self])
			return;

	if ([_selectedColumns count])
		{
		selectionDidChange = YES;
		[_selectedColumns removeAllIndexes];
		}

	if ([_selectedRows count])
		{
		selectionDidChange = YES;
		[_selectedRows removeAllIndexes];
		}

	_lastSelectedRow = _lastSelectedColumn = -1;

	if (selectionDidChange)
		{
		[self setNeedsDisplayInRect:[self visibleRect]];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}

- (void) selectColumn:(int)column byExtendingSelection:(BOOL)extend
{
	BOOL colSelectionDidChange = NO;
	BOOL rowSelectionDidChange = NO;
	NSRect rect = [self visibleRect];

	if (_lastSelectedRow >= 0)
		{
		NSRange	a = (NSRange){0, _lastSelectedRow};

		_lastSelectedRow = -1;
		if ([_selectedRows intersectsIndexesInRange: a])
			{
			rowSelectionDidChange = YES;
			[_selectedRows removeIndexesInRange: a];
		}	}

	if (!extend)
		{
		if ([_selectedColumns count] > 1 || ![_selectedColumns containsIndex:column])
			{
			colSelectionDidChange = YES;
			[_selectedColumns removeAllIndexes];
			}
		}
	else
		if (!_tv.allowsMultipleSelection && _lastSelectedColumn != -1)
			if (column != _lastSelectedColumn)
				[NSException raise: NSInternalInconsistencyException
							 format: @"Multiple selection is not allowed"];

	if (![_selectedColumns containsIndex: column])
		{
		if (!colSelectionDidChange && !rowSelectionDidChange)
			rect = NSIntersectionRect(rect, [self rectOfColumn:column]);
		colSelectionDidChange = YES;
		[_selectedColumns addIndex: column];
		}

	_lastSelectedColumn = column;

	if (colSelectionDidChange || rowSelectionDidChange)
		{
		[self setNeedsDisplayInRect:rect];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}

- (void) selectRow:(int)row byExtendingSelection:(BOOL)extend
{
	BOOL rowSelectionDidChange = NO;
	BOOL colSelectionDidChange = NO;
	NSRect rect = [self visibleRect];

	if (_lastSelectedColumn >= 0)
		{
		NSRange	a = (NSRange){0, _lastSelectedColumn};

		_lastSelectedColumn = -1;
		if ([_selectedColumns intersectsIndexesInRange: a])
			{
			colSelectionDidChange = YES;
			[_selectedColumns removeIndexesInRange: a];
		}	}

	if (!extend)
		{
		if ([_selectedRows count] > 1 || ![_selectedRows containsIndex:row])
			{
			rowSelectionDidChange = YES;
			[_selectedRows removeAllIndexes];
			}
		}
	else
		if (!_tv.allowsMultipleSelection && _lastSelectedRow != -1)
			if (row != _lastSelectedRow)
				[NSException raise: NSInternalInconsistencyException
							 format: @"Multiple selection is not allowed"];

	if (![_selectedRows containsIndex: row])
		{
		if (!colSelectionDidChange && !rowSelectionDidChange)
			rect = NSIntersectionRect(rect, [self rectOfRow:row]);
		rowSelectionDidChange = YES;
		[_selectedRows addIndex: row];
		}

	_lastSelectedRow = row;

	if (colSelectionDidChange || rowSelectionDidChange)
		{
		[self setNeedsDisplayInRect:rect];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}

- (void) deselectColumn:(int)column 
{
	if ([_selectedColumns containsIndex: column])
		{
		NSRect rect = [self rectOfColumn:column];

		[_selectedColumns removeIndex: column];

		if (_lastSelectedColumn == column)
			{
			if ([_selectedColumns count])
				_lastSelectedColumn = [_selectedColumns lastIndex];
			else
				_lastSelectedColumn = -1;
			}

		[self setNeedsDisplayInRect:rect];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}

- (void) deselectRow:(int)row 
{
	if ([_selectedRows containsIndex: row])
		{
		NSRect rect = [self rectOfRow:row];

		[_selectedRows removeIndex: row];

		if (_lastSelectedRow == row)
			{
			if ([_selectedRows count])
				_lastSelectedRow = [_selectedRows lastIndex];
			else
				_lastSelectedRow = -1;
			}

		[self setNeedsDisplayInRect:rect];
		[NSNotificationCenter post: NOTE(SelectionDidChange) object: self];
		}
}							// Return index of last row selected or added to
							// the selection, or -1 if no row is selected.
- (int) selectedRow 					{ return _lastSelectedRow; }
- (int) selectedColumn 					{ return _lastSelectedColumn; }
- (int) editedColumn					{ return _editingColumn; }
- (int) editedRow						{ return _editingRow; }
- (int) clickedColumn					{ return _lastSelectedColumn; }
- (int) clickedRow						{ return _lastSelectedRow; }

- (void) selectColumnIndexes:(NSIndexSet *)idx byExtendingSelection:(BOOL)flag
{
	if (!flag)
		[_selectedColumns removeAllIndexes];

	[_selectedColumns addIndexes: idx];
}

- (void) selectRowIndexes:(NSIndexSet *)idx byExtendingSelection:(BOOL)flag
{
	if (!flag)
		[_selectedRows removeAllIndexes];

	[_selectedRows addIndexes: idx];
}

- (NSIndexSet *) selectedColumnIndexes	{ return [_selectedColumns copy]; }
- (NSIndexSet *) selectedRowIndexes		{ return [_selectedRows copy]; }
- (NSInteger) numberOfSelectedColumns	{ return [_selectedColumns count]; }
- (NSInteger) numberOfSelectedRows		{ return [_selectedRows count]; }

- (BOOL) isColumnSelected:(NSInteger)columnIndex
{
	return [_selectedColumns containsIndex: columnIndex];
}

- (BOOL) isRowSelected:(NSInteger)rowIndex
{ 
	return [_selectedRows containsIndex: rowIndex];
}

- (NSEnumerator*) selectedColumnEnumerator
{
	NSMutableArray *a = [NSMutableArray new];
	int i, last = [_selectedColumns lastIndex];

	for (i = [_selectedColumns firstIndex]; i < last; i++)
		if ([_selectedColumns containsIndex: i])
			[a addObject:[NSNumber numberWithInt:i]];

	return [a objectEnumerator];
}

- (NSEnumerator*) selectedRowEnumerator
{
	NSMutableArray *a = [NSMutableArray new];
	int i, last = [_selectedRows lastIndex];

	for (i = [_selectedRows firstIndex]; i < last; i++)
		if ([_selectedRows containsIndex: i])
			[a addObject:[NSNumber numberWithInt:i]];

	return [a objectEnumerator];
}

- (NSRect) rectOfColumn:(int)column 						// Layout support
{
	int i, count = [_tableColumns count];
	NSTableColumn *colArray[count];
	float x = 0;

	if(column > count)
		return NSZeroRect;

	[_tableColumns getObjects:colArray];
	for (i = 0; i < column; i++)
		x += (colArray[i]->_width + _intercellSpacing.width);

	return (NSRect){{x, 0},{colArray[column]->_width, NSHeight(_frame)}};
}

- (NSRect) rectOfRow:(int)row 
{
	float y = (_rowHeight + _intercellSpacing.height) * row;

	return (NSRect){{0, y}, {NSWidth(_frame), _rowHeight}};
}

- (NSRange) columnsInRect:(NSRect)rect 
{
	NSRange r = {0,0};

	if (NSWidth(rect) > 0 && NSHeight(rect) > 0)
		{
		int i, count = [_tableColumns count];
		NSTableColumn *colArray[count];
		NSRect h = _bounds, intersection;
		float max_X = NSMaxX(rect);

		[_tableColumns getObjects:colArray];
		for (i = 0; i < count; i++)
			{
			h.size.width = colArray[i]->_width + _intercellSpacing.width;

			intersection = NSIntersectionRect(h, rect);
			if (NSWidth(intersection) > 0)
				{
				if (r.length == 0)
					r = (NSRange){i,1};
				else
					r.length++;
				}
			else
				if (NSMinX(h) > max_X)
					break;
			h.origin.x += h.size.width;
		}	}

	return r;
}

- (NSRange) rowsInRect:(NSRect)rect 
{
	NSRange r = {0,0};

	if (NSWidth(rect) > 0 && NSHeight(rect) > 0)
		{
		int i, count = [_dataSource numberOfRowsInTableView:self];

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

- (NSInteger) columnAtPoint:(NSPoint)point
{
	NSInteger i, count = [_tableColumns count];
	NSTableColumn *colArray[count];
	float x = 0;

	[_tableColumns getObjects:colArray];
	for (i = 0; i < count; i++)
		{
		if(point.x >= x && point.x < (x + colArray[i]->_width))
			return i;
		x += (colArray[i]->_width + _intercellSpacing.width);
		if (point.x < x)
			break;
		}

	return NSNotFound;
}

- (NSInteger) rowAtPoint:(NSPoint)point
{
	NSInteger count = [self numberOfRows];
	NSInteger i = (point.y > (_rowHeight + _intercellSpacing.height))
				? (point.y / (_rowHeight + _intercellSpacing.height)) : 0;

	for (; i < count; i++)
		if (NSPointInRect(point, [self rectOfRow:i]))
			return i;

	return NSNotFound;
}

- (NSRect) frameOfCellAtColumn:(int)column row:(int)row 
{
	return NSIntersectionRect([self rectOfRow:row],[self rectOfColumn:column]);
}

- (void) editColumn:(int)column 								// Edit fields
				row:(int)row 
				withEvent:(NSEvent*)event 
				select:(BOOL)select
{
	NSRect r;
	NSText *t;

	if (!(event) && (_editingCell))
		[_window makeFirstResponder:self];

	r = [self frameOfCellAtColumn:column row:row];
	[self lockFocus];
	if ([self scrollRectToVisible: r])
		[_headerView resetCursorRects];
	[self unlockFocus];

	if (!_editingCell)
		{
		NSTableColumn *c = [_tableColumns objectAtIndex:column];
		NSString *d;

		_editingRow = row;
		_editingColumn = column;
		_editingCell = [c dataCell];
		d = [_dataSource tableView:self objectValueForTableColumn:c row:row];
		[_editingCell setObjectValue:d];
		[_editingCell setEditable: YES];
		}

	t = [_window fieldEditor:YES forObject:_editingCell];

	if (event)
		[_editingCell editWithFrame:r
					  inView:self
					  editor:t
					  delegate:self
					  event:event];
	else
		{
		int l = (select) ? [[_editingCell stringValue] length] : 0;

		[_editingCell selectWithFrame:r
					  inView:self
					  editor:t
					  delegate:self
					  start:(int)0
					  length:l];

		[_window makeFirstResponder: t];
		}
}
															// NSText delegate
- (void) textDidBeginEditing:(NSNotification *)aNotification
{
	[NSNotificationCenter post: CNOTE(TextDidBeginEditing) object: self];
}

- (void) textDidChange:(NSNotification *)aNotification
{
	if ([_editingCell respondsToSelector:@selector(textDidChange:)])
		return [_editingCell textDidChange:aNotification];
}

- (BOOL) textShouldBeginEditing:(NSText*)textObject
{ 
	if (_delegate)
		if ([_delegate respondsTo:@selector(control:textShouldBeginEditing:)])
			return [_delegate control:self textShouldBeginEditing:textObject];

	return YES; 
}

- (void) textDidEndEditing:(NSNotification *)aNotification
{
	NSNumber *code;
	NSCell *c = _editingCell;

	NSLog(@" NSTableView textDidEndEditing ");

	_editingCell = nil;
	[c endEditing:[aNotification object]];
	_editingColumn = _editingRow = -1;

	if ((code = [[aNotification userInfo] objectForKey:NSTextMovement]))
		switch([code intValue])
			{
			case NSReturnTextMovement:
				[_window makeFirstResponder:self];
//				[self sendAction:[self action] to:[self target]];
				break;
			case NSTabTextMovement:					// FIX ME select next cell
			case NSBacktabTextMovement:
			case NSIllegalTextMovement:
				break;
			}
}

- (BOOL) textShouldEndEditing:(NSText*)textObject
{
	NSLog(@" NSTableView textShouldEndEditing ");

	if(![_window isKeyWindow])
		return NO;

	if([_editingCell isEntryAcceptable: [textObject string]])
		{
		SEL a = @selector(tableView:setObjectValue:forTableColumn:row:);

		if ([_delegate respondsTo:@selector(control:textShouldEndEditing:)])
			{
			if(![_delegate control:self textShouldEndEditing:textObject])
				{
				NSBeep();

				return NO;
			}	}

		if ([_dataSource respondsToSelector: a])
			{
			NSTableColumn *col = [_tableColumns objectAtIndex:_editingColumn];

			[_dataSource tableView:self 
						 setObjectValue:[textObject string] 
						 forTableColumn:col
						 row:_editingRow];
			return YES;
		}	}

	NSBeep();												// entry not valid
	[textObject setString:[_editingCell stringValue]];

	return NO;
}

- (void) mouseDown:(NSEvent *)event
{
	NSDate *distantFuture;
	NSPoint previous = [event locationInWindow];
	NSPoint p = [self convertPoint:previous fromView:nil];
	NSPoint current = NSZeroPoint;
	CFRange extend = {-1, 0};
	CFRange reduce = {-1, 0};
	NSEventType eventType;
	NSRect r, visibleRect;
	BOOL scrolled;
	NSInteger i, row, startRow, lastRow, scrollRow;

	if ((row = [self rowAtPoint:p]) == NSNotFound)
		return;

	[_headerView _resetClickedHeaderCell];

	if (_lastSelectedRow >= 0 && (_lastSelectedRow == row))
		{													// pre-existing sel
		if (([event modifierFlags] & NSAlternateKeyMask))
			{
			[self deselectRow:row];
			return;
			}

		if ([event clickCount] > 1)
			{												// double click	on
			NSInteger c = [self columnAtPoint:p];			// selected row

			if(c != NSNotFound && [[_tableColumns objectAtIndex:c] isEditable])
				[self editColumn:c row:row withEvent:event select:NO];
			else
				if (_target && _doubleAction)				// double click
					[_target performSelector:_doubleAction withObject:self];

			return;
			}
		}

	[self lockFocus];
	[self selectRow:row byExtendingSelection:NO];			// select start row
	startRow = lastRow = row;
	[self displayIfNeeded];
	[_window flushWindow];
	visibleRect = [self visibleRect];
	distantFuture = [NSDate distantFuture];

	[NSEvent startPeriodicEventsAfterDelay:0.05 withPeriod:0.05];

	while ((eventType = [event type]) != NSLeftMouseUp) 
		{
		if (eventType != NSPeriodic)
			current = [event locationInWindow];
		else
			{
			if (current.x != previous.x || current.y != previous.y || scrolled) 
				{
				previous = current;
				p = [self convertPoint:current fromView:nil];

				if ((row = [self rowAtPoint:p]) != NSNotFound)
					{
					if(!_tv.allowsMultipleSelection)
						{
						extend = (CFRange){row, row};
						reduce = (CFRange){lastRow, lastRow};
						}
					else
						{
						if(row >= startRow && lastRow >= startRow)
							{
							if(row > lastRow)
								extend = (CFRange){lastRow, row};
							else
								if(row < lastRow)
									reduce = (CFRange){row + 1, lastRow};
							}
						else
							{
							if(row <= startRow && lastRow <= startRow)
								{
								if(row < lastRow)
									extend = (CFRange){row, lastRow - 1};
								else
									if(row > lastRow)
										reduce = (CFRange){lastRow, row - 1};
								}
							else							// switch over
								{
								if(lastRow < startRow)	
									reduce = (CFRange){lastRow, startRow - 1};
								else
									if(lastRow > startRow)
										reduce = (CFRange){startRow+1,lastRow};
								if(row > startRow)
									extend = (CFRange){startRow + 1, row};
								else
									if(row < startRow)
										extend = (CFRange){row, startRow - 1};
						}	}	}
															// extend selection
					if (lastRow != row && extend.location >= 0)
						{
						NSRange a = (NSRange){extend.location,
										extend.length - extend.location + 1};

						r = [self rectOfRow: extend.location];
						NSMinX(r) = NSMinX(visibleRect);

//NSLog(@"extend:  %d %d", extend.location, extend.length);
						[_selectedRows addIndexesInRange: a];
//NSLog(@"AFTER add ROWS:  %@", [_selectedRows description]);
						for (i = extend.location; i <= extend.length; i++)
							{
							[self highlightSelectionInClipRect: r];
							[self drawRow:i clipRect:r];
							NSMinY(r) += _rowHeight + _intercellSpacing.height;
							}
						extend.location = -1;
						}
															// reduce selection
					if (lastRow != row && reduce.location >= 0)
						{
						NSRange a = (NSRange){reduce.location,
										reduce.length - reduce.location + 1};

						r = [self rectOfRow: reduce.location];
						NSMinX(r) = NSMinX(visibleRect);
			
//NSLog(@"reduce:  %d %d", reduce.location, reduce.length);
						[_selectedRows removeIndexesInRange: a];
//NSLog(@"AFTER remove ROWS:  %@", [_selectedRows description]);
						for (i = reduce.location; i <= reduce.length; i++)
							{
							[_backgroundColor set];
							NSRectFill(r);
							[self drawRow:i clipRect:r];
							NSMinY(r) += _rowHeight +_intercellSpacing.height;
							}
						reduce.location = -1;
						}

					lastRow = row;
					[_window flushWindow];
					}

				if(lastRow != scrollRow)					// auto scroll
					{
					r = [self rectOfRow: (scrollRow = lastRow)];
					r.size.width = 1;
					NSMinX(r) = NSMinX(visibleRect);
					if ((scrolled = [self scrollRectToVisible:r]))
						visibleRect = [self visibleRect];
			}	}	}

		event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
					   untilDate:distantFuture
					   inMode:NSEventTrackingRunLoopMode
					   dequeue:YES];
		}

	[NSEvent stopPeriodicEvents];
	[self unlockFocus];

//NSLog(@"AFTER selection ROWS:  %@", [_selectedRows description]);
	if (_tv.allowsMultipleSelection)
		_lastSelectedRow = (startRow > lastRow) ? startRow : lastRow;
	else
		_lastSelectedRow = lastRow;

	if (_target && _action)
		[_target performSelector:_action withObject:self];	// single click
}

- (void) tile 
{
	int rows = [_dataSource numberOfRowsInTableView:self];
	NSRect r = [self rectOfRow:rows - 1];
	NSRect c = [self rectOfColumn:[_tableColumns count] - 1];
												// limit column rect height in
	c.size.height = NSMaxY(r);					// case frame size has changed
	r.size.width = NSWidth(c);
	[super setFrame:NSUnionRect(r, c)];
	r = [_headerView frame];
	r.size.width = NSMaxX(c);
	[_headerView setFrame: r];
//	[_headerView resetCursorRects];
}

- (void) reloadData							
{
	[self tile];
	[self setNeedsDisplayInRect:_bounds];
}

- (void) drawRect:(NSRect)rect								// Draw tableview
{
	NSRange rowRange = [self rowsInRect:rect];
	NSRect rowClipRect = [self rectOfRow: rowRange.location];
	int i, maxRowRange = NSMaxRange(rowRange);

	[_backgroundColor set];
	NSRectFill(rect);

	if(_cacheOrigin != NSMinX(rect) || (_cacheWidth != NSWidth(rect)))
		{
		_cacheOrigin = NSMinX(rect);						// cache col origin
		_cacheWidth = NSWidth(rect);						// and size info
		_columnRange = [self columnsInRect:rect];
		_cachedColOrigin = NSMinX([self rectOfColumn:_columnRange.location]);
		}

	if(_lastSelectedColumn >= 0)							// if cols selected
		{													// highlight them
		int maxColRange = NSMaxRange(_columnRange);

		for (i = _columnRange.location; i <= maxColRange; i++)
			if ([_selectedColumns containsIndex: i])
				{
				NSRect c = NSIntersectionRect(rect, [self rectOfColumn:i]);

				[self highlightSelectionInClipRect: c];
		}		}

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

	if (row == _editingRow && _editingCell)					// don't draw over
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

	for (i = _columnRange.location; i < maxColRange; i++)
		{
		NSTableColumn *col = [_tableColumns objectAtIndex:i];
		_TableDataCell *aCell = [col dataCell];
		id data = [_dataSource tableView:self
							   objectValueForTableColumn:col
							   row:row];

		rect.size.width = col->_width;
		if(data)
			{
			[aCell setObjectValue:data];

			if(_tv.delegateWillDisplayCell)
				[_delegate tableView:self 
						   willDisplayCell:aCell 
						   forTableColumn:col
						   row:row];

			if ([_selectedRows containsIndex: row] || [_selectedColumns containsIndex: i])
				[aCell highlight:YES withFrame:rect inView:self];
			else
				[aCell drawInteriorWithFrame:rect inView:self];
			}
		rect.origin.x = NSMaxX(rect) + _intercellSpacing.width;
		}
}

- (void) highlightSelectionInClipRect:(NSRect)rect
{
	[_highlightColor set];
	NSRectFill(rect);
}

- (void) drawGridInClipRect:(NSRect)rect
{
}

- (void) setIndicatorImage:(NSImage *)anImage
			 inTableColumn:(NSTableColumn *)tableColumn
{
	int col = [_tableColumns indexOfObjectIdenticalTo:tableColumn];

	[[tableColumn headerCell] setImage: anImage];
	[_headerView displayRect:[_headerView headerRectOfColumn:col]];
}

- (NSImage*) indicatorImageInTableColumn:(NSTableColumn *)tableColumn
{
	return [[tableColumn headerCell] image];
}

- (void) setHighlightedTableColumn:(NSTableColumn *)tableColumn
{
	_lastSelectedColumn = [_tableColumns indexOfObjectIdenticalTo:tableColumn];
}

- (NSTableColumn*) highlightedTableColumn
{
	return [_tableColumns objectAtIndex:_lastSelectedColumn];
}

- (void) encodeWithCoder:(id)aCoder						// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
	
	[aCoder encodeObject: _headerView];
	[aCoder encodeObject: _cornerView];
}

- (id) initWithCoder:(id)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_headerView = [aDecoder decodeObject];
	_cornerView = [aDecoder decodeObject];
	
	return self;
}

@end /* NSTableView */
