/*
   NSMatrix.h

   Matrix view control

   Copyright (C) 1996 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSMatrix
#define _mGSTEP_H_NSMatrix

#include <AppKit/NSControl.h>

@class NSNotification;
@class NSCell;
@class NSColor;
@class NSText;
@class NSEvent;

typedef enum _NSMatrixMode {
    NSRadioModeMatrix	  = 0,
    NSHighlightModeMatrix = 1,
    NSListModeMatrix	  = 2,
    NSTrackModeMatrix	  = 3
} NSMatrixMode;


@interface NSMatrix : NSControl  <NSCoding>
{
	NSMutableArray *_cells;
	int _numRows;
	int _numCols;
	Class _cellClass;
	id _cellPrototype;
	NSSize _cellSize;
	NSSize _interCell;
	NSColor *_backgroundColor;
	NSColor *_cellBackgroundColor;
	id _delegate;
	id _target;
	SEL _action;
	SEL _doubleAction;
	SEL _errorAction;
	id selectedCell;
	int selectedRow;
	int selectedColumn;
	void *selectedCells;

	struct __MatrixFlags {
		unsigned int allowsEmptySelect:1;
		unsigned int selectionByRect:1;
		unsigned int drawsBackground:1;
		unsigned int drawsCellBackground:1;
		unsigned int autosizesCells:1;
		unsigned int autoscroll:1;
		NSMatrixMode mode:2;
		unsigned int reserved:24;
	} _m;
}

+ (Class) cellClass;
+ (void) setCellClass:(Class)classId;

- (id) initWithFrame:(NSRect)frameRect;
- (id) initWithFrame:(NSRect)frameRect
				mode:(int)aMode
				cellClass:(Class)classId
				numberOfRows:(int)rowsHigh
				numberOfColumns:(int)colsWide;
- (id) initWithFrame:(NSRect)frameRect
				mode:(int)aMode
				prototype:(NSCell *)aCell
				numberOfRows:(int)rowsHigh
				numberOfColumns:(int)colsWide;

- (void) setMode:(NSMatrixMode)aMode;					// Selection Mode
- (NSMatrixMode) mode;

- (BOOL) allowsEmptySelection;							// Matrix Configuration
- (BOOL) isSelectionByRect;
- (void) setAllowsEmptySelection:(BOOL)flag;
- (void) setSelectionByRect:(BOOL)flag;

- (void) setPrototype:(NSCell *)aCell;					// Cell Class
- (void) setCellClass:(Class)classId;
- (Class) cellClass;
- (id) prototype;

- (void) addColumnWithCells:(NSArray *)cellArray;		// Matrix layout
- (void) addRowWithCells:(NSArray *)cellArray;
- (void) addColumn;
- (void) addRow;
- (NSRect) cellFrameAtRow:(int)row column:(int)column;
- (NSSize) cellSize;
- (void) getNumberOfRows:(int *)rowCount columns:(int *)columnCount;
- (void) insertColumn:(int)column;
- (void) insertColumn:(int)column withCells:(NSArray *)cellArray;
- (void) insertRow:(int)row;
- (void) insertRow:(int)row withCells:(NSArray *)cellArray;
- (NSSize) intercellSpacing;
- (NSCell *) makeCellAtRow:(int)row column:(int)column;
- (void) putCell:(NSCell *)newCell atRow:(int)row column:(int)column;
- (void) removeColumn:(int)column;
- (void) removeRow:(int)row;
- (void) renewRows:(int)newRows columns:(int)newColumns;
- (void) setCellSize:(NSSize)aSize;
- (void) setIntercellSpacing:(NSSize)aSize;
- (void) sortUsingFunction:(NSInteger(*)(id elem1,id elem2, void *userData))cmp
				   context:(void *)context;
- (void) sortUsingSelector:(SEL)comparator;
- (int) numberOfColumns;
- (int) numberOfRows;
														// Matrix Coordinates 
- (BOOL) getRow:(int *)row column:(int *)column forPoint:(NSPoint)aPoint;
- (BOOL) getRow:(int *)row column:(int *)column ofCell:(NSCell *)aCell;

- (void) setState:(int)value atRow:(int)row column:(int)column;

- (void) deselectAllCells;								// Selected Cells
- (void) deselectSelectedCell;
- (void) selectAll:(id)sender;
- (void) selectCellAtRow:(int)row column:(int)column;
- (BOOL) selectCellWithTag:(int)anInt;
- (id) selectedCell;
- (NSArray *) selectedCells;
- (int) selectedColumn;
- (int) selectedRow;
- (void) setSelectionFrom:(int)startPos
					  to:(int)endPos
					  anchor:(int)anchorPos
					  highlight:(BOOL)flag;

- (id) cellAtRow:(int)row column:(int)column;			// Locate Cells
- (id) cellWithTag:(int)anInt;
- (NSArray *) cells;

- (NSColor *) backgroundColor;							// Graphic Attributes
- (NSColor *) cellBackgroundColor;
- (BOOL) drawsBackground;
- (BOOL) drawsCellBackground;
- (void) setBackgroundColor:(NSColor *)aColor;
- (void) setCellBackgroundColor:(NSColor *)aColor;
- (void) setDrawsBackground:(BOOL)flag;
- (void) setDrawsCellBackground:(BOOL)flag;

- (void) selectText:(id)sender;							// Editing Text
- (id) selectTextAtRow:(int)row column:(int)column;
- (void) textDidBeginEditing:(NSNotification *)notification;
- (void) textDidChange:(NSNotification *)notification;
- (void) textDidEndEditing:(NSNotification *)notification;
- (BOOL) textShouldBeginEditing:(NSText *)textObject;
- (BOOL) textShouldEndEditing:(NSText *)textObject;

- (id) nextText;										// Tab Key Behavior
- (id) previousText;
- (void) setNextText:(id)anObject;
- (void) setPreviousText:(id)anObject;

- (void) setDelegate:(id)anObject;						// Delegate
- (id) delegate;

- (BOOL) autosizesCells;								// Resizing Matrix
- (void) setAutosizesCells:(BOOL)flag;
- (void) setValidateSize:(BOOL)flag;
- (void) sizeToCells;

- (BOOL) isAutoscroll;									// Scrolling
- (void) scrollCellToVisibleAtRow:(int)row column:(int)column;
- (void) setAutoscroll:(BOOL)flag;
- (void) setScrollable:(BOOL)flag;

- (void) drawCellAtRow:(int)row column:(int)column;		// Drawing
- (void) highlightCell:(BOOL)flag atRow:(int)row column:(int)column;

- (void) setAction:(SEL)aSelector;						// Target / Action
- (void) setDoubleAction:(SEL)aSelector;
- (void) setErrorAction:(SEL)aSelector;
- (SEL) action;
- (SEL) doubleAction;
- (SEL) errorAction;
- (BOOL) sendAction;
- (void) sendAction:(SEL)aSelector to:(id)anObject forAllCells:(BOOL)flag;
- (void) sendDoubleAction;
- (void) setErrorAction:(SEL)aSelector;

- (BOOL) performKeyEquivalent:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (int) mouseDownFlags;

- (void) resetCursorRects;								// Managing Cursor

@end

#endif /* _mGSTEP_H_NSMatrix */
