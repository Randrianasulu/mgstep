/*
   XRBitmapImageRep.h

   XRAW NSBitmapImageRep category 

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_XRBitmapImageRep
#define _mGSTEP_H_XRBitmapImageRep

#include <AppKit/NSBitmapImageRep.h>


@interface NSBitmapImageRep  (_NSBitmapImageRep)

- (XImage *) xImage;
- (Pixmap) xPixmapMask;
- (Pixmap) xPixmapBitmap;

@end

#endif /* _mGSTEP_H_XRBitmapImageRep */
