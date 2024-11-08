/*
   NSActionCell.h

   Abstract cell for target/action paradigm

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSActionCell
#define _mGSTEP_H_NSActionCell

#include <AppKit/NSCell.h>


@interface NSActionCell : NSCell  <NSCopying, NSCoding>
{
	int tag;
	id target;
	SEL action;
}

- (void) setAlignment:(NSTextAlignment)mode;			// graphic attributes
- (void) setBezeled:(BOOL)flag;
- (void) setBordered:(BOOL)flag;
- (void) setEnabled:(BOOL)flag;

- (void) setFont:(NSFont *)fontObject;
- (void) setImage:(NSImage *)image;

- (void) setIntValue:(int)anInt;						// Cell Value
- (void) setFloatValue:(float)aFloat;
- (void) setDoubleValue:(double)aDouble;
- (void) setStringValue:(NSString *)aString;

- (void) setAction:(SEL)aSelector;						// Target / Action
- (void) setTarget:(id)anObject;
- (SEL) action;
- (id) target;

- (void) setTag:(int)anInt;								// Integer Tag
- (int) tag;

@end

#endif /* _mGSTEP_H_NSActionCell */
