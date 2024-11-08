/*
   Browser.h

   NSBrowser and delegate for mGSTEP Workspace

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: 	July 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Browser
#define _mGSTEP_H_Browser

#include <AppKit/NSBrowser.h>


@interface Browser : NSBrowser
{
	NSMatrix *selectionMatrix;
	NSScrollView *selectionScrollView;
}

- (void) toggleBrowserView:(id)sender;

@end


@interface IconViewDelegate : NSObject

- (void) browser:(NSBrowser *)sender
		 createRowsForColumn:(int)column
		 inMatrix:(NSMatrix *)matrix;
- (void) browser:(NSBrowser *)sender
		 willDisplayCell:(id)cell
		 atRow:(int)row
		 column:(int)column;
@end


@interface ListViewDelegate : IconViewDelegate
@end

#endif /* _mGSTEP_H_Browser */
