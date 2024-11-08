/*
   Browser.m

   NSBrowser and delegate for mGSTEP Workspace

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: 	July 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSFileManager.h>
#include <AppKit/AppKit.h>

#include "Browser.h"
#include "WindowShelf.h"
#include "Matrix.h"
#include "Cell.h"

#include <math.h>


#define TITLE_RECT  (NSRect){{2, _frame.size.height - __titleHeight + 4}, \
							 {_columnSize.width - 4, __titleHeight - 8}}

// Class variables
//
static float __titleHeight = 100.0;
static NSImage *__defaultAppImage;
static NSImage *__multipleImage;
static NSImage *__unknownImage;
static NSImage *__folderImage;
static NSImage *__unixImage;
static NSImage *__textImage;
static NSWorkspace *__workspace;
static NSFileManager *__fileManager;


/* ****************************************************************************

		Browser

** ***************************************************************************/

@implementation Browser

+ (void) initialize
{
	if (self == [Browser class])
		{
		DBLog(@"Initialize xbrowser class\n");
		__defaultAppImage = [[NSImage imageNamed: @"host.tiff"] retain];
		__unknownImage = [[NSImage imageNamed: @"unknown.tiff"] retain];
		__folderImage = [[NSImage imageNamed: @"folder.tiff"] retain];
		__unixImage = [[NSImage imageNamed: @"unix.tiff"] retain];
		__textImage = [[NSImage imageNamed: @"text.tiff"] retain];
		__fileManager = [NSFileManager defaultManager];
		__workspace = [NSWorkspace sharedWorkspace];
		}
}

- (void) doSelectionDoubleClick:(id)sender
{
	[[NSApp delegate] doDoubleClick:self];
}

