/*
   NSBrowser.m

   Control and cell for display of hierarchal data

   Copyright (C) 1999-2016 Free Software Foundation, Inc.

   Author:	Felipe A. Rodriguez <far@pcmagic.net>
   Date:	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.

   Browser
	|-- Columns (Scroll View) --- [1...*]
		|-- Rows (Matrix View) --- [0...*]
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSEnumerator.h>

#include <CoreGraphics/CoreGraphics.h>

#include <AppKit/NSBrowser.h>
#include <AppKit/NSBrowserCell.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSScroller.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSMatrix.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSEvent.h>


#define COLUMN_SEP	 6
#define BORDER_WIDTH 4							// border width assumes bezeled

#define VISIBLE_COUNT		  (_firstVisibleColumn + _numberOfVisibleColumns)
#define LAST_VISIBLE_COLUMN   (VISIBLE_COUNT - 1)
#define COLUMN_IS_VISIBLE(c)  ((c >= _firstVisibleColumn) && c < VISIBLE_COUNT)


// Class variables
static NSImage *__branchImage = nil;
static NSImage *__highlightBranchImage = nil;


/* ****************************************************************************

		NSBrowserCell

** ***************************************************************************/

@implementation NSBrowserCell

+ (void) initialize
{
	__branchImage = [[NSImage imageNamed: @"browserRight"] retain];
	__highlightBranchImage = [[NSImage imageNamed: @"browserRightH"] retain];
}

+ (NSImage *) branchImage				{ return __branchImage; }
+ (NSImage *) highlightedBranchImage	{ return __highlightBranchImage; }

- (id) init					{ return [self initTextCell:@"BrowserCell"]; }

- (id) initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell: aString]))
		{
		_c.alignment = NSLeftTextAlignment;
		_c.isLeaf = YES;
		_c.selectable = YES;
		}

	return self;
}

- (void) dealloc
{
	[_branchImage release];
	[_alternateImage release];
	
	[super dealloc];
}

- (id) copy
{
	NSBrowserCell *c = [super copy];

	c->_branchImage = [_branchImage retain];
	c->_alternateImage = [_alternateImage retain];

	return c;
}

- (void) setAlternateImage:(NSImage *)anImage
{														// set image to display
	ASSIGN(_alternateImage, anImage);					// when highlighted
}

- (NSImage *) alternateImage		{ return _alternateImage; }
- (BOOL) isLeaf						{ return _c.isLeaf; }
- (BOOL) isLoaded					{ return _c.isLoaded; }
- (void) setLoaded:(BOOL)flag		{ _c.isLoaded = flag; }
- (void) reset						{ _c.highlighted = _c.state = NO; }
- (void) set						{ _c.highlighted = _c.state = YES; }

- (void) setLeaf:(BOOL)flag
{
	if (!(_c.isLeaf = flag))
		{
		if(!(_branchImage))
			_branchImage = [__branchImage retain];
		if(!(_alternateImage))
			_alternateImage = [__highlightBranchImage retain];
		}
}

- (void) drawInteriorWithFrame:(NSRect)cellFrame 		// draw the cell
						inView:(NSView *)controlView
{
	NSRect titleRect = cellFrame;
	NSRect imageRect = cellFrame;
	NSCompositingOperation op;
	NSImage *image = nil;

	_controlView = controlView;							// remember last view
														// cell was drawn in 
	if (!_c.isLeaf)
		{
		imageRect.size.height = cellFrame.size.height;
		imageRect.size.width = imageRect.size.height;
														// Right justify
		imageRect.origin.x += NSWidth(cellFrame) - NSWidth(imageRect);
		}
	else
		imageRect = NSZeroRect;

	if (_c.highlighted || _c.state)				// temporary hack FAR FIX ME?
		{
		[[NSColor whiteColor] set];
		image = _alternateImage;
		op = NSCompositeHighlight;
		}									
	else
		{	
		[[[controlView window] backgroundColor] set];
		image = _branchImage;
		op = NSCompositeSourceOver;
		}
	NSRectFill(cellFrame);								// Clear the background

	titleRect.size.width -= imageRect.size.width + 4;	// draw the title cell
  	[super drawInteriorWithFrame:titleRect inView:controlView];

	if(!_c.isLeaf)										// Draw the image
		{
		NSSize size = [image size];

		imageRect.origin.x += (imageRect.size.width - size.width) / 2;
		imageRect.origin.y += (imageRect.size.height - size.height) / 2;
									
		[image compositeToPoint:imageRect.origin operation:op];
		}
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[self drawInteriorWithFrame: cellFrame inView: controlView];
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeObject: _branchImage];
	[aCoder encodeObject: _alternateImage];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];

	_branchImage = [aDecoder decodeObject];
	_alternateImage = [aDecoder decodeObject];

	return self;
}

