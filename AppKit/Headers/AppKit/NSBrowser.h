/*
   NSBrowser.h

   Display and access hierarchal data

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:	Felipe A. Rodriguez <far@pcmagic.net>
   Date:	March 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBrowser
#define _mGSTEP_H_NSBrowser

#include <AppKit/NSControl.h>

@class NSCell;
@class NSMatrix;
@class NSScroller;


@interface NSBrowser : NSControl  <NSCoding>
{
	NSString *_pathSeparator;
    NSMutableArray *_titles;
	NSMutableArray *_columns;
    NSMutableArray *_unusedColumns;

	NSScroller *_scroller;

    id _target;
    SEL _action;
	id _delegate;
	SEL _doubleAction;
	Class _matrixClass;
	id _cellPrototype;
	NSSize _columnSize;

	int _numberOfVisibleColumns;
	int _minColumnWidth;
	int _firstVisibleColumn;
	int _maxVisibleColumns;

	struct __BrowserFlags {
		unsigned int isLoaded:1;
		unsigned int allowsMultipleSelection:1;
		unsigned int allowsBranchSelection:1;
		unsigned int allowsEmptySelection:1;
		unsigned int reuseColumns:1;
		unsigned int isTitled:1;
		unsigned int autohidesScroller:1;
		unsigned int updateScrollViews:1;
		unsigned int hasHorizontalScroller:1;
		unsigned int sendActionOnArrowKeys:1;
		unsigned int separatesColumns:1;
		unsigned int titleFromPrevious:1;
		unsigned int delegateCreatesRowsInMatrix:1;			// NO if passive
		unsigned int delegateImplementsWillDisplayCell:1;
		unsigned int delegateSelectsCellsByRow:1;
		unsigned int delegateSelectsCellsByString:1;
		unsigned int delegateSetsTitles:1;
		unsigned int reserved:15;
	} _br;
}

+ (Class) cellClass;									// Component Classes

- (id) cellPrototype;
- (Class) matrixClass;
- (void) setCellClass:(Class)classId;
- (void) setCellPrototype:(NSCell *)aCell;
- (void) setMatrixClass:(Class)classId;

- (BOOL) reusesColumns;									// NSBrowser Behavior
- (void) setReusesColumns:(BOOL)flag;
- (void) setTakesTitleFromPreviousColumn:(BOOL)flag;
- (BOOL) takesTitleFromPreviousColumn;

- (BOOL) allowsBranchSelection;							// Selection behavior
- (BOOL) allowsEmptySelection;
- (BOOL) allowsMultipleSelection;
- (void) setAllowsBranchSelection:(BOOL)flag;
- (void) setAllowsEmptySelection:(BOOL)flag;
- (void) setAllowsMultipleSelection:(BOOL)flag;

- (BOOL) sendsActionOnArrowKeys;
- (void) setSendsActionOnArrowKeys:(BOOL)flag;

- (void) setHasHorizontalScroller:(BOOL)flag;			// Horizontal Scroller
- (BOOL) hasHorizontalScroller;
- (BOOL) autohidesScroller;
- (void) setAutohidesScroller:(BOOL)flag;

- (NSInteger) maxVisibleColumns;						// NSBrowser Appearance
- (void) setMaxVisibleColumns:(NSInteger)columnCount;
- (int) minColumnWidth;
- (void) setMinColumnWidth:(int)columnWidth;
- (void) setSeparatesColumns:(BOOL)flag;
- (BOOL) separatesColumns;

- (NSInteger) columnOfMatrix:(NSMatrix *)matrix;		// Manipulating Columns
- (NSInteger) lastColumn;
- (NSInteger) firstVisibleColumn;
- (NSInteger) lastVisibleColumn;
- (NSInteger) numberOfVisibleColumns;
- (NSInteger) selectedColumn;
- (BOOL) isLoaded;
- (void) addColumn;										
- (void) loadColumnZero;
- (void) reloadColumn:(int)column;
- (void) selectAll:(id)sender;
- (void) setLastColumn:(int)column;
- (void) validateVisibleColumns;
- (void) displayColumn:(int)column;

- (BOOL) isTitled;										// Column Titles
- (void) setTitled:(BOOL)flag;
- (void) drawTitle:(NSString *)title inRect:(NSRect)aRect ofColumn:(int)column;
- (void) setTitle:(NSString *)aString ofColumn:(int)column;
- (NSRect) titleFrameOfColumn:(int)column;
- (float) titleHeight;
- (NSString *) titleOfColumn:(int)column;

- (void) scrollColumnsLeftBy:(int)shiftAmount;			// NSBrowser Scrolling
- (void) scrollColumnsRightBy:(int)shiftAmount;
- (void) scrollColumnToVisible:(int)column;
- (void) scrollViaScroller:(NSScroller *)sender;
- (void) updateScroller;

- (void) doClick:(id)sender;							// Event Handling
- (void) doDoubleClick:(id)sender;

- (id) loadedCellAtRow:(int)row column:(int)column;		// Matrices and Cells
- (id) selectedCell;
- (id) selectedCellInColumn:(int)column;
- (NSArray *) selectedCells;
- (NSMatrix *) matrixInColumn:(int)column;

- (NSRect) frameOfColumn:(int)column;					// Column Frames
- (NSRect) frameOfInsideOfColumn:(int)column;

- (NSString*) path;										// Manipulating Paths
- (NSString*) pathSeparator;
- (NSString*) pathToColumn:(int)column;
- (BOOL) setPath:(NSString *)path;
- (void) setPathSeparator:(NSString *)aString;

- (void) tile;											// Layout support

- (id) delegate;										// delegate
- (void) setDelegate:(id)anObject;

- (SEL) doubleAction;									// Target / Action
- (BOOL) sendAction;
- (void) setDoubleAction:(SEL)aSelector;

@end


@interface NSObject (NSBrowserDelegate)					// to be implemented by
														// the delegate
- (void) browser:(NSBrowser *)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix *)matrix;
- (BOOL) browser:(NSBrowser *)sender isColumnValid:(int)column;
- (int) browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column;
- (BOOL) browser:(NSBrowser *)sender
		 selectCellWithString:(NSString *)title
		 inColumn:(int)column;
- (BOOL) browser:(NSBrowser *)sender selectRow:(int)row inColumn:(int)column;
- (NSString*) browser:(NSBrowser *)sender titleOfColumn:(int)column;
- (void) browser:(NSBrowser *)sender
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column;
- (void) browserDidScroll:(NSBrowser *)sender;
- (void) browserWillScroll:(NSBrowser *)sender;

@end

extern NSString *NSBrowserIllegalDelegateException;

#endif /* _mGSTEP_H_NSBrowser */