- (id) initWithFrame:(NSRect)rect
{
	_br.autohidesScroller = YES;

	if ((self = [super initWithFrame: rect]))
		{
		NSRect browserRect = { rect.origin, {rect.size.width,rect.size.height-125}};
		NSRect matrixRect = (NSRect){{0, 0}, {rect.size.width, 95}};
		SelectionCell *c;

		_matrixClass = [BrowserMatrix class];
		selectionMatrix = [[SelectionMatrix alloc] initWithFrame:matrixRect
												   mode:NSRadioModeMatrix
												   cellClass:[SelectionCell class]
												   numberOfRows:1
												   numberOfColumns:1];
		c = [selectionMatrix cellAtRow:0 column:0];
		[c setBranchImage: __defaultAppImage];
		[c setStringValue: [[NSProcessInfo processInfo] hostName]];
		[c _setPath: @"/"];
		[selectionMatrix setIntercellSpacing: (NSSize){40,5}];	
		[selectionMatrix setCellSize:(NSSize){CELL_WIDTH, CELL_HEIGHT}];
		[selectionMatrix sizeToCells];

		selectionScrollView = [[NSScrollView alloc] initWithFrame:TITLE_RECT];
		[selectionScrollView setHasHorizontalScroller:YES];
		[selectionScrollView setHasVerticalScroller:NO];
		[selectionScrollView setAutoresizingMask:NSViewWidthSizable];
		[selectionScrollView setRulersVisible:YES];
		[selectionScrollView setDocumentView:selectionMatrix];
		[self addSubview:selectionScrollView];

		[selectionMatrix setTarget:self];
		[selectionMatrix setAction:@selector(select:)];
		[selectionMatrix setDoubleAction: @selector(doSelectionDoubleClick:)];

		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Workspace"];	// context menu

		[menu addItemWithTitle:@"Delete" action:@selector(destroy:) keyEquivalent:@"d"];
		[menu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
		[menu addItem:[NSMenuItem separatorItem]];
		[menu addItemWithTitle:@"Open With:" action:@selector(openWithPanel:) keyEquivalent:@""];
		[menu addItemWithTitle:@"XTerm" action:@selector(openXTerm:) keyEquivalent:@""];
		[selectionMatrix setMenu:menu];
		}

	return self;
}

- (void) select:(id)sender
{
	NSInteger column = [selectionMatrix selectedColumn];

	if (column == NSNotFound || column > [self lastColumn])
		return;

	[self setLastColumn: column];
	[self reloadColumn: column];
	[(SplitView*)_superview setFileSize:@""];
	[_window flushWindow];
}

- (void) selectAll:(id)sender
{
	[_window endEditingFor:nil];
	[super selectAll: sender];
	[self doClick: [self matrixInColumn: [self lastVisibleColumn]]];
}

- (float) titleHeight						{ return __titleHeight; }

- (void) drawTitle:(NSString *)title
			inRect:(NSRect)aRect
			ofColumn:(int)column			{}

- (void) setFrame:(NSRect)rect
{
	int lastVisible = _firstVisibleColumn + _numberOfVisibleColumns - 1;

	[super setFrame:rect];
	[selectionScrollView setFrame:TITLE_RECT];
	[self setNeedsDisplayInRect: [self titleFrameOfColumn: lastVisible]];
	[self reloadColumn: lastVisible];
}

- (void) _updateScrollView:(NSScrollView *)sc
{
	id matrix = [sc documentView];

	if (sc && matrix)						// adjust the matrix but only
		{									// if column has been loaded
		NSSize ms = [matrix cellSize];
		NSClipView *c = (NSClipView *)[sc contentView];
		NSRect cRect;
//		id cl;
											// end field edit selection
//		if ((cl = [matrix selectedCell]) && ![cl isSelectable])
//			[cl endEditing: [_window fieldEditor:NO forObject:cl]];

		if (ms.width != CELL_WIDTH || ms.height != CELL_HEIGHT)
			{
			[matrix setPostsFrameChangedNotifications:NO];
			[matrix setCellSize: (NSSize){CELL_WIDTH, CELL_HEIGHT}];
			[matrix setIntercellSpacing: (NSSize){12,5}];
			[matrix sizeToCells];
			[matrix setPostsFrameChangedNotifications:YES];
			}

		cRect = [c frame];							// Add offset to clip view
//		if (cRect.origin.x <= 20)					// Left side scroller
		if (cRect.origin.x < 10)					// Right side scroller
			{
			cRect.origin.x += 10;
			cRect.size.width -= 10;
			[c setFrame: cRect];
		}	}	// FIX ME should detect scrollview flag _sv.leftSideScroller
}

- (void) reloadColumn:(int)column
{
	id c;

	if (!_window)
		return;

	if ((c = [self selectedCellInColumn: column]))	// end field edit selection
		[c endEditing: [_window fieldEditor:NO forObject:c]];			

	[super reloadColumn:column];

	if ([self lastColumn] == column)
		{
		[selectionMatrix renewRows:1 columns:column+1];
		[selectionMatrix sizeToCells];
		[selectionMatrix lockFocus];
		[selectionMatrix scrollCellToVisibleAtRow:0 column:column];
		[selectionMatrix selectCellAtRow:0 column:column];
		[selectionMatrix unlockFocus];
		}
}

- (BOOL) setPath:(NSString *)path
{
	int result;
	NSMatrix *m;

	NSLog(@"Browser setPath: %@", path);

	if ((m = [[_columns objectAtIndex:[self lastColumn]] documentView]))
		[m deselectAllCells];

	if ((result = [super setPath: path]))
		{
		SelectionCell *c, *d;
		int column = 1, lastColumnLoaded = [self lastColumn];

		[selectionMatrix renewRows:1 columns:lastColumnLoaded+1];
		for (; column <= lastColumnLoaded; column++)
			{
			c = [selectionMatrix cellAtRow:0 column:column];
			d = [self selectedCellInColumn:column - 1];
			[c setBranchImage:[d image]];
			[c setStringValue: [d stringValue]];
			[c _setPath: [self pathToColumn: column]];
			}	
		[selectionMatrix sizeToCells];
		[selectionMatrix scrollCellToVisibleAtRow:0 column:lastColumnLoaded];
		[selectionMatrix selectCellAtRow:0 column:lastColumnLoaded];

		if ((m = [[_columns objectAtIndex:lastColumnLoaded] documentView]))
			[m deselectAllCells];
		[(SplitView*)_superview setFileSize:@""];
		}

	return result;
}

- (void) keyDown:(NSEvent*)event
{
	NSMatrix *m = [self matrixInColumn: [self lastColumn]];

	[m keyDown:event];
	[self doClick: m];
}

- (void) keyUp:(NSEvent*)event
{
	[[self matrixInColumn: [self lastColumn]] keyUp:event];
}

- (void) mouseDown:(NSEvent*)event
{
	if ([event type] == NSLeftMouseDown)			// not in matrix rubberband
		[[self matrixInColumn: [self lastColumn]] mouseDown:event];
}

- (void) doClick:(id)sender
{
	NSInteger column = [self columnOfMatrix: sender];
	NSInteger count;
	NSString *t, *p, *b;
	SelectionCell *s;
	NSArray *a;
	NSArray *fa = nil;
	NSImage *img;
	BOOL isLeaf;

	[self sendAction];								// Send action to target

	if((sender) == [_window firstResponder])		// retain first responder
		if([sender isKindOfClass:[NSMatrix class]])	// status unless field 
			[_window makeFirstResponder:self];		// editor is in use

	NSLog (@"doClick");

	a = [sender selectedCells];
	if ((count = [a count]) == 0)					// click on blank cell
		{
		[selectionMatrix selectCellAtRow:0 column: column];
		[self select:nil];
		[(SplitView*)_superview setFileSize:@""];

		return;
		}

	column++;

	if (count == 1)
		{
		id c = [a objectAtIndex: 0];

		isLeaf = [c isLeaf];
		img = [[self selectedCellInColumn:column-1] image];
		t = [c stringValue];
		p = [self pathToColumn:column];
		}
	else
		{
		if (!__multipleImage)
			__multipleImage = [[NSImage imageNamed: @"multiple.tiff"] retain];

		isLeaf = YES;
		img = __multipleImage;
		t = [NSString stringWithFormat:@"%d items", count];
		p = [self pathToColumn:column];
		b = [p stringByDeletingLastPathComponent];
		p = b;
		fa = a;
		}

	[selectionMatrix renewRows:1 columns:column+1];
	s = [selectionMatrix cellAtRow:0 column:column];
	if (isLeaf)
		{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSDictionary *fa = [fm fileAttributesAtPath:p traverseLink:NO];
		NSNumber *fsize;

		if ((fsize = [fa objectForKey:NSFileSize]))
			{
			NSUInteger sz = [fsize unsignedLongLongValue] / 1000;
			
			if (sz > 1000000)
				fsize = [NSString stringWithFormat:@"%1.2f GB", sz / 1000000.0];
			else if (sz > 1000)
				fsize = [NSString stringWithFormat:@"%1.2f MB", sz / 1000.0];
			else
				fsize = [NSString stringWithFormat:@"%d KB", sz];
//			NSLog(@"File size: %d\n", [fsize intValue]);
			[(SplitView*)_superview setFileSize:fsize];
			}

		[s setLeafImage:img];
		}
	else
		{
		[s setBranchImage:img];
		[(SplitView*)_superview setFileSize:@""];
		}
	[s setStringValue: t];
	[_titles addObject: t];
	[s _setPath:p];
	[s _setFiles:fa];
 	[selectionMatrix sizeToCells];
	[selectionMatrix scrollCellToVisibleAtRow:0 column:column];
	[selectionMatrix selectCellAtRow:0 column:column];
	[selectionMatrix display];
}

- (void) doDoubleClick:(id)sender
{
	NSInteger column = [self columnOfMatrix: sender];
	BOOL shouldSelect = YES;
	NSArray *a;

	DBLog(@" NSBrowser: doDoubleClick");

	if (column == NSNotFound)					// If the matrix isn't ours
    	return;									// then just return

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
			{
//			[self setLastColumn: column];
			[[NSApp delegate] doDoubleClick: self];
			}
		else									// cell is a directory
			{
			int lastVisible;

			if([[[c stringValue] pathExtension] isEqualToString: @"app"])
				{
				[self setLastColumn: column];
				[[NSWorkspace sharedWorkspace] launchApplication: [self path]];

				return;
				}
			if ([c image] != __folderImage)		// FIX ME crude
				{
				[self setLastColumn: column];
				[[NSWorkspace sharedWorkspace] openFile:[self path] withApplication:nil];
				return;
				}
								// The cell is not a leaf so we need to load a
								// column.  If last column then add a column
			if (column == (int)([_columns count] - 1))
	   	 		[self addColumn];

			[self reloadColumn: column + 1];		// Load column
//			[self setLastColumn: column + 1];
													// If this is the last 
			lastVisible = _firstVisibleColumn + _numberOfVisibleColumns - 1;
			if (column == lastVisible)				// visible column then
				[self scrollColumnsRightBy: 1];		// scroll right by one col
		}	}
	else										// If multiple selection then
		[self setLastColumn: column];			// we unload the columns after
    									// We have already handled the single
										// click so send the double action
	[self sendAction: _doubleAction to: [self target]];
}