@end  /* NSBrowserCell */

/* ****************************************************************************

		NSBrowser

** ***************************************************************************/

@implementation NSBrowser

+ (Class) cellClass							{ return [NSBrowserCell class]; }

- (id) initWithFrame:(NSRect)rect
{
	_cell = [NSTextFieldCell new];

	if ((self = [super initWithFrame: rect]))
		{
		float sw = [NSScroller scrollerWidth];

		[_cell setEditable: NO];
		[_cell setTextColor: [NSColor whiteColor]];
		[_cell setBackgroundColor: [NSColor darkGrayColor]];
		[_cell setAlignment: NSCenterTextAlignment];

		_cellPrototype = [[[self class] cellClass] new];
		_matrixClass = [NSMatrix class];
		_pathSeparator = @"/";

		_br.allowsBranchSelection = YES;
		_br.allowsEmptySelection = YES;
		_br.allowsMultipleSelection = YES;
		_br.separatesColumns = YES;
		_br.titleFromPrevious = YES;
		_br.isTitled = YES;
		_br.hasHorizontalScroller = YES;
		_br.sendActionOnArrowKeys = YES;
		_br.reuseColumns = YES;

		_maxVisibleColumns = 1;
		_minColumnWidth = (int)(sw + BORDER_WIDTH);

		_scroller = [NSScroller alloc];
		[_scroller initWithFrame: (NSRect){{0,0},{NSWidth(_frame),sw}}];
		[_scroller setTarget: self];
		[_scroller setAction: @selector(scrollViaScroller:)];
		[_scroller setAutoresizingMask: NSViewWidthSizable];
		[self addSubview: _scroller];

		_titles = [NSMutableArray new];
		_columns = [NSMutableArray new];
		_unusedColumns = [NSMutableArray new];

		[self tile];									// Calculate geometry
		[self addColumn];
		}
	
	return self;
}

- (void) dealloc
{
	[_cellPrototype release];
	[_pathSeparator release];
	[_scroller release];
	[_columns release];
	
	[super dealloc];
}

- (BOOL) sendAction		
{
	return [self sendAction:_action to:_target];
}

- (SEL) doubleAction					{ return _doubleAction; }
- (id) cellPrototype					{ return _cellPrototype; }
- (Class) matrixClass					{ return _matrixClass; }
- (NSString*) pathSeparator				{ return _pathSeparator; }
- (NSInteger) numberOfVisibleColumns	{ return _numberOfVisibleColumns; }
- (NSInteger) lastVisibleColumn			{ return LAST_VISIBLE_COLUMN; }
- (NSInteger) firstVisibleColumn		{ return _firstVisibleColumn; }
- (NSInteger) maxVisibleColumns			{ return _maxVisibleColumns; }
- (int) minColumnWidth					{ return _minColumnWidth; }
- (BOOL) isTitled						{ return _br.isTitled; }
- (BOOL) separatesColumns				{ return _br.separatesColumns; }
- (BOOL) isLoaded						{ return _br.isLoaded; }
- (BOOL) reusesColumns					{ return _br.reuseColumns; }
- (BOOL) takesTitleFromPreviousColumn	{ return _br.titleFromPrevious; }
- (BOOL) allowsBranchSelection			{ return _br.allowsBranchSelection; }
- (BOOL) allowsEmptySelection			{ return _br.allowsEmptySelection; }
- (BOOL) allowsMultipleSelection		{ return _br.allowsMultipleSelection; }
- (BOOL) sendsActionOnArrowKeys			{ return _br.sendActionOnArrowKeys; }
- (BOOL) autohidesScroller				{ return _br.autohidesScroller; }
- (BOOL) hasHorizontalScroller			{ return _br.hasHorizontalScroller; }
- (void) setPathSeparator:(NSString *)a	{ ASSIGN(_pathSeparator, a); }
- (void) setReusesColumns:(BOOL)flag	{ _br.reuseColumns = flag; }
- (void) setCellPrototype:(NSCell *)c	{ ASSIGN(_cellPrototype, c); }
- (void) setMatrixClass:(Class)classId	{ _matrixClass = classId; }
- (void) setDoubleAction:(SEL)aSelector	{ _doubleAction = aSelector; }

- (void) setCellClass:(Class)classId
{
	[self setCellPrototype: [[[classId alloc] init] autorelease]];
}

- (void) setTakesTitleFromPreviousColumn:(BOOL)flag
{
	_br.titleFromPrevious = flag;
}

