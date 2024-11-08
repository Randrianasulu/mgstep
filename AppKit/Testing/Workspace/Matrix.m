/*
   Matrix.m

   Matrices for Workspace browser

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <AppKit/AppKit.h>

#include "Matrix.h"
#include "Controller.h"
#include "WindowShelf.h"
#include "Cell.h"

#include <math.h>


// Class variables
ShelfCell *__ghostCell = nil;
ShelfCell *__openCell = nil;
NSArray *__types = nil;
NSRect openCellRect;
BOOL __doAnimation = NO;
BOOL __needsUnlockFocus = NO;
static NSString *__dragSourcePath = nil;
static NSMutableDictionary *__pbPropList = nil;


typedef struct _tMatrix {
	int allocatedRows;
	int allocatedCols;
	BOOL **matrix;
} *tMatrix;


@implementation Matrix

- (void) viewWillMoveToWindow:(NSWindow *)newWindow
{
	[super viewWillMoveToWindow: newWindow];

	if (newWindow /* && _window != newWindow */)
		{
		if (!__types)
			__types = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];
		[self registerForDraggedTypes:[__types retain]];
		}
}

- (NSArray *) saveState
{
	int i, j;
	NSString *p;
	NSMutableArray *array = [NSMutableArray array];

	for (i = 0; i < _numRows; i++) 
		for (j = 0; j < _numCols; j++)
			if ((p = [[_cells objectAtIndex:((i * _numCols) + j)] path]))
			   [array addObject:[NSString stringWithFormat:@"%d %d %@",i,j,p]];

	return array;
}

- (void) restoreState
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *array;

	if((array = [defaults objectForKey: @"Shelf"]))
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		int i, count = [array count];
		int cellCount = [_cells count];

		for (i = 0; i < count; i++)
			{
			NSString *p = [array objectAtIndex: i];
			int ii = 0, jj = 0;
			BOOL isDir = NO;
			char path[1024];

			if(sscanf([p cString], "%d %d %s", &ii, &jj, path) != 3
					|| (((ii * _numCols) + jj) >= cellCount))
				NSLog(@"Error in Defaults DB shelf matrix record\n");
			else
				{
				p = [NSString stringWithCString: path];
	
				if ([fm fileExistsAtPath:p isDirectory:&isDir])
					{
					id c = [_cells objectAtIndex:((ii * _numCols) + jj)];

					if ([c image])
						NSLog(@"Duplicate entry in shelf matrix state\n");
					else
						{
						if (isDir)
							[c setBranchImage: [ws iconForFile:p]];
						else
							[c setLeafImage: [ws iconForFile:p]];

						[c _setPath: p];
						[c setStringValue: [p lastPathComponent]];
		}	}	}	}	}
}

- (void) deselectAllCells
{
	if(_m.mode != NSHighlightModeMatrix && _m.mode != NSRadioModeMatrix)
		if (selectedCell)
			{
			NSText *t = [_window fieldEditor:NO forObject:selectedCell];
			
			if ([t delegate] == self)
				[selectedCell endEditing: t];
			}

	[super deselectAllCells];
}

- (void) selectCell:(NSCell *)aCell withRect:(NSRect)rect
{
	NSCell *browserText = [(ShelfCell *)aCell browserText];
	float titleWidth = [browserText cellSize].width - 4;
	NSRect titleRect = rect;

	titleRect.size.height = 17;							// Determine title rect
	titleRect.origin.y = NSMaxY(rect) - 13;		
	titleRect.origin.x += (titleRect.size.width - titleWidth) / 2;
	titleRect.size.width = titleWidth;
	if (NSMaxX(titleRect) > NSMaxX(_frame))
		titleRect.origin.x += (NSMaxX(_frame) - NSMaxX(titleRect));
	titleRect.origin.x = MAX(NSMinX(titleRect), 1);

	if(_m.mode == NSHighlightModeMatrix)				// not in shelf mode
		return;
	if(_m.mode == NSRadioModeMatrix)					// not in selector mode
		return;

	[browserText selectWithFrame:titleRect				// edit browser cell's
				 inView:self							// text
				 editor:[_window fieldEditor:YES forObject:browserText]	
				 delegate:self	
				 start:(int)0	 
				 length:(int)0];
}

