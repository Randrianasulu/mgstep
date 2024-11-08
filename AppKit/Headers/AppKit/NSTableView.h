/*
   NSTableView.h

   Interface to NSTableView classes  (10.6 cell based)

   Copyright (C) 1999-2017 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTableView
#define _mGSTEP_H_NSTableView

#include <AppKit/NSControl.h>

@class NSCell;
@class NSColor;
@class NSCursor;
@class NSImage;
@class NSTableView;
@class NSEnumerator;
@class NSIndexSet;
@class NSMutableIndexSet;



@interface NSTableHeaderView : NSView
{
    NSTableView *_tableView;
    NSImage *_headerDragImage;
    NSCursor *_resizeCursor;

	NSCell *_highCell;
	NSRect _highRect;

    int _resizedColumn;
    int _draggedColumn;
    int _clickedColumn;
    float _draggedDistance;
    BOOL _drawingLastColumn;
}

- (void) setTableView:(NSTableView *)tableView;
- (NSTableView*) tableView;
- (float) draggedDistance;
- (int) draggedColumn;
- (int) resizedColumn;
- (int) columnAtPoint:(NSPoint)point;
- (NSRect) headerRectOfColumn:(int)column;

@end


@interface NSTableColumn : NSObject
{
    NSTableView *_tableView;
    NSCell *_headerCell;
    NSCell *_dataCell;

    id _identifier;
    float _minWidth;
    float _maxWidth;

    struct __tableColFlags {
        unsigned int isResizable:1;
        unsigned int isEditable:1;
        unsigned int isHidden:1;
        unsigned int reserved:5;
    } _tc;

@public
    float _width;
}

- (id) initWithIdentifier:(id)identifier;

- (NSTableView*) tableView;
- (void) setTableView:(NSTableView *)tableView;
- (void) setIdentifier:(id)identifier;
- (id) identifier;
- (id) headerCell;
- (id) dataCell;
- (void) setHeaderCell:(NSCell*)cell;
- (void) setDataCell:(NSCell*)cell;
- (void) setResizable:(BOOL)flag;
- (void) setEditable:(BOOL)flag;
- (BOOL) isEditable;
- (BOOL) isResizable;
- (BOOL) isHidden;
- (void) setHidden:(BOOL)flag;
- (void) setWidth:(float)width;
- (void) setMinWidth:(float)minWidth;
- (void) setMaxWidth:(float)maxWidth;
- (void) sizeToFit;
- (float) width;
- (float) minWidth;
- (float) maxWidth;

@end


@interface NSTableView : NSControl
{
	NSTableHeaderView *_headerView;
	NSView *_cornerView;
    NSMutableArray *_tableColumns;
    id _delegate;
    id _dataSource;
    NSSize _intercellSpacing;
    float _rowHeight;
    int _lastSelectedColumn;
    int _lastSelectedRow;
    int _editingRow;
    int _editingColumn;
    NSCell *_editingCell;

    NSMutableIndexSet *_selectedColumns;
    NSMutableIndexSet *_selectedRows;

    NSColor *_backgroundColor;
    NSColor *_gridColor;
    NSColor *_highlightColor;
    id _target;
    SEL _action;
    SEL _doubleAction;

	float _cacheOrigin;
	float _cacheWidth;
	float _cachedColOrigin;
	NSRange _columnRange;

	struct __TableViewFlags {
		unsigned int refusesFirstResponder:1;
		unsigned int dataSourceSetObjectValue:1;	// cell based TV (<= 10.6)
		unsigned int autoresizesAllColumnsToFit:1;
		unsigned int delegateSelectionShouldChangeInTableView:1;
		unsigned int delegateShouldSelectTableColumn:1;
		unsigned int delegateShouldSelectRow:1;
		unsigned int delegateShouldEditTableColumn:1;
		unsigned int delegateWillDisplayCell:1;
		unsigned int selectionType:2;
		unsigned int allowsColumnSelection:1;
		unsigned int allowsMultipleSelection:1;
		unsigned int allowsEmptySelection:1;
		unsigned int drawsGrid:1;
		unsigned int allowsColumnResizing:1;
		unsigned int allowsColumnReordering:1;
		unsigned int alternatingRowColor:1;
		unsigned int reserved:15;
	} _tv;
}

- (void) setDelegate:(id)delegate;
- (void) setDataSource:(id)aSource;
- (id) dataSource;
- (id) delegate;
- (NSTableHeaderView*) headerView;
- (NSView*) cornerView;
- (void) setHeaderView:(NSTableHeaderView *)headerView;
- (void) setCornerView:(NSView *)cornerView;
- (void) setAllowsColumnReordering:(BOOL)flag;
- (void) setAllowsColumnResizing:(BOOL)flag;
- (BOOL) allowsColumnReordering;
- (BOOL) allowsColumnResizing;
- (BOOL) autoresizesAllColumnsToFit;
- (void) setAutoresizesAllColumnsToFit:(BOOL)flag;
- (void) setDrawsGrid:(BOOL)flag;
- (BOOL) drawsGrid;
- (void) setIntercellSpacing:(NSSize)aSize;
- (NSSize) intercellSpacing;
- (void) setBackgroundColor:(NSColor *)color;
- (void) setGridColor:(NSColor *)color;
- (void) setHighlightColor:(NSColor *)color;				// mGSTEP extension
- (NSColor*) highlightColor;
- (NSColor*) gridColor;
- (NSColor*) backgroundColor;
- (void) setRowHeight:(float)rowHeight;
- (float) rowHeight;

- (NSArray*) tableColumns;
- (int) numberOfColumns;
- (int) numberOfRows;

- (void) addTableColumn:(NSTableColumn *)column;
- (void) removeTableColumn:(NSTableColumn *)column;
- (int) columnWithIdentifier:(id)identifier;
- (NSTableColumn*) tableColumnWithIdentifier:(id)identifier;

- (void) tile;
- (void) sizeLastColumnToFit;
- (void) scrollRowToVisible:(int)row;
- (void) scrollColumnToVisible:(int)column;
- (void) moveColumn:(int)column toColumn:(int)newIndex;

- (void) reloadData;
- (void) noteNumberOfRowsChanged;

- (int) editedColumn;
- (int) editedRow;
- (int) clickedColumn;
- (int) clickedRow;

- (void) setDoubleAction:(SEL)aSelector;
- (SEL) doubleAction;

- (void) setAllowsMultipleSelection:(BOOL)flag;				// Selection
- (void) setAllowsEmptySelection:(BOOL)flag;
- (void) setAllowsColumnSelection:(BOOL)flag;
- (BOOL) allowsMultipleSelection;
- (BOOL) allowsEmptySelection;
- (BOOL) allowsColumnSelection;
- (void) selectAll:(id)sender;
- (void) deselectAll:(id)sender;
- (void) selectColumn:(int)column byExtendingSelection:(BOOL)extend;
- (void) selectRow:(int)row byExtendingSelection:(BOOL)extend;

- (void) selectColumnIndexes:(NSIndexSet *)idx byExtendingSelection:(BOOL)flag;
- (void) selectRowIndexes:(NSIndexSet *)idx byExtendingSelection:(BOOL)flag;
- (NSIndexSet *) selectedColumnIndexes;
- (NSIndexSet *) selectedRowIndexes;

- (void) deselectColumn:(int)column;
- (void) deselectRow:(int)row;
- (int) selectedColumn;
- (int) selectedRow;
- (BOOL) isColumnSelected:(NSInteger)columnIndex;
- (BOOL) isRowSelected:(NSInteger)rowIndex;
- (NSInteger) numberOfSelectedColumns;
- (NSInteger) numberOfSelectedRows;
- (NSEnumerator*) selectedColumnEnumerator;
- (NSEnumerator*) selectedRowEnumerator;

- (NSRect) rectOfColumn:(int)column;						// Layout support
- (NSRect) rectOfRow:(int)row;
- (NSRect) frameOfCellAtColumn:(int)column row:(int)row;
- (NSRange) columnsInRect:(NSRect)rect;
- (NSRange) rowsInRect:(NSRect)rect;
- (NSInteger) columnAtPoint:(NSPoint)point;
- (NSInteger) rowAtPoint:(NSPoint)point;

- (BOOL) textShouldBeginEditing:(NSText *)textObject;		// Text delegate
- (BOOL) textShouldEndEditing:(NSText *)textObject;
- (void) textDidBeginEditing:(NSNotification *)notification;
- (void) textDidEndEditing:(NSNotification *)notification;
- (void) textDidChange:(NSNotification *)notification;

- (void) editColumn:(int)column								// subclassers
				row:(int)row 
				withEvent:(NSEvent *)event 
				select:(BOOL)select;
- (void) drawRow:(int)row clipRect:(NSRect)rect;
- (void) highlightSelectionInClipRect:(NSRect)rect;
- (void) drawGridInClipRect:(NSRect)rect;

- (void) setUsesAlternatingRowBackgroundColors:(BOOL)useAlternatingRowColors;
- (BOOL) usesAlternatingRowBackgroundColors;

- (void) setIndicatorImage:(NSImage *)anImage
			 inTableColumn:(NSTableColumn *)tableColumn;
- (NSImage*) indicatorImageInTableColumn:(NSTableColumn *)tableColumn;

- (void) setHighlightedTableColumn:(NSTableColumn *)tableColumn;
- (NSTableColumn*) highlightedTableColumn;

//- (void) setVerticalMotionCanBeginDrag:(BOOL)flag;		// drag or select ?
//- (BOOL) verticalMotionCanBeginDrag;

@end



@interface NSObject (NSTableViewDelegate)					// Implemented by
															// the delegate
- (void) tableView:(NSTableView *)tableView 
		 willDisplayCell:(id)cell 
		 forTableColumn:(NSTableColumn *)tableColumn 
		 row:(int)row;
- (BOOL) tableView:(NSTableView *)tableView 
		 shouldEditTableColumn:(NSTableColumn *)tableColumn 
		 row:(int)row;
- (BOOL) selectionShouldChangeInTableView:(NSTableView *)aTableView;
- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(int)row;
- (BOOL) tableView:(NSTableView *)tableView 
		 shouldSelectTableColumn:(NSTableColumn *)tableColumn;

- (void) tableView:(NSTableView *)tableView
		 mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;
@end


@interface NSObject (NSTableViewNotifications)

- (void) tableViewSelectionDidChange:(NSNotification *)notification;
- (void) tableViewColumnDidMove:(NSNotification *)notification;
- (void) tableViewColumnDidResize:(NSNotification *)notification;
- (void) tableViewSelectionIsChanging:(NSNotification *)notification;

@end

															// Notifications
extern NSString *NSTableViewSelectionDidChangeNotification;
extern NSString *NSTableViewColumnDidMoveNotification;	
											// @"NSOldColumn", @"NSNewColumn"
extern NSString *NSTableViewColumnDidResizeNotification;	
											// @"NSTableColumn", @"NSOldWidth"
extern NSString *NSTableViewSelectionIsChangingNotification;


@interface NSObject (NSTableDataSource)						// Implemented by
															// the datasource
- (int) numberOfRowsInTableView:(NSTableView *)tableView;
- (id) tableView:(NSTableView *)tableView 
	   objectValueForTableColumn:(NSTableColumn *)tableColumn 
	   row:(int)row;
- (void) tableView:(NSTableView *)tableView 
		 setObjectValue:(id)object 
		 forTableColumn:(NSTableColumn *)tableColumn 
		 row:(int)row;
@end

#endif /* _mGSTEP_H_NSTableView */