- (void) setAllowsEmptySelection:(BOOL)flag
{
	_br.allowsEmptySelection = flag;
}

- (void) setAllowsBranchSelection:(BOOL)flag
{
	_br.allowsBranchSelection = flag;
}

- (void) setAllowsMultipleSelection:(BOOL)flag
{
	_br.allowsMultipleSelection = flag;
}

- (void) setSendsActionOnArrowKeys:(BOOL)flag
{
	_br.sendActionOnArrowKeys = flag;
}

- (void) setAutohidesScroller:(BOOL)flag
{
	if (_br.autohidesScroller != flag)
		_br.updateScrollViews = YES;
	_br.autohidesScroller = flag;
}

- (void) setHasHorizontalScroller:(BOOL)flag
{
	if (_br.hasHorizontalScroller != flag)
		{
		if (!(_br.hasHorizontalScroller = flag))
			[_scroller removeFromSuperview];
		if (_br.isLoaded)
			[self tile];
		}
}

- (void) setSeparatesColumns:(BOOL)flag
{
	if (_br.separatesColumns != flag)
		{
		_br.separatesColumns = flag;
		if (_br.isLoaded)
			[self tile];
		}
}

- (void) setTitled:(BOOL)flag
{
	if (_br.isTitled != flag)
		{
		_br.isTitled = flag;
		if (_br.isLoaded)
			[self tile];
		}
}

- (void) _updateScrollView:(NSScrollView *)sc
{
	id matrix = [sc documentView];
													// Adjust matrix to fit in
	if (sc && matrix)								// scrollview do so only if 	
		{											// column has been loaded
		NSSize ms = [matrix cellSize];
		NSSize cs = [sc contentSize];

		if(ms.width != cs.width)
			{
			ms.width = cs.width;
			[matrix setCellSize: ms];
			[matrix sizeToCells];
		}	}

	if (_br.updateScrollViews)
		[sc setScrollerStyle: (_br.autohidesScroller) ? NSScrollerStyleOverlay
													  : NSScrollerStyleLegacy];
}

- (void) _updateColumnFrames
{
	int count = [_columns count];

	DBLog(@"NSBrowser _updateColumnFrames\n");
	while (count--)
		{
		NSScrollView *sc = [_columns objectAtIndex: count];

		if (COLUMN_IS_VISIBLE(count))
			{
			if (![sc superview])				// Add as subview if necessary
				[self addSubview: sc];
			[sc setFrame: [self frameOfInsideOfColumn: count]];
			[self _updateScrollView: sc];
			}
		else									// If it is not visible remove
			if ([sc superview])					// it from it's superview 
				[sc removeFromSuperview];
		}

	_br.updateScrollViews = NO;
}

- (float) titleHeight
{
//	return [_cell cellSize].height;   FIX ME
	return 24;
}

- (NSInteger) lastColumn
{
	int i, count = [_columns count];			// Find the last loaded column
												// A column is loaded if it has
	for (i = 0; i < count; ++i)					// a doc view matrix.
		if (![[_columns objectAtIndex: i] documentView])
			break;

	return MAX(0, i-1);
}

- (NSInteger) columnOfMatrix:(NSMatrix *)matrix
{												// Find the column that has
	NSInteger i, count = [_columns count];		// matrix as it's doc view

	for (i = 0; i < count; ++i)
		if (matrix == [[_columns objectAtIndex: i] documentView])
			return i;

	return NSNotFound;
}

- (NSInteger) selectedColumn
{
	NSInteger i = [_columns count] - 1;

	for (;(i >= 0); i--)
		if ([[[_columns objectAtIndex:i] documentView] selectedCell])
			return i;

	return NSNotFound;
}

- (void) setMaxVisibleColumns:(NSInteger)columnCount
{
	NSInteger i, count = [_columns count];

	_maxVisibleColumns = columnCount;
		// FIX ME reduce numberOfVisible if > new max
														// Create additional 
	for (i = count; i < _maxVisibleColumns; ++i)		// columns if necessary
		[self addColumn];

	if (_br.isLoaded)
		[self tile];
}

- (void) setMinColumnWidth:(int)columnWidth
{
	float sw = [NSScroller scrollerWidth];
	float bw = 4;								// assume bezeled border width

	if (_br.separatesColumns)					// Take the border into account
		sw += bw;
												// width min = scroller+border
	_minColumnWidth = (columnWidth < sw) ? (int)sw : columnWidth;	

	if (_br.isLoaded)
		[self tile];
}