- (void) selectRect:(NSRect)rect
{
	int i, j;
	int row1, col1;					// cell at upper left corner
	int row2, col2;					// cell at lower right corner
	NSRect cellRect, upperLeftRect;
	NSPoint p = {NSMaxX(rect), NSMaxY(rect)}; 
	NSSize inc = {_cellSize.width + _interCell.width,
				  _cellSize.height + _interCell.height};

	if (_numRows <= 0 || _numCols <= 0)
		return;

	if (![self getRow:&row1 column:&col1 forPoint:rect.origin])
		{
//		row1 = _numRows - 1;					// -y in rect is not sane
//		col1 = _numCols - 1;
		}
	if (![self getRow:&row2 column:&col2 forPoint:p])
		{
//		row2 = _numRows - 1;
//		col2 = _numCols - 1;
		}

	if (row1 < 0 || row1 >= _numRows)
		return;									// -y in rect is not sane
	if (col1 < 0 || col1 >= _numCols)
		return;
	if (row2 < 0 || row2 < row1 || row2 >= _numRows)
		return;
	if (col2 < 0 || col2 < col1 || col2 >= _numCols)
		return;

//	NSLog (@"sel cells between (%d, %d) and (%d, %d)", row1,col1, row2,col2);

	cellRect = upperLeftRect = [self cellFrameAtRow:row1 column:col1];
	for (i = row1; i <= row2; i++)
		{										// Select the cells within
		for (j = col1; j <= col2; j++)			// the rectangle
			{
			if (NSIntersectsRect(rect, cellRect))
				{
				NSCell *aCell = [_cells objectAtIndex:((i * _numCols) + j)];

				if ([aCell image])
					{
					[aCell setState:1];
					[aCell highlight:YES withFrame:cellRect inView:self];
					((tMatrix)selectedCells)->matrix[i][j] =YES;
					selectedCell = aCell;
				}	}
			cellRect.origin.x += inc.width;
			}
		cellRect.origin.x = upperLeftRect.origin.x;
		cellRect.origin.y += inc.height;
		}

	selectedRow = i;					
	selectedColumn = j;

	[_window flushWindow];
}

- (NSRect) selectWithRubberBand:(NSEvent*)event
{
	NSEventType type;
	NSPoint op, cp = [event locationInWindow];
	NSPoint t, p = [self convertPoint:cp fromView:nil];
	NSRect nr = (NSRect){p,{0,0}};
	NSRect or = nr;

//	[_window endEditingFor:nil];
	if (selectedCell)
		[selectedCell endEditing: [_window fieldEditor:NO forObject:nil]];
	[[NSColor lightGrayColor] set];

	while((type = [event type]) != NSLeftMouseUp)
		{
		if (type == NSPeriodic)
			{
			if (!NSEqualPoints(op, cp))
				{
				op = cp;
				t = nr.origin = [self convertPoint:cp fromView:nil];

				nr.size = (NSSize){MAX(p.x - nr.origin.x, nr.origin.x - p.x),
								   MAX(p.y - nr.origin.y, nr.origin.y - p.y)};
				if (nr.origin.x > p.x)
					nr.origin.x = p.x;
				if (nr.origin.y > p.y)
					nr.origin.y = p.y;

				if(or.size.width != 0)
					NSFrameRectWithWidthUsingOperation(or, 1., NSCompositeXOR);
				[self scrollRectToVisible:(NSRect){t,{2.,2.}}];
				NSFrameRectWithWidthUsingOperation(nr, 1., NSCompositeXOR);
				[_window flushWindow];
				or = nr;
			}	}
		else
			cp = [event locationInWindow];

		event = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
					   untilDate:[NSDate distantFuture]
					   inMode:NSEventTrackingRunLoopMode 
					   dequeue:YES];
		}

	if(or.size.width != 0)
		{
		NSFrameRectWithWidthUsingOperation(or,1., NSCompositeXOR);
		[_window flushWindow];
		}

	return nr;
}

- (void) setIsFinderShelf:(BOOL)flag			{ _isFinderShelf = flag; }
- (BOOL) acceptsFirstResponder					{ return _m.mode == NSListModeMatrix; }
- (void) keyUp:(NSEvent *)event					{ }	// NSResponder overrides

