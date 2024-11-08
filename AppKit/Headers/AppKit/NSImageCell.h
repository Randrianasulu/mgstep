/*
   NSImageCell.h

   Image View Cell class

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	Jan 2004

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSImageCell
#define _mGSTEP_H_NSImageCell

#include <AppKit/NSCell.h>

typedef enum {
	NSScaleProportionally = 0,
	NSScaleToFit,
	NSScaleNone
} NSImageScaling;

typedef enum {
	NSImageAlignCenter = 0,
	NSImageAlignTop,
	NSImageAlignTopLeft,
	NSImageAlignTopRight,
	NSImageAlignLeft,
	NSImageAlignBottom,
	NSImageAlignBottomLeft,
	NSImageAlignBottomRight,
	NSImageAlignRight
} NSImageAlignment;

typedef enum {
	NSImageFrameNone = 0,
	NSImageFramePhoto,
	NSImageFrameGrayBezel,
	NSImageFrameGroove,
	NSImageFrameButton
} NSImageFrameStyle;


@interface NSImageCell : NSCell  <NSCopying, NSCoding>
{
	struct __ImageCellFlags {
		NSImageScaling imageScaling:2;
		NSImageAlignment imageAlignment:4;
		NSImageFrameStyle imageFrameStyle:3;
		unsigned int reserved:7;
		} _ic;
}

- (NSImageScaling) imageScaling;
- (NSImageAlignment) imageAlignment;
- (NSImageFrameStyle) imageFrameStyle;

- (void) setImageScaling:(NSImageScaling)newScaling;
- (void) setImageAlignment:(NSImageAlignment)newAlign;
- (void) setImageFrameStyle:(NSImageFrameStyle)newStyle;

@end

#endif /* _mGSTEP_H_NSImageCell */
