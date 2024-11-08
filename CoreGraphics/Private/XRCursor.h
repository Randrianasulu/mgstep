/*
   XRCursor.h

   X11 Cursor class

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@pcmagic.net>
   Date:    June 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_XRCursor
#define _mGSTEP_H_XRCursor

#include <AppKit/NSCursor.h>


@interface XRCursor : NSCursor
{
	Cursor _cursor;
}

@end


@interface NSCursor (_NSCursor)

- (void) xSetCursor:(Cursor)cursor;
- (Cursor) xCursor;

@end

#endif /* _mGSTEP_H_XRCursor */