- (void) keyDown:(NSEvent *)event
{
	unsigned short keyCode;
	unsigned int row = selectedRow;
	unsigned int col = selectedColumn;
	NSRect rect;
	NSCell *c;

//	if (_m.mode != NSRadioModeMatrix)
	if (!selectedCell)
		return;

	switch (keyCode = [event keyCode])
		{	
		case NSUpArrowFunctionKey:
			if (selectedRow > 0)
				row = selectedRow - 1;
			break;
		case NSDownArrowFunctionKey:
			if (selectedRow < _numRows - 1)
				row = selectedRow + 1;
			break;
		case NSLeftArrowFunctionKey:
			if (selectedColumn > 0)
				col = selectedColumn - 1;
			break;
		case NSRightArrowFunctionKey:
			if (selectedColumn < _numCols - 1)
				col = selectedColumn + 1;
			break;
		default:
			return;
		}

	c = [self cellAtRow:row column:col];
	if (![c image])
		return;

	[self lockFocus];

	if (selectedCell)
		{
		id f = [_window fieldEditor:NO forObject:nil];

		[selectedCell endEditing:f];
		rect = [self cellFrameAtRow:selectedRow column:selectedColumn];
		[selectedCell setState:0];						// deselect previous
		[selectedCell highlight:NO withFrame:rect inView:self];
		[_window flushWindow];
		((tMatrix)selectedCells)->matrix[selectedRow][selectedColumn] = NO;
		}

	selectedCell = c;
	[self scrollCellToVisibleAtRow:row column:col];
	rect = [self cellFrameAtRow:row column:col];

	selectedRow = row;
	selectedColumn = col;
	((tMatrix)selectedCells)->matrix[row][col] = YES;
	[selectedCell setState:1];
	[selectedCell highlight:YES withFrame:rect inView:self];
	[self selectCell:selectedCell withRect:rect];
	[_window flushWindow];
	[self unlockFocus];
}