- (void) addColumn
{
	int c = [_columns count];
	NSScrollView *sc;

	sc = [[NSScrollView alloc] initWithFrame: [self frameOfInsideOfColumn: c]];
	[sc setHasVerticalScroller: YES];
	[sc setScrollerStyle: (_br.autohidesScroller) ? NSScrollerStyleOverlay
												  : NSScrollerStyleLegacy];
	[self addSubview: sc];
	[sc release];
	[_columns addObject: sc];
	[_titles addObject: @""];
}

- (void) displayColumn:(int)column			// FIX ME should display col not
{											// just the title
	if (!(COLUMN_IS_VISIBLE(column)))
		return;

	if([[_columns objectAtIndex: column] documentView])
		{						// Ask the delegate for the column title
		if([_delegate respondsToSelector:@selector(browser:titleOfColumn:)])
			[self setTitle: [_delegate browser: self
									   titleOfColumn: column]
									   ofColumn: column];
		else
			{					// Check if we take title from previous column
			if (_br.titleFromPrevious)
				{				// If first column then use the path separator
				if (column == 0)
					[self setTitle: _pathSeparator ofColumn: 0];
				else			// Get the selected cell. Use its string value
					{			// as the title Only if it is not a leaf
					id c = [self selectedCellInColumn: column - 1];
	
					if ([c isLeaf] || ![c stringValue])
						[self setTitle: @"" ofColumn: column];
					else
						[self setTitle: [c stringValue] ofColumn: column];
				}	}
			else
				[self setTitle: @"" ofColumn: column];
		}	}

	[self drawTitle: [_titles objectAtIndex: column]	// Draw the title
		  inRect: [self titleFrameOfColumn: column]
		  ofColumn: column];
}

- (void) loadColumnZero
{
	[self reloadColumn: 0];
	[self setLastColumn: 0];					// set the last column loaded
	
	if ([[_columns objectAtIndex: 0] documentView])		// FIX ME should not be necessary
		_br.isLoaded = YES;
	[self tile];
}

- (void) reloadColumn:(int)column
{												// Make sure the column exists
	int i, rows = 0, cols = 0;
	NSMatrix *m = nil;
	NSScrollView *sc;

	if (column >= (int)[_columns count])
		return;

	sc = [_columns objectAtIndex: column];
	if (!_br.delegateCreatesRowsInMatrix)
		{
		rows = [_delegate browser:self numberOfRowsInColumn:column];
		cols = 1;
		}

	if (_br.reuseColumns)
		if (!(m = [sc documentView]) && [_unusedColumns count])
			{
			[sc setDocumentView: (m = [_unusedColumns lastObject])];
			[_unusedColumns removeLastObject];
			}

	if (!m)
		{										// create a new column matrix
		unsigned int mode = _br.allowsMultipleSelection
							? NSListModeMatrix : NSRadioModeMatrix;

		m = [[_matrixClass alloc] initWithFrame: (NSRect){{0,0},{100,100}}
								  mode: mode
								  prototype: _cellPrototype
								  numberOfRows: rows
								  numberOfColumns: cols];
		[m setAllowsEmptySelection: _br.allowsEmptySelection];
		[m setTarget: self];
		[m setAction: @selector(doClick:)];
		[m setDoubleAction: @selector(doDoubleClick:)];
		[sc setDocumentView: m];
		}
	else
		[m renewRows:rows columns: 1];

	if (!_br.delegateCreatesRowsInMatrix)		// Load from passive delegate
		{										
		for (i = 0; i < rows; ++i)				// loop thru cells loading each
			[self loadedCellAtRow: i column: column];
		}										// Load from active delegate
	else										// Ask delegate to create rows
		[_delegate browser:self createRowsForColumn:column inMatrix:m];

	[self _updateScrollView: sc];

	[self setNeedsDisplayInRect: [self frameOfInsideOfColumn:column]];
}

- (void) selectAll:(id)sender
{
	if (_br.allowsMultipleSelection)
		[[self matrixInColumn: [self lastVisibleColumn]] selectAll: sender];
}

- (void) setLastColumn:(int)column		
{ 
	DBLog(@"NSBrowser setLastColumn: %d  count: %d \n", column, count);

	if (([[_columns objectAtIndex: column] documentView]))
		{
		int i, count = [_columns count];

		for (i = (column + 1); i < count; ++i)
			{
			NSScrollView *s = [_columns objectAtIndex: i];
	
			if ([s documentView])
				{
				if (_br.reuseColumns)
					[_unusedColumns addObject: [s documentView]];
	
				[s setDocumentView: nil];
				[self setTitle: @"" ofColumn: i];
				[self setNeedsDisplayInRect: [self frameOfInsideOfColumn: i]];
			}	}

		if (!(COLUMN_IS_VISIBLE(column)))
			[self scrollColumnToVisible: column];
		[self updateScroller];
		}
}

