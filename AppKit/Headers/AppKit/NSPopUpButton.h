/*
   NSPopUpButton.h

   Popup list buttons

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author: Michael Hanni <mhanni@sprintmail.com>
   Date:   June 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPopUpButton
#define _mGSTEP_H_NSPopUpButton

#include <AppKit/NSButton.h>
#include <AppKit/NSMenuItem.h>
#include <AppKit/NSMenu.h>

@class NSArray;
@class NSMutableArray;


extern NSString *NSPopUpButtonCellWillPopUpNotification;


typedef enum {
    NSPopUpNoArrow        = 0,
    NSPopUpArrowAtCenter  = 1,
    NSPopUpArrowAtBottom  = 2
} NSPopUpArrowPosition;


@interface NSPopUpButtonCell : NSMenuItem		// NSMenuItemCell in OSX
{
    int _selectedIndex;

	struct __pbCellFlags {
		unsigned int pullsDown:1;
		unsigned int preferredEdge:3;
		unsigned int menuIsAttached:1;
		unsigned int usesItemFromMenu:1;
		unsigned int altersStateOfSelectedItem:1;
		NSPopUpArrowPosition arrowPosition:2;
		unsigned int reserved:23;
	} _pbc;
}

- (id) initTextCell:(NSString *)string pullsDown:(BOOL)flag;

- (void) setPullsDown:(BOOL)flag;
- (BOOL) pullsDown;

- (void) selectItemAtIndex:(int)index;

@end


@interface NSPopUpButton : NSButton  <NSCoding>
{
	NSMutableArray *_items;
	NSWindow *_popUpWindow;
	NSInteger _selectedItem;
}

- (id) initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag;

- (void) addItemWithTitle:(NSString *)title;			// Adding Items
- (void) addItemsWithTitles:(NSArray *)itemTitles;
- (void) insertItemWithTitle:(NSString *)title atIndex:(unsigned int)index;

- (void) removeAllItems;								// Removing Items
- (void) removeItemWithTitle:(NSString *)title;
- (void) removeItemAtIndex:(int)index;

- (NSInteger) indexOfItemWithTitle:(NSString *)title;			// Access Items
- (NSInteger) indexOfSelectedItem;
- (NSInteger) numberOfItems;

- (NSArray *) itemArray;
- (NSArray *) itemTitles;

- (id <NSMenuItem>) itemAtIndex:(NSInteger)index;
- (id <NSMenuItem>) itemWithTitle:(NSString *)title;
- (id <NSMenuItem>) lastItem;
- (id <NSMenuItem>) selectedItem;

- (NSString *) titleOfSelectedItem;
- (NSString *) itemTitleAtIndex:(int)index;

- (void) setPullsDown:(BOOL)flag;
- (BOOL) pullsDown;

- (void) setMenu:(NSMenu *)menu;
- (NSMenu *) menu;

- (void) selectItemAtIndex:(int)index;
- (void) selectItemWithTitle:(NSString *)title;
- (void) setTitle:(NSString *)aString;
- (void) synchronizeTitleAndSelectedItem;

- (BOOL) autoenablesItems;								// Display management
- (void) setAutoenablesItems:(BOOL)flag;

@end

#endif /* _mGSTEP_H_NSPopUpButton */