- (void) mouseDown:(NSEvent*)event
{
	BOOL inCell, done = NO;
	int row, column, clickCount;
	NSPoint location;
	NSRect rect, previousCellRect;
	id aCell, previousCell = nil;
	NSPoint selectedLocation;

	NSLog(@"Matrix mouseDown:\n");

	if ((clickCount = [event clickCount]) > 1)
		{
		if(_target && _doubleAction && clickCount == 2)		// double click
			if ((_m.mode != NSHighlightModeMatrix))
				[_target performSelector:_doubleAction withObject:self];

		return;
		}

	[_window endEditingFor:nil];

	if ((_m.mode != NSTrackModeMatrix) && (_m.mode != NSHighlightModeMatrix)) 
		[NSEvent startPeriodicEventsAfterDelay:0.03 withPeriod:0.03];

	location = [self convertPoint:[event locationInWindow] fromView:nil];
	[self lockFocus];					// selection involves two steps, first
										// a loop that continues until the left
	while (!done) 						// mouse goes up; then a series of 
		{								// steps which send actions and display
		BOOL shouldProceedEvent = NO;	// the cell as it should appear after
										// the selection process is complete
		if ((inCell = [self getRow:&row column:&column forPoint:location])) 			
			{											 
      		aCell = [self cellAtRow:row column:column];
      		rect = [self cellFrameAtRow:row column:column];

      		switch (_m.mode) 
				{
				case NSRadioModeMatrix:				// Path selection mode
					if (previousCell == aCell)
						{
						if((location.x > selectedLocation.x + 4.0)
								|| (location.x < selectedLocation.x - 4.0)
								|| (location.y > selectedLocation.y + 4.0) 
								|| (location.y < selectedLocation.y - 4.0))
							{		
							NSPasteboard *p;
							NSArray *t = [NSArray arrayWithObjects:
											NSFilenamesPboardType, nil];
							NSSize offset = {(NSWidth(rect)-80.0)/2.0,-40.0};
													// adjust off for last loc
							offset.width -= (location.x - NSMinX(rect)-17);
							offset.height += (location.y - NSMinY(rect)-15);
	
							p = [NSPasteboard pasteboardWithName:NSDragPboard];
							[p declareTypes:t owner:self];
							ASSIGN(__dragSourcePath, [aCell path]);

							[NSEvent stopPeriodicEvents];
							[self unlockFocus];
													// perform drag mechanics
							[self dragImage:[aCell image]
								  at:location
								  offset:offset
								  event:event
								  pasteboard:p
								  source:self
								  slideBack:YES];
							[self lockFocus];
							done = YES;			
							}
	
						break;		
						}	

					if (selectedCell == aCell)					
	    				break;		
					if ([event type] != NSLeftMouseDown)					
	    				break;		

					if (selectedCell)					
						{
						[selectedCell setState:0];		// deselect
						((tMatrix)selectedCells)->matrix[selectedRow]
														[selectedColumn] = NO;	
						[self renewRows:1 columns:1];
						[self sizeToCells];
						}			

					selectedCell = aCell;				// select current cell
					selectedRow = row;					
					selectedColumn = column;
					selectedLocation = location;	
					[aCell setState:1];	
					[aCell highlight:YES withFrame:rect inView:self];
					((tMatrix)selectedCells)->matrix[row][column] = YES;				
//					[_window flushWindow];

				case NSTrackModeMatrix:				
					break;									

				case NSHighlightModeMatrix:				// Shelf mode
					{
					NSString *path;
					NSPoint b = { MAX(rect.origin.x, location.x - 4.0), 
								  MAX(rect.origin.y, location.y - 4.0) };
					NSRect dragRect = {b, MIN( 8.0, NSMaxX(rect) - b.x),
										  MIN( 8.0, NSMaxY(rect) - b.y) };
					unsigned modifiers = [event modifierFlags];

					if (!(modifiers & NSShiftKeyMask)
							&& !(modifiers & NSAlternateKeyMask))
						[self deselectAllCells];
													// Highlight mode is like
					[aCell setState:1];				// Track mode except that
					selectedCell = aCell;			// the cell is lit before
					selectedRow = row;				// it begins tracking and
					selectedColumn = column;		// unlit afterwards
					((tMatrix)selectedCells)->matrix[row][column] = YES;
					[aCell highlight:YES withFrame:rect inView:self];
					[_window flushWindow];

					if([aCell trackMouse:event			 
							  inRect:dragRect					
							  ofView:self				
							  untilMouseUp:YES])			// YES if mouse 
						done = YES;							// went up in cell
					else
						{									// user is dragging
						if((path = [aCell path]))			// a cell from the
							{								// shelf
							NSImage *cellImage = [aCell image];
							NSPasteboard *p;
							NSSize offset = {(NSWidth(rect) - 48.0)/2.0,-56.0};
							NSArray *t = [NSArray arrayWithObjects:
											NSFilenamesPboardType, nil];
	
							p = [NSPasteboard pasteboardWithName:NSDragPboard];
							[p declareTypes:t owner:self];
							ASSIGN(__dragSourcePath, [aCell path]);

							[aCell setState:0];	
							[aCell setImage:nil];
							[aCell _setPath:nil];
							[self displayRectIgnoringOpacity: rect];
							[self unlockFocus];
													// perform drag mechanics
							[self dragImage:cellImage
								  at:rect.origin
								  offset:offset
								  event:event
								  pasteboard:p
								  source:self
								  slideBack:NO];
							done = YES;			
							[self lockFocus];

							break;		
						}	}
					DBLog(@"mouse is up");

					if(_delegate)
						if([_delegate respondsToSelector:@selector(setPath:)]
								&& (path = [aCell path]) 
								&& ![path isEqualToString:[_delegate path]])
							{
							NSFileManager *fm = [NSFileManager defaultManager];
							BOOL d = NO;

							if ([fm fileExistsAtPath:path isDirectory:&d] && d)
								[_delegate setPath:path];
							}

					if (!_isFinderShelf)
						{
						[aCell setState:0];
						((tMatrix)selectedCells)->matrix[row][column] = NO;
						[aCell highlight: NO withFrame: rect inView: self];
						selectedCell = nil;
						}
					[_window flushWindow];
					}
					break;

				case NSListModeMatrix: 			 	// File browser mode
					{
	  				unsigned modifiers = [event modifierFlags];
													// drag op if mouse moves
	  				if (previousCell == aCell)		// more than x pixels while
						{							// left mouse is down
						if((location.x > selectedLocation.x + 4.0)
								|| (location.x < selectedLocation.x - 4.0)
								|| (location.y > selectedLocation.y + 4.0)
								|| (location.y < selectedLocation.y - 4.0))
							{					// offset compensates for the
												// pos of the image cell within 
												// the larger browser cell
							NSSize offset = {(NSWidth(rect) - 48.0)/2.0,-48.0};
							NSPasteboard *p;
							NSArray *t = [NSArray arrayWithObjects:
											NSFilenamesPboardType, nil];

							p = [NSPasteboard pasteboardWithName:NSDragPboard];
							[p declareTypes:t owner:self];
							ASSIGN(__dragSourcePath, nil);

							[NSEvent stopPeriodicEvents];
													// perform drag mechanics
							[self unlockFocus];
							[self dragImage:[aCell image]
								  at:previousCellRect.origin
								  offset:offset
								  event:event
								  pasteboard:p
								  source:self
								  slideBack:YES];
							done = YES;
							[self lockFocus];
							}

	    				break;
						}

					if(selectedCell == aCell)		// Edit browsercell's text
						{
						if([aCell trackMouse:event
								  inRect:rect
								  ofView:self
								  untilMouseUp:YES])
							done = YES;				// YES if mouse up in aCell

						if(done)
							break;
						}				// When the user first clicks on a cell 
										// we clear the existing selection 
					if (!previousCell) 	// unless the Alternate or Shift keys
						{				// have been pressed.
						if (!(modifiers & NSShiftKeyMask)
								&& !(modifiers & NSAlternateKeyMask))
							{
							if (selectedCell)
								{
								id f = [_window fieldEditor:NO forObject:nil];
								[selectedCell endEditing:f];
								}
	      					[self deselectAllCells];
							}

	    				if ([aCell image])		// select or extend selection
							{					// FIX ME implement shift extend
							if (selectedCell)
								{
								id f = [_window fieldEditor:NO forObject:nil];
								[selectedCell endEditing:f];
								}
							selectedCell = aCell;		// select current cell
							selectedRow = row;
							selectedColumn = column;
							selectedLocation = location;

							[aCell setState:1];
							[aCell highlight:YES withFrame:rect inView:self];
							[self selectCell:aCell withRect:rect];

							((tMatrix)selectedCells)->matrix[row][column] = YES;
							[self sendAction];
							[_window flushWindow];
							break;
							}
	  					}

					done = YES;

					[_window flushWindow];
					break;
					}
      			}
			previousCell = aCell;
			previousCellRect = rect;
//			[self scrollRectToVisible:rect];
    		}
		else
			if (_m.mode == NSListModeMatrix && !_isFinderShelf)
				{
				NSRect s = [self selectWithRubberBand: event];

				[self deselectAllCells];
				if (!NSIsEmptyRect(s))
					[self selectRect: s];
				[self sendAction];
				done = YES;			
				}

    	if (done)										// if done break out of
      		break;										// the selection loop

		event = nil;
		while (!shouldProceedEvent)
			{											// Get the next event
			NSEvent *e = [NSApp nextEventMatchingMask:_NSTrackingLoopMask
								untilDate:[NSDate distantFuture]
								inMode:NSEventTrackingRunLoopMode
								dequeue:YES];

			DBLog(@"Matrix: got event of type: %d\n", [e type]);
      		switch ([e type])
				{
				case NSMouseMoved:
				case NSLeftMouseUp:
					shouldProceedEvent = done = YES;
					break;
				case NSPeriodic:						// it's time to cycle
					if (event)							// thru the loop again
						{
						shouldProceedEvent = YES;
						location = [self convertPoint:location fromView:nil];
						}
					break;				// Track and Highlight modes do not use		
				case NSLeftMouseDown:	// periodic events so we must break out
				default:				// and check if the mouse is in a cell
					location = [(event = e) locationInWindow];
					if ((_m.mode == NSTrackModeMatrix)
							|| (_m.mode == NSHighlightModeMatrix))
						{
				  		shouldProceedEvent = YES;
						location = [self convertPoint:location fromView:nil];
						}
					continue;
		}	}	}

	if(selectedCell && (_m.mode == NSRadioModeMatrix))	// single click action
		[self sendAction];			// in Track & Highlight modes single click
									// was already sent by cell to it's target
	if (!selectedCell && _m.mode == NSListModeMatrix)
		{
      	selectedCell = _cellPrototype;					// click on blank cell
		[self sendAction];
      	selectedCell = nil;
		}

	[self unlockFocus];

	if ((_m.mode != NSTrackModeMatrix) && (_m.mode != NSHighlightModeMatrix))
		[NSEvent stopPeriodicEvents];
}

