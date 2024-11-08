/*
   NSSearchField.h

   Text search field control class for data entry

   Copyright (C) 2004-2017 Free Software Foundation, Inc.

   Author: H. Nikolaus Schaller <hns@computer.org>
   Date:   Dec 2004

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSearchField
#define _mGSTEP_H_NSSearchField

#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSTextField.h>

@class NSButtonCell;


@interface NSSearchField : NSTextField

- (NSString *) recentsAutosaveName;
- (NSArray *) recentSearches;
- (void) setRecentsAutosaveName:(NSString *)name;		// forwarded to cell
- (void) setRecentSearches:(NSArray *)searches;

@end


@interface NSSearchFieldCell : NSTextFieldCell
{
	NSButtonCell *_searchButtonCell;
    NSButtonCell *_cancelButtonCell;
//    NSMenu*         _searchMenuTemplate;
    NSString *_recentsAutosaveName;
    NSMutableArray *_recentSearches;
    NSMenu *_searchMenu;
    NSTimer *_partialStringTimer;

	NSArray *recentSearches;
	NSString *recentsAutosaveName;
	NSMenu *_menuTemplate;
	unsigned char maxRecents;
//	BOOL sendsWholeSearchString;
//	BOOL sendsSearchStringImmediately;

    struct __searchFieldFlags {
		unsigned int sendsWholeSearchString:1;
		unsigned int maximumRecents:8;
		unsigned int cancelVisible:1;
		unsigned int reserved2:2;
		unsigned int disableText:1;
		unsigned int menuTracking:1;
		unsigned int deferredUpdate:1;
		unsigned int sendsImmediately:1;
		unsigned int reserved:16;
    } _sf;
}

- (NSButtonCell*) searchButtonCell;
- (NSButtonCell*) cancelButtonCell;

- (void) setSearchButtonCell:(NSButtonCell*)cell;	// can modify, set or cancel search button.
- (void) setCancelButtonCell:(NSButtonCell*)cell;	// can modify, set or clear cancel button.

- (void) resetSearchButtonCell;			// restore target, action, and image
- (void) resetCancelButtonCell;
    // if cell has been cleared, creates a new cell with default values

- (NSRect) searchTextRectForBounds:(NSRect)rect;
- (NSRect) searchButtonRectForBounds:(NSRect)rect;
- (NSRect) cancelButtonRectForBounds:(NSRect)rect;

- (NSMenu *) searchMenuTemplate;
- (NSInteger) maximumRecents;
- (NSArray *) recentSearches;
- (NSString*) recentsAutosaveName;

- (void) setMaximumRecents:(NSInteger) max;
- (void) setRecentsAutosaveName:(NSString *) name;
- (void) setRecentSearches:(NSArray *) searches;
- (void) setSearchMenuTemplate:(NSMenu *) menu;
- (void) setSendsSearchStringImmediately:(BOOL) flag; 
- (void) setSendsWholeSearchString:(BOOL) flag;

- (BOOL) sendsWholeSearchString;
- (BOOL) sendsSearchStringImmediately;
- (void) setSendsSearchStringImmediately:(BOOL)flag;

@end

#endif /* _mGSTEP_H_NSSearchField */
