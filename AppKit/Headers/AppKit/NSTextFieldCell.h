/*
   NSTextFieldCell.h

   Text field cell class

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTextFieldCell
#define _mGSTEP_H_NSTextFieldCell

#include <AppKit/NSActionCell.h>

@class NSColor;
@class NSImage;

typedef enum {
    NSTextFieldSquareBezel  = 0,
    NSTextFieldRoundedBezel = 1
} NSTextFieldBezelStyle;


@interface NSTextFieldCell : NSActionCell  <NSCoding>
{
	NSColor *_backgroundColor;
	NSColor *_textColor;
	id _placeholderString;

    struct __textFieldCellFlags {
        unsigned int           drawsBackground:1;
        NSTextFieldBezelStyle  bezelStyle:3;
        unsigned int           reserved:4;
    } _tc;
}

- (NSColor *) backgroundColor;							// Graphic Attributes
- (NSColor *) textColor;
- (BOOL) drawsBackground;
- (void) setBackgroundColor:(NSColor *)aColor;
- (void) setDrawsBackground:(BOOL)flag;
- (void) setTextColor:(NSColor *)aColor;

- (NSTextFieldBezelStyle) bezelStyle;
- (void) setBezelStyle:(NSTextFieldBezelStyle)style;

- (NSString *) placeholderString;
- (void) setPlaceholderString:(NSString *)string;
- (void) setPlaceholderAttributedString:(NSAttributedString*)aString;
- (NSAttributedString *) placeholderAttributedString;

@end


@interface NSTableHeaderCell : NSTextFieldCell
{
	NSImage *_indicatorImage;
}
@end

#endif /* _mGSTEP_H_NSTextFieldCell */