- (BOOL) acceptsFirstResponder					{ return YES; }
- (BOOL) becomeFirstResponder					{ return YES; }

- (void) toggleBrowserView:(id)sender
{
	NSLog(@"toggleBrowserView");
#if 0
	NSString *path = [_browser path];

	if(!(_listView))
		{
		_listView = [[NSBrowser alloc] initWithFrame: [_browser frame]];
		[_listView retain];
		[_listView setDelegate: [ListViewDelegate new]];
		[_listView setMaxVisibleColumns: 6];
		[_listView setMinColumnWidth: 150];
		[_listView setTitled: NO];
		[_listView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
		}

	if (_browser == _listView)
		{
		[[_browser superview] replaceSubview:_listView with:_iconView];
		_browser = (Browser *)_iconView;
		}
	else
		{
		[[_browser superview] replaceSubview:_iconView with:_listView];
		_browser = (Browser *)_listView;
		}

	[_browser scrollColumnToVisible: 0];
	[_browser setPath: path];
	[_browser display];
#endif
}

@end /* Browser */

/* ****************************************************************************

		IconViewDelegate,  delegates which actively create Browser rows

** ***************************************************************************/

@implementation IconViewDelegate

- (void) browser:(NSBrowser*)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix
{
	NSString *ptc = [sender pathToColumn: column];
	NSArray *files = [__fileManager directoryContentsAtPath: ptc];
	int i, j, c, nrows, count = [files count];
	NSArray *cells;

	NSRect f = [sender frame];
	int cols = (int)(NSWidth(f) / (CELL_WIDTH + 10));

	if(count < cols)
		{											// add up to MAX_COLS
		c = count;									// columns to the browser's
		nrows = 1;									// matrix
		}
	else
		{
		c = cols;
		nrows = ceil((double)count / (double)cols);
		}

	[matrix renewRows:nrows columns:c];				// create necessary cells
	[matrix sizeToCells];

	if (count == 0)
		return;

	cells = [matrix cells];
	files = [files sortedArrayUsingSelector:@selector(compare:)];

	for (i = 0; i < nrows; ++i)						// create necessary rows
		for (j = 0; j < c; ++j)
			{
			BOOL is_dir = NO;
			NSMutableString *s; 
			int pos = i*c + j;						// convert matrix row/col 
			id cell = [cells objectAtIndex:pos];	// to linear pos

			if(pos < count)							// set the cell's image		
				{									
				NSString *f = [files objectAtIndex: pos];
				NSImage *image;

				[cell setStringValue: f];
				s = (NSMutableString *)[ptc stringByAppendingPathComponent: f];

				if ([__fileManager fileExistsAtPath:s isDirectory:&is_dir])
					{
					if (is_dir)						
						{							// some type of directory
///						if([[s pathExtension] isEqualToString: @"app"])
///							[cell setBranchImage: __defaultAppImage];
						if((image = [__workspace iconForFile:s]))
							[cell setBranchImage: image];
						else
							[cell setBranchImage: __folderImage];
						}
					else
						{							// some type of file
						if((image = [__workspace iconForFile:s]))
							[cell setLeafImage: image];
						else
							if([__fileManager isExecutableFileAtPath:s])
								[cell setLeafImage: __unixImage];
							else
								[cell setLeafImage: __textImage];
					}	}
				else								// probably a symbolic link
					[cell setLeafImage: __unknownImage];
				}	
			else
				[cell setLeafImage: nil];			// display blank grey cell
			}
}

- (void) browser:(NSBrowser *)sender
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column
{
}

- (BOOL) browser:(NSBrowser *)sender
		 selectCellWithString:(NSString *)title
		 inColumn:(int)column;
{
//NSArray *cells = [[sender matrixInColumn: column] cells];

	fprintf(stderr, "browser:selectCellWithString: %s \n", [title cString]);

	return YES;
}

@end /* IconViewDelegate */


@implementation ListViewDelegate

- (void) browser:(NSBrowser*)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix*)matrix
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *ptc = [sender pathToColumn: column];
	NSArray *files = [fm directoryContentsAtPath: ptc];
	int i, count = [files count];

	[matrix renewRows:count columns:1];				// create necessary cells
	[matrix sizeToCells];

	if (count == 0)
		return;

	for (i = 0; i < count; ++i)
		{
		id cell = [matrix cellAtRow: i column: 0];
		BOOL is_dir = NO;
		NSMutableString *s;

		[cell setStringValue: [files objectAtIndex: i]];

		s = [[[NSMutableString alloc] initWithString: ptc] autorelease];
		[s appendString: @"/"];
		[s appendString: [files objectAtIndex: i]];
		[fm fileExistsAtPath: s isDirectory: &is_dir];
		
		[cell setLeaf: (!(is_dir))];
		}
}

@end /* ListViewDelegate */
