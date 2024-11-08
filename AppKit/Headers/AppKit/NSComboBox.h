/*
   NSComboBox.h

   Control which combines a textfield and a popup list.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSComboBox
#define _mGSTEP_H_NSComboBox

#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSTextField.h>

@class NSNotification;
@class NSButtonCell;
@class NSTableView;
@class NSScrollView;
@class NSPanel;


@protocol NSComboBox

- (void) setHasVerticalScroller:(BOOL)flag;
- (void) setIntercellSpacing:(NSSize)aSize;
- (void) setItemHeight:(float)itemHeight;
- (void) setNumberOfVisibleItems:(int)visibleItems;

- (BOOL) hasVerticalScroller;
- (NSSize) intercellSpacing;
- (float) itemHeight;
- (int) numberOfVisibleItems;

- (void) reloadData;
- (void) noteNumberOfItemsChanged;

- (void) scrollItemAtIndexToTop:(int)index;
- (void) scrollItemAtIndexToVisible:(int)index;

- (void) selectItemAtIndex:(int)index;
- (void) deselectItemAtIndex:(int)index;
- (int) indexOfSelectedItem;
- (int) numberOfItems;

- (void) setUsesDataSource:(BOOL)flag;
- (BOOL) usesDataSource;
												// Access datasource.  Use only
- (id) dataSource;								// when usesDataSource is YES
- (void) setDataSource:(id)aSource;
												// Use these methods only when
- (void) addItemWithObjectValue:(id)object;		// usesDataSource is NO
- (void) addItemsWithObjectValues:(NSArray *)objects;
- (void) insertItemWithObjectValue:(id)object atIndex:(int)index;
- (void) removeItemWithObjectValue:(id)object;
- (void) removeItemAtIndex:(int)index;
- (void) removeAllItems;
- (void) selectItemWithObjectValue:(id)object;
- (id) objectValueOfSelectedItem;
- (id) itemObjectValueAtIndex:(NSInteger)index;
- (NSInteger) indexOfItemWithObjectValue:(id)object;
- (NSArray *) objectValues;

@end


@interface NSComboBoxCell : NSTextFieldCell  <NSComboBox>
{
    id _delegate;
    id _dataSource;
    NSTableView *_tableView;
    NSButtonCell *_buttonCell;
    NSScrollView *_scrollView;
    NSRect *_cellFrame;
    NSPanel *_popUpWindow;
    NSMutableArray *_popUpList;
    NSSize _intercellSpacing;
	float _itemHeight;
	int _visibleItems;

    struct __comboBoxCellFlags {
		unsigned int usesDataSource:1;
		unsigned int hasVerticalScroller:1;
		unsigned int reserved:6;
	} _cbc;
}

@end


@interface NSObject (NSComboBoxCellDataSource)

- (int) numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell;
- (id) comboBoxCell:(NSComboBoxCell *)aComboBoxCell
	   objectValueForItemAtIndex:(int)index;
- (unsigned int) comboBoxCell:(NSComboBoxCell *)aComboBoxCell
				 indexOfItemWithStringValue:(NSString *)string;
@end


@interface NSComboBox : NSTextField  <NSComboBox>
{
    id _dataSource;
}

@end


@interface NSObject (NSComboBoxDataSource)

- (int) numberOfItemsInComboBox:(NSComboBox *)aComboBox;
- (id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index;
- (unsigned int) comboBox:(NSComboBox *)aComboBox 
				 indexOfItemWithStringValue:(NSString *)string;
@end


@interface NSObject (NSComboBoxNotifications)

- (void) comboBoxWillPopUp:(NSNotification *)notification;
- (void) comboBoxWillDismiss:(NSNotification *)notification;
- (void) comboBoxSelectionDidChange:(NSNotification *)notification;
- (void) comboBoxSelectionIsChanging:(NSNotification *)notification;

@end

extern NSString *NSComboBoxWillPopUpNotification;
extern NSString *NSComboBoxWillDismissNotification;
extern NSString *NSComboBoxSelectionDidChangeNotification;
extern NSString *NSComboBoxSelectionIsChangingNotification;

#endif /* _mGSTEP_H_NSComboBox */