- (void) validateVisibleColumns
{
	int i;
										// xxx Should we trigger an exception?
	if (![_delegate respondsToSelector:@selector(browser:isColumnValid:)])
		return;	
										// Loop through the visible columns
	for (i = _firstVisibleColumn; i <= LAST_VISIBLE_COLUMN; ++i)
		{
		BOOL v = [_delegate browser: self isColumnValid: i];
										// Ask delegate if the column is valid 
		if (!v)							// and if not then reload the column
			[self reloadColumn: i];
		}
}

- (void) drawTitle:(NSString *)title 
			inRect:(NSRect)aRect
			ofColumn:(int)column
{
	if (_br.isTitled && COLUMN_IS_VISIBLE(column))
		{
		[_cell setStringValue: title];
		[_cell drawWithFrame: aRect inView: self];
		}
}

- (void) setTitle:(NSString *)aString ofColumn:(int)column
{
	if (column < [_titles count])
		[_titles replaceObjectAtIndex:column withObject:aString];

	if (COLUMN_IS_VISIBLE(column))
		[self setNeedsDisplayInRect: [self titleFrameOfColumn: column]];
}

- (NSRect) titleFrameOfColumn:(int)column
{
	float titleHeight = [self titleHeight];
	NSRect r;
	int n;

	if (!_br.isTitled)								// Not titled then no frame
		return NSZeroRect;
													// Number of columns over 
	n = column - _firstVisibleColumn;				// from the first
	
	r.origin.x = (n * _columnSize.width) + 2;		// Calculate the frame
	r.origin.y = _frame.size.height - titleHeight + 2;
	r.size.width = _columnSize.width - 4;
	r.size.height = titleHeight - 4;
	
	if (_br.separatesColumns)
		r.origin.x += n * COLUMN_SEP;
	
	return r;
}

- (NSString*) titleOfColumn:(int)column
{
	return [_titles objectAtIndex: column];
}

- (void) scrollColumnsLeftBy:(int)shiftAmount
{													// Cannot shift past the
	if ((_firstVisibleColumn - shiftAmount) < 0)	// zero column
		shiftAmount = _firstVisibleColumn;
	
	if (shiftAmount <= 0)
		return;
	
	if ([_delegate respondsToSelector: @selector(browserWillScroll:)])
		[_delegate browserWillScroll: self];		// Notify the delegate
	
	_firstVisibleColumn = _firstVisibleColumn - shiftAmount;
	[self _updateColumnFrames];						// Update scrollviews
	[self updateScroller];							// Update the scroller
														
	if ([_delegate respondsToSelector: @selector(browserDidScroll:)])
		[_delegate browserDidScroll: self];			// Notify the delegate

	[self setNeedsDisplayInRect: _bounds];
}

- (void) scrollColumnsRightBy:(int)shiftAmount
{
	int lastColumnLoaded = [self lastColumn];		// Cannot shift past the
													// last loaded column
	if ((shiftAmount + LAST_VISIBLE_COLUMN) > lastColumnLoaded)
		shiftAmount = lastColumnLoaded - LAST_VISIBLE_COLUMN;
	
	if (shiftAmount <= 0)
		return;
	
	if ([_delegate respondsToSelector: @selector(browserWillScroll:)])
		[_delegate browserWillScroll: self];		// Notify the delegate
	
	_firstVisibleColumn = _firstVisibleColumn + shiftAmount;
	[self _updateColumnFrames];						// Update scrollviews
	[self updateScroller];							// Update the scroller
	
	if ([_delegate respondsToSelector: @selector(browserDidScroll:)])
		[_delegate browserDidScroll: self];			// Notify the delegate

	[self setNeedsDisplayInRect: _bounds];
}

- (void) scrollColumnToVisible:(int)column
{
	int i;									// If col is last visible or number
											// of visible columns is greater 
	if (LAST_VISIBLE_COLUMN == column)		// than number loaded do nothing
		return;
	if (_firstVisibleColumn ==0 && [self lastColumn] < _numberOfVisibleColumns)
		return;

	if ((i = LAST_VISIBLE_COLUMN - column) > 0)
		[self scrollColumnsLeftBy: i];
	else
		[self scrollColumnsRightBy: (-i)];
}

