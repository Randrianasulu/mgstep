/*
   NSBox.h

   Box view that displays a border, title and contents.

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    March 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBox
#define _mGSTEP_H_NSBox

#include <AppKit/NSView.h>

@class NSString;
@class NSFont;

typedef enum _NSTitlePosition {
	NSNoTitle	  = 0,
	NSAboveTop	  = 1,
	NSAtTop		  = 2,
	NSBelowTop	  = 3,
	NSAboveBottom = 4,
	NSAtBottom	  = 5,
	NSBelowBottom = 6
} NSTitlePosition;


@interface NSBox : NSView  <NSCoding>
{
	id _titleCell;
	id _contentView;
	NSSize _offsets;
	NSRect _borderRect;
	NSRect _titleRect;

    struct __BoxFlags {
		unsigned int needsTile:1;
		NSBorderType borderType:2;
		NSTitlePosition	titlePosition:3;
		unsigned int transparent:1;
		unsigned int reserved:1;
	} _bx;
}

- (NSRect) borderRect;									// Border+Title attribs
- (NSBorderType) borderType;
- (void) setBorderType:(NSBorderType)aType;
- (void) setTitle:(NSString *)aString;
- (void) setTitleFont:(NSFont *)fontObj;
- (void) setTitlePosition:(NSTitlePosition)aPosition;
- (NSString *) title;
- (id) titleCell;
- (NSFont *) titleFont;
- (NSTitlePosition) titlePosition;
- (NSRect) titleRect;

- (id) contentView;										// Content View
- (NSSize) contentViewMargins;
- (void) setContentView:(NSView *)aView;
- (void) setContentViewMargins:(NSSize)offsetSize;

- (void) sizeToFit;										// Sizing the Box
- (void) setFrameFromContentFrame:(NSRect)contentFrame;

@end

#endif /* _mGSTEP_H_NSBox */
