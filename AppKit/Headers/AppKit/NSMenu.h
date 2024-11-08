/*
   NSMenu.h

   Application Menu classes

   Copyright (C) 1998-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    July 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSMenu
#define _mGSTEP_H_NSMenu

#include <AppKit/NSMenuItem.h>
#include <AppKit/NSControl.h>

@class NSString;
@class NSEvent;
@class NSMenuView;


@interface NSMenu : NSObject  <NSCoding, NSCopying>
{
	struct __MenuFlags {
		unsigned int autoenablesItems:1;
		unsigned int menuChangedMessagesEnabled:1;
		unsigned int menuHasChanged:1;
		unsigned int menuLocationSet:1;
		unsigned int isHorizontal:1;
		unsigned int reserved:3;
	} _mn;

	NSString *_title;
	NSView *_titleView;

	NSWindow *window;
	NSMenuView *_menuView;

	NSMenu *_supermenu;
	NSMenu *_attachedMenu;
@public
	NSMenu *_isCopyOfMenu;
}

+ (void) setCellClass:(Class)aClass;					// menu cell class
+ (Class) cellClass;

+ (void) popUpContextMenu:(NSMenu*)m withEvent:(NSEvent*)e forView:(NSView*)v;

+ (void) setMenuBarVisible:(BOOL)visible;
+ (BOOL) menuBarVisible;

- (id) initWithTitle:(NSString*)aTitle;
														// Add menu items
- (NSMenuItem *) addItemWithTitle:(NSString*)aString
						   action:(SEL)aSelector
						   keyEquivalent:(NSString*)charCode;
- (NSMenuItem *) insertItemWithTitle:(NSString*)aString
							  action:(SEL)aSelector
							  keyEquivalent:(NSString*)charCode
							  atIndex:(unsigned int)index;
- (NSArray*) itemArray;

- (void) addItem:(NSMenuItem *)item;
- (void) removeItem:(NSMenuItem *)item;

- (NSMenuItem *) itemWithTag:(int)aTag;					// Find menu items
- (NSMenuItem *) itemWithTitle:(NSString*)aString;

- (void) submenuAction:(id)sender;						// Managing submenus
- (void) setSubmenu:(NSMenu*)aMenu forItem:(NSMenuItem *)anItem;
- (BOOL) isAttached;
- (NSPoint) locationForSubmenu:(NSMenu*)aSubmenu;
- (NSMenu*) supermenu;
- (NSMenu*) attachedMenu;

- (void) setAutoenablesItems:(BOOL)flag;				// Enabling menu items
- (BOOL) autoenablesItems;
- (void) update;

- (BOOL) performKeyEquivalent:(NSEvent*)event;			// keyboard equivalents

- (void) sizeToFit;

- (void) setTitle:(NSString*)aTitle;					// Menu title
- (NSString*) title;

@end


@interface NSObject (NSMenuItemValidation)

- (BOOL) validateMenuItem:(NSMenuItem *)item;

@end


@interface NSMenu (PrivateMethods)

- (void) display;							// display menu window on screen
- (void) close;								// close associated window menu
- (NSMenuView *) menuCells;					// menu cells' view matrix
- (NSView *) menuTitleView;
- (void) setHorizontal:(BOOL)flag;
- (void) _closeAttachedMenu:(NSEvent *)event;

@end


@protocol _MenuTitle						// Menu Backend protocol

+ (NSView *) _newMenuTitleView;
- (void) setMenu:(NSMenu*)aMenu;

@end


@interface NSMenu  (PrivateMenu)  <_MenuTitle>

- (NSWindow *) _menuWindow;

@end

/* ****************************************************************************

		NSMenuView

** ***************************************************************************/

@interface NSMenuView : NSView	<NSCopying>
{
	NSMutableArray *_cells;
	float _cellHeight;
	NSMenu *_menu;
	NSMenuItem *_menuItem;
	id selectedCell;
	id _selectedCellTarget;
	int selectedCellIndex;
	NSRect selectedCellRect;

	void *_texture;
	NSSize _textureSize;

	struct __MenuViewFlags {
		unsigned int selectedCellHasSubmenu:1;
		unsigned int isHorizontal:1;
		unsigned int reserved:6;
	} _mv;
}

- (id) initWithFrame:(NSRect)rect;
//- (id) initAsTearOff;

- (void) setMenu:(NSMenu*)menu;
- (NSMenu *) menu;

- (NSRect) rectOfItemAtIndex:(NSInteger)index;
- (NSInteger) indexOfItemAtPoint:(NSPoint)point;

- (void) setHorizontal:(BOOL)flag;
- (BOOL) isHorizontal;

- (CGFloat) horizontalEdgePadding;				// space between items
- (void) setHorizontalEdgePadding:(CGFloat)pad;

@end


@interface NSMenuView (PrivateMethods)

- (NSArray*) itemArray;
- (void) setSelectedCell:(id)aCell;
- (id) selectedCell;
- (NSRect) selectedCellRect;
- (float) cellHeight;

@end

/* ****************************************************************************

		OSX unused

** ***************************************************************************/

@interface NSMenuItemCell : NSButtonCell
{
	NSMenuItem *_menuItem;
}

- (void) setMenuItem:(NSMenuItem *)item;
- (NSMenuItem *) menuItem;

@end


@interface NSMenuView (OSX_NotImplemented)

- (NSRect) innerRect;

- (void) setHighlightedItemIndex:(NSInteger)index;
- (NSInteger) highlightedItemIndex;

- (void) setMenuItemCell:(NSMenuItemCell*)cell forItemAtIndex:(NSInteger)index;

- (NSMenuItemCell *) menuItemCellForItemAtIndex:(NSInteger)index;

- (BOOL) isAttached;
- (BOOL) isTornOff;

- (NSMenu *) attachedMenu;
- (NSMenuView *) attachedMenuView;

@end

#endif /* _mGSTEP_H_NSMenu */
