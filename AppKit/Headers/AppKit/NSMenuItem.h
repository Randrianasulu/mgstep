/*
   NSMenuItem.h

   Menu item and display cell.

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Ovidiu Predescu <ovidiu@net-community.com>
   Date:    May 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSMenuItem
#define _mGSTEP_H_NSMenuItem

#include <AppKit/NSButtonCell.h>

@class NSMenu;


@protocol NSMenuItem  <NSCopying, NSCoding>  // NSValidatedUserInterfaceItem

+ (void) setUsesUserKeyEquivalents:(BOOL)flag;
+ (BOOL) usesUserKeyEquivalents;

- (BOOL) isEnabled;
- (BOOL) hasSubmenu;
- (NSString*) userKeyEquivalent;

- (id) representedObject;
- (void) setRepresentedObject:(id)anObject;

@end


@interface NSMenuItem : NSButtonCell  <NSMenuItem>
{
    NSMenu *_menu;

	struct __MenuItemFlags {
		unsigned int hasSubmenu:1;
		unsigned int isHorizontal:1;
		unsigned int reserved:6;
	} _mi;
}

- (id) initWithTitle:(NSString *)t action:(SEL)a keyEquivalent:(NSString *)code;

+ (NSMenuItem *) separatorItem;
- (BOOL) isSeparatorItem;

- (void) setMenu:(NSMenu *)menu;
- (NSMenu *) menu;
- (NSMenu *) submenu;

@end


@interface NSMenuItem  (OSX_NotImplemented)

- (void) setSubmenu:(NSMenu *)submenu;
- (void) setHorizontal:(BOOL)flag;

@end

#endif /* _mGSTEP_H_NSMenuItem */