- (void) scrollViaScroller:(NSScroller *)sender
{
	NSScrollerPart h = [sender hitPart];

	if ((h == NSScrollerDecrementLine) || (h == NSScrollerDecrementPage))
		[self scrollColumnsLeftBy: 1];					// Scroll to the left
	else if ((h == NSScrollerIncrementLine) || (h == NSScrollerIncrementPage))
		[self scrollColumnsRightBy: 1];					// Scroll to the right
	else if ((h == NSScrollerKnob) || (h == NSScrollerKnobSlot))
		{
		int i = rint([sender floatValue] * [self lastColumn]);

		[self scrollColumnToVisible: i];
		}
}

- (void) updateScroller			// If there are not enough columns to scroll
{								// with then the column must be visible
	int lastColumnLoaded = [self lastColumn];

	if((lastColumnLoaded == 0) || (lastColumnLoaded < _numberOfVisibleColumns))
		{									// disable horiz scroller only if
		if(_firstVisibleColumn == 0)		// browser's first col is visible
			[_scroller setEnabled: NO];
		}
	else
		{
		float p = (float)((float)_numberOfVisibleColumns 
							/ (float)(lastColumnLoaded + 1));
		float i = (lastColumnLoaded + 1) - _numberOfVisibleColumns;
		float f = 1 + ((LAST_VISIBLE_COLUMN - lastColumnLoaded) / i);

		[_scroller setFloatValue: f knobProportion: p];
		[_scroller setEnabled: YES];
		}
}

- (void) doClick:(id)sender					// handle a single click in a cell
{
	NSInteger column = [self columnOfMatrix: sender];
	BOOL shouldSelect = YES;
	NSArray *a;
											// If the matrix isn't ours then 
	if (column == NSNotFound)				// just return
		return;

	if (_br.delegateSelectsCellsByRow)		// Ask delegate if selection is ok
		{
		shouldSelect = [_delegate browser: self
								  selectRow: [sender selectedRow]
								  inColumn: column];
		}
	else if (_br.delegateSelectsCellsByString)	// Try the other method
		{
		id a = [[sender selectedCell] stringValue];

		shouldSelect = [_delegate browser:self
								  selectCellWithString:a
								  inColumn: column];
		}
	
	if (!shouldSelect)							// If we should not select cell
		{										// deselect it and return
		[sender deselectSelectedCell];
		return;
		}

	a = [sender selectedCells];
	
	if ([a count] == 1)							// If only one cell is selected
		{
		id c = [a objectAtIndex: 0];			
												// If the cell is a leaf then
		if ([c isLeaf])							// unload the columns after
			[self setLastColumn: column];
		else									// The cell is not a leaf so we 
			{									// need to load a column.  If 
			int next = column + 1;				// last column then add a col

			if (column == (int)([_columns count] - 1))
				[self addColumn];
												// Load column
			[self reloadColumn: next];
												// If this column is the last 
			if (column == LAST_VISIBLE_COLUMN)	// visible column then scroll 
				[self scrollColumnsRightBy: 1];	// right by one column
			else
				{
				[self setLastColumn: next];
				[self setNeedsDisplayInRect:[self titleFrameOfColumn: next]];
		}	}	}
	else										// If multiple selection then
		[self setLastColumn: column];			// we unload the columns after
	
	[self sendAction];							// Send action to the target
}

- (void) doDoubleClick:(id)sender				// Already handled the single
{												// click so send double action
	[self sendAction: _doubleAction to: [self target]];
}

- (id) loadedCellAtRow:(int)row column:(int)column		// FIX ME wrong
{
	id c = nil;

	if (column < [_columns count])							// col range check
		{
		id matrix = [[_columns objectAtIndex: column] documentView];
		NSArray *columnCells = [matrix cells];

		if (row >= [columnCells count])						// row range check
			return nil;
		
		c = [matrix cellAtRow: row column: 0];				// Get the cell
		
		if (![c isLoaded])									// Load if not yet
			{												// loaded
			[_delegate browser:self willDisplayCell:c atRow:row column:column];
			[c setLoaded: YES];
		}	}

	return c;
}

- (NSMatrix*) matrixInColumn:(int)column
{
	return [[_columns objectAtIndex: column] documentView];
}

- (id) selectedCell
{
	NSInteger i = [self selectedColumn];

	return (i == NSNotFound) ? nil : [[self matrixInColumn: i] selectedCell];
}

- (id) selectedCellInColumn:(int)column
{
	return [[self matrixInColumn: column] selectedCell];
}

- (NSArray*) selectedCells
{
	NSInteger i = [self selectedColumn];

	return (i == NSNotFound) ? nil : [[self matrixInColumn: i] selectedCells];
}

