/*
   Cell.h

   BrowserCell's for Workspace

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:	April 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Cell
#define _mGSTEP_H_Cell

#include <AppKit/NSBrowserCell.h>


@interface ShelfCell : NSBrowserCell
{
	NSString *_path;
	NSImage *_image;
	NSCell *_browserText;
	NSArray *_files;
}

- (NSString *) path;
- (NSArray *) files;
- (NSCell *) browserText;
- (void) _setFiles:(NSArray *)files;
- (void) _setPath:(NSString *)aPath;
- (void) setBranchImage:(NSImage *)anImage;
- (void) setLeafImage:(NSImage *)anImage;
- (void) drawLightInteriorWithFrame:(NSRect)cellFrame
							 inView:(NSView *)controlView;
@end


@interface BrowserCell : ShelfCell
@end


@interface SelectionCell : BrowserCell
@end

#endif /* _mGSTEP_H_Cell */
