/*
   NSBrowserCell.h

   NSBrowser's default cell class

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date:    October 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSBrowserCell
#define _mGSTEP_H_NSBrowserCell

#include <AppKit/NSCell.h>

@class NSImage;


@interface NSBrowserCell : NSCell  <NSCoding>
{
	NSImage *_branchImage;
	NSImage *_alternateImage;
}

+ (NSImage *) branchImage;								// Graphic Attributes
+ (NSImage *) highlightedBranchImage;

- (NSImage *) alternateImage;
- (void) setAlternateImage:(NSImage *)anImage;

- (BOOL) isLeaf;										// cell type in browser
- (void) setLeaf:(BOOL)flag;

- (BOOL) isLoaded;										// cell load status
- (void) setLoaded:(BOOL)flag;

- (void) reset;											// cell state
- (void) set;

@end

#endif /* _mGSTEP_H_NSBrowserCell */