- (void) pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{
	if (type == NSFilenamesPboardType)
		{
		NSArray *cells = [self selectedCells];
		NSMutableArray *files = [NSMutableArray new];
		ShelfCell *cell;

		if ([cells count] == 1)
			{
			NSArray *fa;

			if ((cell = [cells objectAtIndex: 0]))
				{
				if ((fa = [cell files]))			// if multiple selection
					{
					NSEnumerator *e = [fa objectEnumerator];
					ShelfCell *f;

					for (;(f = [e nextObject]);)
						[files addObject:[f stringValue]];
					}
				else
					[files addObject:[cell stringValue]];
				}
			}
		else
			{
			NSEnumerator *e = [cells objectEnumerator];

			for(;(cell = [e nextObject]);)
				[files addObject:[cell stringValue]];
			}

		if (!__dragSourcePath)
			{
			NSBrowser *b = (id)[(WindowShelf*)[NSApp mainWindow] browser];
			NSString *s = [b pathToColumn:[b selectedColumn]];
			NSString *n;

			if (files && (n = [files objectAtIndex: 0]))
				s = [s stringByAppendingPathComponent: n];

			ASSIGN(__dragSourcePath, s);

			NSLog (@"__dragSourcePath ref count: '%d'\n",
					[__dragSourcePath retainCount]);
			}
		if (!__pbPropList)
			__pbPropList = [NSMutableDictionary new];

		NSLog (@"__dragSourcePath: '%@'\n", __dragSourcePath);

		[__pbPropList setObject:__dragSourcePath forKey:@"SourcePath"];
		[__pbPropList setObject:files forKey:@"SelectedFiles"];

		[sender setPropertyList:__pbPropList forType:NSFilenamesPboardType];
		}
}