- (NSRect) frameOfColumn:(int)column				// Number of columns over
{													// from the first visible
	int n = MAX(0, MIN(column - _firstVisibleColumn, _numberOfVisibleColumns-1));
	NSRect r = {{n * _columnSize.width, 0}, _columnSize};

	if (_br.separatesColumns)
		r.origin.x += n * COLUMN_SEP;
													// Adjust for horizontal
	if (_br.hasHorizontalScroller)					// scroller
		r.origin.y = [NSScroller scrollerWidth] + 4;
	
	return r;
}

- (NSRect) frameOfInsideOfColumn:(int)column
{
	return NSInsetRect([self frameOfColumn: column], 2, 2);
}

- (BOOL) setPath:(NSString *)path
{
	NSArray *subStrings;
	int numberOfSubStrings, i, count;

	if(!path)
		return NO;

	subStrings = [path componentsSeparatedByString:_pathSeparator];
	count = [_columns count] - 1;

	if(_br.isLoaded)
		{
		[self setLastColumn: 0];
		[self scrollColumnsLeftBy: count + 1];			
		}
	else
		[self loadColumnZero];

	if (((numberOfSubStrings = [subStrings count]) == 1)
			&& [[subStrings objectAtIndex:0] length] == 0)
		return YES;									// optimized root path sel

	for(i = 1; i < numberOfSubStrings; i++)			// cycle thru str's array
		{											// created from path
		NSMatrix *matrix = [[_columns objectAtIndex: i-1] documentView];
		NSArray *cells = [matrix cells];
		int j, k, numOfRows, numOfCols;
		NSBrowserCell *matchingCell = nil;
		NSString *a = [subStrings objectAtIndex:i];

		if (!matrix)	// FIX ME should not happen
			{
			NSLog(@"NSBrowser: WARNING no matrix in column %d\n", i-1);
			continue;
			}

		if (i == 1 && _br.isLoaded)					// clear any selecteted
			[matrix deselectAllCells];
		[matrix getNumberOfRows:&numOfRows columns:&numOfCols];

		for (j = 0; j < numOfRows; j++)				// find the cell in the
			for (k = 0; k < numOfCols; k++)			// browser matrix with
				{									// title equal to "a"
				id tc = [cells objectAtIndex:((j * numOfCols) + k)];

				if ([[tc stringValue] isEqualToString: a])
					{
					int r, c;

					k = numOfCols;
					j = numOfRows;
					if ([matrix getRow:&r column:&c ofCell:tc])
						{
						[matrix selectCellAtRow:r column:c];
						matchingCell = tc;
				}	}	}
													// if unable to find a cell
		if(!matchingCell)							// whose title matches "a"
			{										// return NO
			NSLog(@"NSBrowser: unable to find cell in matrix\n");
			return NO;
			}
													// if the cell is not a
		if(![matchingCell isLeaf])					// leaf add a column to the
			{										// browser for it
			if(i > count)
				[self addColumn];
			[self reloadColumn: i];					// Load the column
			[self scrollColumnsRightBy: 1];			// scroll right by one col
			}
		else										// the cell is a leaf so we
			break;									// break out
		}

	return YES;
}

- (NSString*) path
{
	return [self pathToColumn: [_columns count]];
}

- (NSString*) pathToColumn:(int)column
{
	NSMutableString *s = [_pathSeparator mutableCopy];
	int i, lastColumnLoaded = [self lastColumn];
	id c;

	if (column > lastColumnLoaded)
		column = lastColumnLoaded + 1;				// limit to loaded columns

	for (i = 0; i < column && (c = [self selectedCellInColumn: i]); i++)
		{
		if(i > 0)
			[s appendString: _pathSeparator];
		[s appendString: [c stringValue]];
		}

	return (NSString*)[s autorelease];
}

- (void) setFrame:(NSRect)rect
{
	if (!NSEqualRects(rect, _frame))
		{
		[super setFrame:rect];
		[self tile];
		}
}

- (void) setFrameSize:(NSSize)newSize
{
	[super setFrameSize:newSize];
	[self tile];								// recalc browser's elements
}

- (void) resizeWithOldSuperviewSize:(NSSize)oldSize		
{
	DBLog(@"NSBrowser resizeWithOldSuperviewSize:");
	[super resizeWithOldSuperviewSize:oldSize];
	[self tile];								// recalc browser's elements
}

