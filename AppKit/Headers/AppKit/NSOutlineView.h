/*
   NSOutlineView.h

   Table View subclass for displaying hierchical data

   Copyright (C) 2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Oct 2016

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSOutlineView
#define _mGSTEP_H_NSOutlineView

#include <AppKit/NSTableView.h>

@class NSButtonCell;

@protocol NSOutlineViewDelegate;
@protocol NSOutlineViewDataSource;


@interface NSOutlineView : NSTableView
{
    NSTableColumn *_outlineTableColumn;
    NSButtonCell *_outlineCell;
    CGFloat _indentationPerLevel;

//    NSInteger _numberOfRows;
//    _NSOVRowEntry *_rowEntryTree;
//    NSMapTable *_itemToEntryMap;
//	  CFMutableArrayRef _rowEntryArray;


	struct __OutlineViewFlags {
		unsigned int indentationMarkerInCell:1;
		unsigned int delegateWillDisplayCell:1;
		unsigned int delegateShouldSelectItem:1;
		unsigned int delegateShouldExpandItem:1;
		unsigned int delegateShouldCollapseItem:1;
		unsigned int delegateShouldEditTableColumn:1;
		unsigned int delegateShouldSelectTableColumn:1;
		unsigned int delegateSelectionShouldChangeInOutlineView:1;
		unsigned int reserved:24;
	} _ov;
}

- (void) setDelegate:(id <NSOutlineViewDelegate>)delegate;
- (void) setDataSource:(id <NSOutlineViewDataSource>)aSource;
- (id <NSOutlineViewDataSource>) dataSource;
- (id <NSOutlineViewDelegate>) delegate;

- (void) setOutlineTableColumn:(NSTableColumn *)outlineTableColumn;
- (NSTableColumn *) outlineTableColumn;		// col that displays hierarchical
											// data below its decoration marker
											// indented per indent level

- (BOOL) isExpandable:(id)item;
- (BOOL) isItemExpanded:(id)item;
- (void) expandItem:(id)item expandChildren:(BOOL)flag;
- (void) expandItem:(id)item;

- (void) collapseItem:(id)item collapseChildren:(BOOL)flag;
- (void) collapseItem:(id)item;

- (void) reloadItem:(id)item reloadChildren:(BOOL)flag;
- (void) reloadItem:(id)item;

- (id) parentForItem:(id)item;						// parent or nil if root

- (id) itemAtRow:(NSInteger)row;
- (NSInteger) rowForItem:(id)item;

- (void) setIndentationPerLevel:(CGFloat)level;		// indentation
- (CGFloat) indentationPerLevel;
- (NSInteger) levelForItem:(id)item;
- (NSInteger) levelForRow:(NSInteger)row;
- (void) setIndentationMarkerFollowsCell:(BOOL)flag;
- (BOOL) indentationMarkerFollowsCell;

// FIX ME incomplete
@end


@protocol NSOutlineViewDelegate  <NSObject> // <NSControlTextEditingDelegate>

- (NSView *) outlineView:(NSOutlineView *)outlineView
			 viewForTableColumn:(NSTableColumn *)tableColumn
			 item:(id)item;
									// substitue NSTableView delegate methods
- (void) outlineView:(NSOutlineView *)outlineView
		 willDisplayCell:(id)cell
		 forTableColumn:(NSTableColumn *)tableColumn
		 item:(id)item;
- (BOOL) outlineView:(NSOutlineView *)outlineView
		 shouldEditTableColumn:(NSTableColumn *)tableColumn
		 item:(id)item;
- (BOOL) selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView;

- (BOOL) outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item;
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item;
- (BOOL) outlineView:(NSOutlineView *)v houldSelectTableColumn:(NSTableColumn *)c;

- (void) outlineViewSelectionDidChange:(NSNotification *)n;
- (void) outlineViewColumnDidMove:(NSNotification *)n;
- (void) outlineViewColumnDidResize:(NSNotification *)n;
- (void) outlineViewSelectionIsChanging:(NSNotification *)n;
- (void) outlineViewItemWillExpand:(NSNotification *)n;
- (void) outlineViewItemDidExpand:(NSNotification *)n;
- (void) outlineViewItemWillCollapse:(NSNotification *)n;
- (void) outlineViewItemDidCollapse:(NSNotification *)n;

@end

											// @"NSOldColumn", @"NSNewColumn"
extern NSString *NSOutlineViewColumnDidMoveNotification;
extern NSString *NSOutlineViewSelectionDidChangeNotification;
											// @"NSTableColumn", @"NSOldWidth"
extern NSString *NSOutlineViewColumnDidResizeNotification;
extern NSString *NSOutlineViewSelectionIsChangingNotification;

		// have userinfo dict with @"NSObject" key for changed item value
extern NSString *NSOutlineViewItemWillExpandNotification;
extern NSString *NSOutlineViewItemDidExpandNotification;
extern NSString *NSOutlineViewItemWillCollapseNotification;
extern NSString *NSOutlineViewItemDidCollapseNotification;


@protocol NSOutlineViewDataSource  <NSObject>

- (NSInteger) outlineView:(NSOutlineView *)outlineView
			  numberOfChildrenOfItem:(id)item;
- (id) outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item;
- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id) outlineView:(NSOutlineView *)outlineView
		objectValueForTableColumn:(NSTableColumn *)tableColumn
		byItem:(id)item;
@end


enum {		// FIX ME move to generic location
	kGenericFolderIcon = 1, // 'fldr',
	kDropFolderIcon    = 2, // 'dbox',
	kMountedFolderIcon = 3, // 'mntd',
	kOpenFolderIcon    = 4, // 'ofld',
	kOwnedFolderIcon   = 5, // 'ownd',
	kPrivateFolderIcon = 6, // 'prvf',
	kSharedFolderIcon  = 7  // 'shfl'
};

//NSString * NSFileTypeForHFSTypeCode(OSType hfsFileTypeCode);
NSString * NSFileTypeForHFSTypeCode(unsigned int hfsFileTypeCode);

#endif /* _mGSTEP_H_NSOutlineView */