- (void) draggingExited:(id <NSDraggingInfo>)sender
{
	if(__openCell)
		{
		if ([[__openCell path] isEqualToString: @"/"])
			[__openCell setImage:[NSImage imageNamed: @"host.tiff"]];
		else
			[__openCell setImage:[NSImage imageNamed: @"folder.tiff"]];
		[__openCell drawInteriorWithFrame:openCellRect inView:self];
		[_window flushWindow];
		__openCell = nil;
		}
	if(__ghostCell)
		{
		[__ghostCell setImage:nil];
		[self displayRectIgnoringOpacity: openCellRect];
		[_window flushWindow];
		__ghostCell = nil;
		}
	if(__needsUnlockFocus)
		{
		__needsUnlockFocus = NO;
		[self unlockFocus];
		}
}

- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
	unsigned int ret = NSDragOperationNone;
	NSPoint p = [sender draggingLocation];
	int row, col;

	DBLog(@"draggingUpdated ptr window coords: '%f, %f'\n", p.x, p.y);

	p = [[_window contentView] convertPoint:p toView:self];

	DBLog(@"draggingUpdated target view coords: '%f, %f'\n", p.x, p.y);

	if([self getRow:&row column:&col forPoint:p])
		{
		ShelfCell *c = [self cellAtRow:row column:col];
		BOOL needsFlush = NO;

		DBLog(@"draggingUpdated cell at: '%d, %d'\n", row, col);

		if(__openCell && (__openCell != c))
			{
			[__openCell setImage:[NSImage imageNamed: @"folder.tiff"]];
			[__openCell drawInteriorWithFrame:openCellRect inView:self];
			needsFlush = YES;
			__openCell = nil;
			}

		if(__ghostCell && (__ghostCell != c))
			{
			[__ghostCell setImage:nil];
//			[__ghostCell drawInteriorWithFrame:openCellRect inView:self];
			[self displayRectIgnoringOpacity: openCellRect];
			needsFlush = YES;
			__ghostCell = nil;
			}

		if(![c isLeaf] && c != selectedCell)			// cell is a folder
			{
			openCellRect = [self cellFrameAtRow:row column:col];

			if (_m.mode != NSRadioModeMatrix || col < selectedColumn - 1)
				[c setImage:[NSImage imageNamed: @"openFolder.tiff"]];

			if(!__needsUnlockFocus)
				[self lockFocus];
			__needsUnlockFocus = YES;
			needsFlush = YES;
			__openCell = c;
			[c drawInteriorWithFrame:openCellRect inView:self];
//			ret = NSDragOperationCopy;

			if (_m.mode != NSRadioModeMatrix || col < selectedColumn - 1)
				ret = [sender draggingSourceOperationMask];
			}
		else
			{
			if(![c image])								// cell must be blank
				{
				__ghostCell = c;
				openCellRect = [self cellFrameAtRow:row column:col];
				[c setLeafImage:[sender draggedImage]];
				if(!__needsUnlockFocus)
					[self lockFocus];
				__needsUnlockFocus = YES;
				needsFlush = YES;
				[c drawLightInteriorWithFrame:openCellRect inView:self];
				ret = NSDragOperationGeneric;
			}	}

		if(needsFlush)
			[_window flushWindow];
		}

	return ret;
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSLog (@"concludeDragOperation:\n");

	if(__doAnimation)
		{
		__doAnimation = NO;
		[NSTimer scheduledTimerWithTimeInterval: 0.4
				 target: self
				 selector: @selector(draggingExited:)
				 userInfo: nil
				 repeats: NO];
		return;
		}

	if (_m.mode != NSListModeMatrix && [sender draggingSource] == self)
		{
		ShelfCell *aCell = [self selectedCell];
		NSRect rect;

		if(aCell != __ghostCell)
			{
			rect = [self cellFrameAtRow:selectedRow column:selectedColumn];
	
			[_window endEditingFor: nil];
			[aCell setState:0];
			[aCell setImage:nil];
			[aCell _setPath:nil];
			[self displayRectIgnoringOpacity: rect];
		}	}

	__ghostCell = nil;
	if(__openCell || __needsUnlockFocus)
		[self draggingExited:nil];

	NSLog (@"View concludeDragOperation: view description: '%s'\n",
			[[self description] cString]);
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	int row, col;
	NSPoint p = [sender draggingLocation];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSDictionary *d = [pb propertyListForType:NSFilenamesPboardType];
	NSString *browserPath = [d objectForKey:@"SourcePath"];
	ShelfCell *aCell;
	NSRect rect;

	if(!_dragTypes)
		return NO;

	NSLog (@"View performDragOperation: view description: '%s'\n",
			[[self description] cString]);
									// drag op; currently just for Workspace

	fprintf(stderr," mouse went up in window that triggered drag\n");
	fprintf (stderr,"pointer window coords: '%f, %f'\n", p.x, p.y);

	p = [[_window contentView] convertPoint:p toView:self];

	fprintf (stderr,"pointer target view coords: '%f, %f'\n", p.x,p.y);

	[self getRow:&row column:&col forPoint:p];
	
	aCell = (ShelfCell *)[self cellAtRow:row column:col];

	if([aCell path] || _m.mode == NSListModeMatrix)
		{
NSLog(@"[aCell path]: '%@'\n",[aCell path]);
		if(![aCell isLeaf] && aCell != selectedCell)
			{
			NSDragOperation ops = [sender draggingSourceOperationMask];
			NSString *op = nil;
			NSString *dst = nil;
			id delegate = [NSApp delegate];

			if (ops & NSDragOperationGeneric || ops & NSDragOperationPrivate)
				op = NSWorkspaceMoveOperation;
			else if (ops & NSDragOperationCopy)
				op = NSWorkspaceCopyOperation;
			else if (ops & NSDragOperationLink)
				op = NSWorkspaceLinkOperation;

			if (!(dst = [__openCell path]))
				{
///				dst = [[delegate path] stringByDeletingLastPathComponent];
				dst = [[_target path] stringByDeletingLastPathComponent];
//NSLog(@" **** [_target path]: '%@'\n",[_target path]);
				dst = [dst stringByAppendingPathComponent:[__openCell stringValue]];
NSLog(@" **** dst: '%@'\n", dst);
				}
			if (op && [delegate performFileOperation:op destination:dst])
				{
				__doAnimation = YES;
				[aCell setImage:[NSImage imageNamed: @"depositFolder.tiff"]];
				}
			else
				{
				[self draggingExited:nil];
				return NO;
				}
			}
		else
			{							// can't drop onto an occupied leaf
			NSLog (@"Can't drop onto an occupied leaf\n");
			if(__ghostCell)
				[self draggingExited:nil];
			return NO;					// drag cell should slide back
		}	}  
	else
		{
		NSImage *draggedImage = [sender draggedImage];
		NSString *s, *n;

		if(__ghostCell && (__ghostCell != aCell))
			aCell = __ghostCell;

		if(draggedImage == [NSImage imageNamed: @"folder.tiff"])
			[aCell setBranchImage: draggedImage];
		else
			[aCell setLeafImage: draggedImage];

		s = [d objectForKey:@"SourcePath"];
		n = [[d objectForKey:@"SelectedFiles"] objectAtIndex: 0];

fprintf (stderr,"XRWindow set cell path: '%s'\n",[s cString]);
fprintf (stderr,"XRWindow cell at: '%d, %d'\n",row,col);

		[aCell _setPath: s];
		[aCell setStringValue: n];
		}

	if(!__needsUnlockFocus)
		[self lockFocus];
	__needsUnlockFocus = YES;
	if(__ghostCell == aCell)
		rect = openCellRect;
	else
		rect = [self cellFrameAtRow:row column:col];
	[aCell drawInteriorWithFrame:rect inView:self];
	[_window flushWindow];

	return YES;
}

- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationGeneric|NSDragOperationLink|NSDragOperationCopy;
}

- (void) setFrame:(NSRect)frameRect
{
  	[super setFrame:frameRect];

	if (_m.mode == NSHighlightModeMatrix)				// only in shelf mode
		{
		int rows = (int)(NSHeight(_frame) / CELL_HEIGHT);
		int cols = (int)(NSWidth(_frame) / CELL_WIDTH);

//	NSLog(@"setFrame Matrix: ((%f, %f), (%f, %f))  rows/cols %d %d",
//				NSMinX(_frame), NSMinY(_frame), NSWidth(_frame), NSHeight(_frame), rows, cols);

		if (rows && cols && (rows != _numRows || cols != _numCols))
			[self renewRows:rows columns:cols];
// 		[self sizeToCells];
		}
}

@end /* Matrix */

/* ****************************************************************************

		SelectionMatrix

** ***************************************************************************/

static NSMenu *__contextMenu = nil;


@implementation SelectionMatrix

- (BOOL) acceptsFirstMouse:(NSEvent*)event	{ return NO; }
- (void) setMenu:(NSMenu *)menu				{ ASSIGN(__contextMenu, menu); }
- (NSMenu *) menu							{ return __contextMenu; }

- (void) sizeToCells
{
	NSSize new = {-_interCell.width, 0};

	new.width += MAX(_numCols, 1) * (_cellSize.width + _interCell.width);
	new.height += MAX(_numRows, 1) * (_cellSize.height + _interCell.height);

	[self setFrameSize: new];
}

@end /* SelectionMatrix */


@implementation BrowserCell  (ContextMenus)

- (NSMenu *) menu							{ return __contextMenu; }

- (NSMenu *) menuForEvent:(NSEvent *)event		// avoids Browser category
				   inRect:(NSRect)cellFrame
				   ofView:(NSView *)view
{
	[NSMenu popUpContextMenu:__contextMenu withEvent:event forView:view];

	return __contextMenu;
}

@end

/* ****************************************************************************

		FinderMatrix

** ***************************************************************************/

@implementation FinderMatrix

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize
{
	float cellHeight = _cellSize.height;

	[super resizeSubviewsWithOldSize:oldSize];
	
	_cellSize.height = cellHeight;
}

@end /* FinderMatrix */


@implementation BrowserMatrix

- (BOOL) acceptsFirstMouse:(NSEvent*)event	{ return YES; }

@end /* BrowserMatrix */