- (void) tile									// assume that frame and bounds
{												// have been set appropriately
	int columnsPossible = (int)(NSWidth(_frame) / (_minColumnWidth + COLUMN_SEP));
	int currentVisibleColumns = _numberOfVisibleColumns;

	DBLog(@"NSBrowser tile");

	_numberOfVisibleColumns = MIN(_maxVisibleColumns, columnsPossible);

	if (_br.separatesColumns)
		_columnSize.width = ((NSWidth(_frame) - ((_numberOfVisibleColumns - 1)
							* COLUMN_SEP)) / _numberOfVisibleColumns);
	else
		_columnSize.width = NSWidth(_frame) / (float)_numberOfVisibleColumns;
	_columnSize.width = ceil(_columnSize.width);
	_columnSize.height = _frame.size.height;
	
	if (_br.hasHorizontalScroller)						// Horizontal scroller
		_columnSize.height -= ([NSScroller scrollerWidth] + 4);

	if (_br.isTitled)									// Adjust for Title
		_columnSize.height -= [self titleHeight];
	
	if (_columnSize.height < 0)
		_columnSize.height = 0;

	if(currentVisibleColumns != _numberOfVisibleColumns)
		{
		if(_numberOfVisibleColumns > currentVisibleColumns)
			{
			if(_firstVisibleColumn > 0)
				{
				int c = _numberOfVisibleColumns - currentVisibleColumns;
				int d = MAX([_columns count] - currentVisibleColumns, 1);

				[self scrollColumnsLeftBy: MIN(d, c)];
				}
			else
				[_scroller setEnabled: NO];
			}
		else
			{
			int c = currentVisibleColumns - _numberOfVisibleColumns;

			if ([_columns count] > _numberOfVisibleColumns)
				[self scrollColumnsRightBy: c];
		}	}

	[self _updateColumnFrames];
}

- (void) drawRect:(NSRect)rect
{
	int i;
 
	if (!_br.isLoaded)					// Load the first column if not already
		{								// loaded
		[self loadColumnZero];
		[self displayColumn: 0];
		[self setNeedsDisplayInRect: _bounds];
		}
										// Loop through the visible columns
	for (i = _firstVisibleColumn; i <= LAST_VISIBLE_COLUMN; ++i)
		{							 
		NSRect r = NSIntersectionRect([self titleFrameOfColumn: i], rect);

		if (! NSIsEmptyRect(r))			// If the column title intersects with
			[self displayColumn: i];	// the rect to be drawn then draw that
		}								// column
}	

- (void) mouseDown:(NSEvent*)event				{}
- (void) drawCell:(NSCell *)aCell				{}		// override NSControl's
- (void) drawCellInside:(NSCell *)aCell			{}		// defaults
- (void) selectCell:(NSCell *)aCell				{}
- (void) updateCell:(NSCell *)aCell				{}
- (void) updateCellInside:(NSCell *)aCell		{}

- (id) delegate									{ return _delegate; }

- (void) setDelegate:(id)anObject
{
	SEL s = @selector(browser:willDisplayCell:atRow:column:);
	SEL a = @selector(browser:createRowsForColumn:inMatrix:);
	char *b = "browser:createRowsForColumn:inMatrix:";
	char *p = "browser:numberOfRowsInColumn:";

	if ([anObject respondsToSelector:@selector(browser:numberOfRowsInColumn:)])
		{
		_br.delegateCreatesRowsInMatrix = NO;			// Passive delegate

		if ([anObject respondsToSelector: a])
			[NSException raise: NSBrowserIllegalDelegateException
						 format: @"Delegate responds to both %s and %s",b,p];
		}
	else
		{
		_br.delegateCreatesRowsInMatrix = YES;			// Active delegate

		if (![anObject respondsToSelector: a])
			[NSException raise: NSBrowserIllegalDelegateException
						 format: @"Delegate does not respond to %s or %s",b,p];
		}

	if ([anObject respondsToSelector: s])
		_br.delegateImplementsWillDisplayCell = YES;
	else
		if (!_br.delegateCreatesRowsInMatrix)
			[NSException raise: NSBrowserIllegalDelegateException
						 format: @"Passive delegate must respond to %s\n",
								"browser:willDisplayCell:atRow:column:"];

	s = @selector(browser:selectRow:inColumn:);
	_br.delegateSelectsCellsByRow = ([anObject respondsToSelector: s]);
	s = @selector(browser:selectCellWithString:inColumn:);
	_br.delegateSelectsCellsByString = ([anObject respondsToSelector: s]);
	s = @selector(browser:titleOfColumn:);
	_br.delegateSetsTitles = ([anObject respondsToSelector: s]);

	_delegate = anObject;
}

- (void) encodeWithCoder:(NSCoder*)aCoder				// NSCoding protocol
{
	[super encodeWithCoder:aCoder];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	return [super initWithCoder:aDecoder];
}

@end /* NSBrowser */
