/*
   Matrix.h

   NSBrowser Matrix for Workspace's browser

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:	August 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Matrix
#define _mGSTEP_H_Matrix

#include <AppKit/NSMatrix.h>

#define CELL_WIDTH  70
#define CELL_HEIGHT 70

@class Browser;


@interface Matrix : NSMatrix
{
	BOOL _isFinderShelf;
}

- (NSArray *) saveState;
- (void) restoreState;

- (void) setIsFinderShelf:(BOOL)flag;

@end

@interface BrowserMatrix : Matrix
@end

@interface SelectionMatrix : Matrix
@end

@interface FinderMatrix : NSMatrix
@end

#endif /* _mGSTEP_H_Matrix */
