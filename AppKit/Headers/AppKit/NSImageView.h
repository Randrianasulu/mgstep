/*
   NSImageView.h

   Image View class

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	Jan 2004

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSImageView
#define _mGSTEP_H_NSImageView

#include <AppKit/NSControl.h>
#include <AppKit/NSImageCell.h>


@interface NSImageView : NSControl

- (NSImage *) image;
- (void) setImage:(NSImage *)image;

- (NSImageScaling) imageScaling;
- (NSImageAlignment) imageAlignment;
- (NSImageFrameStyle) imageFrameStyle;

- (void) setImageScaling:(NSImageScaling)scaling;
- (void) setImageAlignment:(NSImageAlignment)align;
- (void) setImageFrameStyle:(NSImageFrameStyle)style;

- (void) setEditable:(BOOL)flag;
- (BOOL) isEditable;

@end

#endif /* _mGSTEP_H_NSImageView */
