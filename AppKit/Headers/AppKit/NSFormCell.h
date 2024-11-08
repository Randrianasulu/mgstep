/*
   NSFormCell.h

   Cell class for the NSForm control

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:	Ovidiu Predescu <ovidiu@net-community.com>
   Date:	March 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSFormCell
#define _mGSTEP_H_NSFormCell

#include <AppKit/NSActionCell.h>


@interface NSFormCell : NSActionCell
{
	float _titleWidth;
	NSCell *_titleCell;
}

- (BOOL) isOpaque;										// Graphic Attributes

- (void) setTitle:(NSString*)aString;					// Title management
- (void) setTitleAlignment:(NSTextAlignment)mode;
- (void) setTitleFont:(NSFont*)fontObject;
- (void) setTitleWidth:(float)width;
- (NSString*) title;
- (NSTextAlignment) titleAlignment;
- (NSFont*) titleFont;
- (float) titleWidth;
- (float) titleWidth:(NSSize)aSize;

@end

#endif /* _mGSTEP_H_NSFormCell */
